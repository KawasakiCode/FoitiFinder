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
import match_expiry
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
    #WITHDRAWN BY EITHER SIDE MEANS GONE FOR BOTH. The row survives so the
    #connection is still on record; it just stops being served - which is the
    #only thing the app can actually take back once a handle has been read.
    #
    #AND AN UNANSWERED MATCH RUNS OUT. The match page lets the person who
    #completed one back out of answering, which leaves a match only they can
    #see - so without a deadline, a match the other side never heard about
    #would sit there forever. See match_expiry: three days from whenever it
    #became somebody's turn, derived rather than stored.
    now = datetime.datetime.now(datetime.timezone.utc)
    matches = db.query(models.Matches).filter(
        match_expiry.not_past_grace(now),
        #WHICH SIDE I AM ON DECIDES BOTH QUESTIONS, so they are answered
        #together rather than as two filters that have to agree:
        #
        #  as user_a   mine always, unless I removed my own copy
        #  as user_b   only once user_a has answered, and unless I removed
        #              my own copy
        #
        #The other side's removal is deliberately not consulted. They cannot
        #take a handle back and I should not be able to tell they walked away.
        or_(
            and_(models.Matches.user_a_id == me.id,
                 models.Matches.hidden_by_a_at.is_(None)),
            and_(models.Matches.user_b_id == me.id,
                 models.Matches.hidden_by_b_at.is_(None),
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
            #RAN OUT, AND STILL SHOWN SAYING SO. Inside the grace window the
            #row is still served with this set, so whoever was owed an answer
            #reads that it lapsed rather than finding a match missing. Past
            #the window the query above has already dropped it.
            "expired": match_expiry.is_expired(match, now),
            #THE DEADLINE, so the page can name a date instead of a policy.
            #'Matches expire after three days' in a help screen is read by
            #nobody; 'if Maria does not answer by Thursday' is read by
            #everybody. Null once the exchange is done and nothing expires.
            "expires_at": (None if match.b_confirmed_at is not None
                           else match_expiry.expires_at(match)),
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

    #A MATCH YOU HAVE NOT BEEN SHOWN CANNOT BE ANSWERED, which is the SAME
    #rule get_matches applies and the reason it has to be repeated here.
    #
    #Until user_a answers, the match is theirs alone - user_b has never been
    #told it exists. But match ids are sequential integers, so without this
    #check user_b could confirm one by guessing its id, and three things
    #followed from that: user_a got a push saying somebody answered a match
    #user_a had not answered yet, b_confirmed_at was set so the match could
    #never expire (a finished exchange must not), and user_a's own confirm
    #then revealed immediately, skipping the state where they are told
    #somebody is waiting on them.
    #
    #404, NOT 409: the point is that user_b does not know this match exists,
    #and any other answer confirms that it does. It is the same reply a
    #stranger gets, for the same reason.
    if match.user_b_id == me.id and match.a_confirmed_at is None:
        raise HTTPException(status_code=404, detail="Match not found")

    #A MATCH THE LIST NO LONGER SERVES CANNOT BE ACTED ON EITHER, and both of
    #the callers below are things you should not be able to do to it: confirm
    #hands over an Instagram handle, decline deletes the row and tells the
    #other side. The two reads have to agree, or a client holding a stale page
    #is the way around the rule.
    #
    #EXPIRED: it ran out unanswered. The other side was shown that it lapsed,
    #so letting a confirm land afterwards would hand them a handle for a match
    #they were told was over.
    #
    #REMOVED BY ME: my own copy is gone, so there is nothing of mine left to
    #answer. THEIR removal is not checked, deliberately - the whole point of
    #it being per side is that neither of us can detect the other's, and a 409
    #here would be exactly that detector.
    now = datetime.datetime.now(datetime.timezone.utc)
    removed_by_me = (match.hidden_by_a_at if match.user_a_id == me.id
                     else match.hidden_by_b_at)
    if removed_by_me is not None or match_expiry.is_expired(match, now):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This match is no longer available",
        )
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
        #THE ID TRAVELS WITH IT, so the banner opens this match instead of
        #a list to search. Both kinds carry it and both open the same place -
        #which is why the app does not branch on the kind at all.
        push(other, 'match_revealed' if revealed else 'match',
             match_id=match.id)

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
    #read only to decide whether this match is already finished, below
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

    #NOBODY IS TOLD, not even somebody who was waiting on the answer.
    #
    #THERE USED TO BE A PUSH HERE, and the argument for it was that a person
    #who has shared their handle and is waiting deserves to hear. The argument
    #against is what it actually says: a notification whose only content is
    #that somebody said no, with nothing to do about it. The match leaves
    #their list, which is the honest representation and the same way an
    #expired one goes - that one is shown saying so for a couple of days and
    #sends nothing either.
    #
    #Declining as the person who COMPLETED the match was always silent, for a
    #stronger reason: they were never shown the match, so "someone matched
    #with you and then changed their mind" would be news of a rejection they
    #could not have seen coming.
    return {"declined": True}


@router.delete("/matches/{match_id}")
def remove_match(match_id: int, uid: str = Depends(verified_email_uid),
                 db: Session = Depends(get_db)):
    """Take a finished match off your own list, and only yours.

    THE OTHER HALF OF decline, AND THEY DIVIDE EVERY MATCH BETWEEN THEM.
    decline refuses once both sides have confirmed, because a handle that has
    been read cannot be unread - and that left the finished state with no exit
    at all, permanent for as long as the account exists. This covers exactly
    that state and nothing else, so every match can be left by precisely one
    of the two endpoints.

    ONLY WHEN BOTH HAVE CONFIRMED, which is decline's refusal condition
    inverted rather than `revealed`. A match where both said yes but somebody
    has no handle yet is not revealed, and it still needs the way out: the
    alternative is a row that waits forever on a handle that may never be
    filled in. Anything still unanswered belongs to decline, which tells
    whoever was waiting - letting this one through instead would be a silent
    way to leave somebody waiting on an answer that never comes.

    THE OTHER SIDE IS TOLD NOTHING AND LOSES NOTHING. Their copy stays. See
    the model: removing it from them would take back nothing they do not
    already have, while making the removal something they can notice - and
    once reporting removes a match too, noticing it is how somebody learns
    they were reported by a person whose Instagram handle they hold.

    IDEMPOTENT. The first call writes the timestamp and later ones answer the
    same thing, so a retry after a dropped connection is not a different
    decision - and the row the caller is retrying for is already gone from
    their list either way.
    """
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")

    #NOT _match_for_participant: that refuses a match already removed by the
    #caller, which is right for answering one and wrong for removing it - a
    #retried removal would answer 409 for having worked. The participation
    #check is the part that matters here, so it is made directly.
    match = db.query(models.Matches).filter(
        models.Matches.id == match_id).first()
    if not match or me.id not in (match.user_a_id, match.user_b_id):
        raise HTTPException(status_code=404, detail="Match not found")

    i_am_a = match.user_a_id == me.id

    if match.a_confirmed_at is None or match.b_confirmed_at is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Only a completed match can be removed",
        )

    now = datetime.datetime.now(datetime.timezone.utc)
    if i_am_a and match.hidden_by_a_at is None:
        match.hidden_by_a_at = now
    elif not i_am_a and match.hidden_by_b_at is None:
        match.hidden_by_b_at = now
    db.commit()

    #NO PUSH, to anybody. Nothing of theirs changed, and "somebody removed
    #your match" is a rejection notice about a decision they cannot act on.
    return {"removed": True}
