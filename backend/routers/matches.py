"""A match: who is in it, and what each side has agreed to."""

import datetime

from sqlalchemy import and_, or_

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth import current_uid, verified_claims, verified_email_uid
from database import models, schemas
from database.database import get_db

router = APIRouter()

from ages import age_from_birthday
from api_models import MatchResponse
from app_logging import logger
#PUSH ONLY, no stored row. The matches page is the record now - it lists every
#live match and says whose turn each one is - so a notification row about a
#match would be a second, staler copy of a screen the user can just open. The
#push is still worth sending: it is what brings somebody back to the app.
from notifications import push
from typing import List

#get every match the user currently has
@router.get("/matches", response_model = List[MatchResponse])
def get_matches(uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")
    
    #A MATCH THE OTHER SIDE HAS NOT ANSWERED IS NOT YOURS TO SEE YET, and this
    #is the rule the whole flow is built on: the person who was liked hears
    #nothing until the one who completed the match has confirmed. Otherwise
    #this page would announce matches that are declined seconds later, to
    #somebody who was never given the chance to want one.
    #
    #user_a is always the one who completed the match (record_swipe writes it
    #that way), so: it is mine if I completed it, or if the completer has said
    #yes. A match they abandon is deleted and the other side never knew.
    #
    #NEWEST FIRST: this is the page people open to find the match they just
    #made, not to browse history.
    matches = db.query(models.Matches).filter(
        or_(
            models.Matches.user_a_id == me.id,
            and_(models.Matches.user_b_id == me.id,
                 models.Matches.a_confirmed_at.isnot(None)),
        ),
    ).order_by(models.Matches.id.desc()).all()

    if not matches:
        return []

    #figure out the "other" user for each match in one pass
    other_ids = [
        match.user_b_id if match.user_a_id == me.id else match.user_a_id
        for match in matches
    ]

    #one query for every other user instead of one per match
    users_by_id = {
        user.id: user
        for user in db.query(models.User).filter(models.User.id.in_(other_ids)).all()
    }
    #and one for their profile pictures: the photo with display_order 0
    picture_by_user = {
        photo.user_id: photo.photo_url
        for photo in db.query(models.Photos).filter(
            models.Photos.user_id.in_(other_ids),
            models.Photos.display_order == 0,
        ).all()
    }

    results = []
    for match in matches:
        i_am_a = match.user_a_id == me.id
        other_user_id = match.user_b_id if i_am_a else match.user_a_id
        other_user = users_by_id.get(other_user_id)

        #a match with a deleted user is skipped rather than failing the whole call
        if not other_user:
            continue

        mine = match.a_confirmed_at if i_am_a else match.b_confirmed_at
        theirs = match.b_confirmed_at if i_am_a else match.a_confirmed_at

        results.append({
            "match_id": match.id,
            "other_user_id": other_user.id,
            "other_user_name": other_user.name,
            "other_user_age": age_from_birthday(other_user.birthday),
            "image_url": picture_by_user.get(other_user.id),
            "i_confirmed": mine is not None,
            "they_confirmed": theirs is not None,
            #THE SAME CONDITION confirm_match REVEALS ON, handles included: a
            #row claiming to be revealed when one side has no handle would send
            #the page to ask for something that is not there.
            "revealed": (mine is not None and theirs is not None
                         and bool(me.instagram_handle)
                         and bool(other_user.instagram_handle)),
        })

    return results

#THE TWO HALVES OF A MATCH. Mutual likes make the row; these decide whether
#anything is actually exchanged.
#
#Both take the match id rather than a user id, and both check that the caller
#is one of its two participants - a match is the only context in which these
#two users are allowed to affect each other, so it is the match that is
#addressed, not the person.
def _match_for_participant(match_id: int, me: models.User, db: Session) -> models.Matches:
    match = db.query(models.Matches).filter(models.Matches.id == match_id).first()
    #the same 404 whether it does not exist or belongs to other people: a
    #different answer for each would let anyone count other people's matches
    if not match or me.id not in (match.user_a_id, match.user_b_id):
        raise HTTPException(status_code=404, detail="Match not found")
    return match

@router.post("/matches/{match_id}/confirm")
def confirm_match(match_id: int, uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    """Say yes to a match, and get the other handle once both sides have.

    IDEMPOTENT. A second call from the same user changes nothing and answers
    the same thing - a retry after a dropped connection must not look like a
    different decision, and the client cannot tell the two apart.
    """
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")

    match = _match_for_participant(match_id, me, db)
    i_am_a = match.user_a_id == me.id
    other_id = match.user_b_id if i_am_a else match.user_a_id

    #whether they were already waiting decides what they get told below, so it
    #is read BEFORE this confirmation is written
    other_confirmed = match.a_confirmed_at if not i_am_a else match.b_confirmed_at

    #read BEFORE the write, so a retry can be told apart from a first answer
    already_confirmed = (match.a_confirmed_at if i_am_a
                         else match.b_confirmed_at) is not None

    now = datetime.datetime.now(datetime.timezone.utc)
    if i_am_a and match.a_confirmed_at is None:
        match.a_confirmed_at = now
    elif not i_am_a and match.b_confirmed_at is None:
        match.b_confirmed_at = now
    db.commit()

    other = db.query(models.User).filter(models.User.id == other_id).first()
    if not other:
        #their account is gone, so there is nobody to exchange with
        db.delete(match)
        db.commit()
        raise HTTPException(status_code=404, detail="Match not found")

    #BOTH HANDLES HAVE TO EXIST for there to be an exchange. Setup refuses to
    #let anyone past without one, but a row written before that page existed
    #can still be NULL until its owner next opens the app - and an exchange
    #that hands over nothing is worse than one that has not happened yet.
    #Saying "not yet" keeps both confirmations on the row, so it completes on
    #its own once the missing handle is filled in.
    both_have_handles = bool(me.instagram_handle) and bool(other.instagram_handle)
    revealed = other_confirmed is not None and both_have_handles

    #The handle crosses between users HERE AND NOWHERE ELSE, and only when
    #both of them have asked for it. Everything else about another user comes
    #from /users/{id}/profile, which deliberately has no handle in it.
    #
    #They were waiting -> this completes it and their own reveal is in the
    #bell. Otherwise it is their turn, and the same row is what gets them
    #there whether or not the push arrives.
    #NOTHING HERE MAY FAIL THE CONFIRM. The confirmation is already committed,
    #and a push that cannot be sent - no token, Firebase down - must not turn a
    #successful exchange into an error for the person who just agreed to it.
    #
    #A retried confirm sends a second push, where the old notification row was
    #deduplicated. That is the honest trade for dropping the row: a duplicate
    #banner is a smaller harm than a stale list, and the matches page is where
    #the truth is either way.
    #ONLY WHEN THIS CALL CHANGED SOMETHING. confirm is idempotent, so the
    #client is free to retry one whose answer it never saw - and that must not
    #reach the other person as a second banner saying the same thing. The
    #stored notification used to carry that guarantee with `once`; without a
    #row it has to come from here.
    if not already_confirmed:
        push(other, 'match_revealed' if revealed else 'match')

    return {
        "revealed": revealed,
        "name": other.name,
        "instagram_handle": other.instagram_handle if revealed else None,
    }

@router.post("/matches/{match_id}/decline")
def decline_match(match_id: int, uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    """Change your mind: the match is deleted and the like is withdrawn.

    THE SWIPE IS TURNED INTO A PASS, not just the match deleted. The like that
    created it would otherwise still stand, so the other side's likes page
    would show this person as a fresh like (it re-surfaces anyone whose like
    is newer than your own swipe) and the next re-swipe would rebuild the
    match that was just refused.
    """
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")

    match = _match_for_participant(match_id, me, db)
    i_am_a = match.user_a_id == me.id
    other_id = match.user_b_id if i_am_a else match.user_a_id
    #only somebody who already said yes is owed an answer - see below
    other_confirmed = match.a_confirmed_at if not i_am_a else match.b_confirmed_at
    mine_confirmed = match.a_confirmed_at if i_am_a else match.b_confirmed_at

    #A REVEALED MATCH CANNOT BE DECLINED. Once both sides have said yes the
    #handles have been handed over, and nothing can take back something
    #somebody has already read - so deleting the row here would destroy the
    #only record of a connection that genuinely happened, and turn the like
    #that made it into a pass. It is also how an already-answered
    #notification, tapped twice, used to delete a finished match.
    if mine_confirmed is not None and other_confirmed is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This match has already been completed",
        )

    db.query(models.UserSwipes).filter(
        models.UserSwipes.user_id == me.id,
        models.UserSwipes.target_id == other_id,
    ).update(
        {models.UserSwipes.action: "pass",
         models.UserSwipes.timestamp: datetime.datetime.now(datetime.timezone.utc)},
        synchronize_session=False,
    )
    db.delete(match)
    db.commit()

    #WHOEVER WAS WAITING GETS TOLD, and nobody else. Declining as the person
    #who completed the match tells the other side nothing at all: they were
    #never informed a match existed, so "someone matched with you and then
    #changed their mind" would be news of a rejection they could not have
    #seen coming. Declining when the other has already said yes is different -
    #they are waiting on an answer and deserve one.
    if other_confirmed is not None:
        other = db.query(models.User).filter(models.User.id == other_id).first()
        if other:
            #PUSH ONLY, AND NOTHING LEFT BEHIND. The match row is gone, so the
            #entry simply disappears from their matches page - which is the
            #honest representation of what happened. A stored notification
            #would be the one record of a match that no longer exists, and
            #tapping it could only ever lead nowhere.
            push(other, 'match_declined')

    return {"declined": True}
