"""Recording a swipe, and noticing when it completes a match."""

import datetime

from sqlalchemy import and_, or_

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth import current_uid, verified_claims, verified_email_uid
from database import models, schemas
from database.database import get_db

router = APIRouter()

from api_models import SwipeRequest
from app_logging import logger
from firebase_app import firestore_db
from notifications import send_smart_notification

#register a swipe
@router.post("/swipes")
def record_swipe(swipe: SwipeRequest, uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
       raise HTTPException(status_code=404, detail="Current User not found")

    query = db.query(models.UserSwipes).filter(  
        models.UserSwipes.user_id == me.id,
        models.UserSwipes.target_id == swipe.target_id
    )

    existing = query.first()

    is_match = False
    #the row the two of them now share, when this swipe completed one
    match_id = None

    if existing:
        #only write when the action actually changed (re-swiping the same way
        #is a no-op). datetime is imported as a module, hence datetime.datetime.
        if existing.action != swipe.action:
            query.update({models.UserSwipes.action: swipe.action,
                        models.UserSwipes.timestamp: datetime.datetime.now(datetime.timezone.utc)}, synchronize_session=False)
            db.commit()
    else:
        new_swipe = models.UserSwipes(  
        user_id = me.id,
        target_id = swipe.target_id,
        action = swipe.action
        )

        db.add(new_swipe)
        db.commit()  
    
    if swipe.action in ["like", "super_like"]:
        # Look in UserSwipes to see if THEY liked US
        reverse_swipe = db.query(models.UserSwipes).filter(
            models.UserSwipes.user_id == swipe.target_id, # Them
            models.UserSwipes.target_id == me.id,         # Us
            or_(  
                models.UserSwipes.action == "like",
                models.UserSwipes.action == "super_like"
            )
        ).first()

        if reverse_swipe:
            # Check if match already exists (to prevent duplicates)
            existing_match = db.query(models.Matches).filter(
                or_(
                    and_(
                        models.Matches.user_a_id == me.id,
                        models.Matches.user_b_id == swipe.target_id,
                    ),
                    and_(
                        models.Matches.user_a_id == swipe.target_id,
                        models.Matches.user_b_id == me.id,
                    )
                ),
            ).first()

            if not existing_match:
                # Create the Match
                new_match = models.Matches(user_a_id=me.id, user_b_id=swipe.target_id)
                db.add(new_match)
                db.commit()
                is_match = True
                match_id = new_match.id
            else:
                #re-swiping the same way reaches here with the match already
                #made; the client still needs its id to open the match page
                match_id = existing_match.id

        #The following code is used to grab the target user's fcm token to be able to send 
        #a notification to them
        #Remember firebase uid is NOT the same as the FCM token
        target_user = db.query(models.User).filter(models.User.id == swipe.target_id).first()
        if not target_user:
            raise HTTPException(status_code=404, detail="Target User not found")

        #A MATCH IS NOT ANNOUNCED HERE ANY MORE. The person being liked only
        #hears about it once the one who completed the match has confirmed on
        #the match page (POST /matches/{id}/confirm) - until then there is
        #nothing to tell them about, and telling them early would mean
        #announcing matches that get declined seconds later.
        #
        #A like is still announced, and it is deliberately the same message
        #whether or not it completed a match: "someone liked you" leaks
        #nothing, while "it's a match" would say who.
        #
        #NOTHING HERE MAY FAIL THE SWIPE. The swipe is already committed, and
        #this used to raise 404 when the target had no FCM token - so the
        #caller was told the swipe failed, and never learned it was a match,
        #for a reason that has nothing to do with the swipe.
        if not is_match:
            try:
                send_smart_notification(target_user.firebase_uid, 'like', firestore_db)
            except Exception as exc:
                logger.warning("like notification failed: %s: %s",
                               type(exc).__name__, exc)

    #THE SWIPER USED TO GET A NOTIFICATION about their own match, because the
    #match page was the ONLY entrance to it: a swipe delivered late by the
    #retry queue, or the app being killed while the page was open, left a
    #match nobody could reach.
    #
    #THE MATCHES PAGE IS THAT ENTRANCE NOW. Every live match is listed there
    #whatever happened to the swipe or the app, so the row has nothing left to
    #rescue - and it was the row that made 'match' mean two different things
    #(see the notify dedupe), gave the wrong title to whoever completed the
    #match, and sat dead in the bell once they had answered.

    #match_id so the client can confirm or decline the match it just created.
    #
    #IT IS SET WHETHER OR NOT THIS SWIPE CREATED THE MATCH, while `data` is
    #true only the first time. A retried swipe finds the match already there,
    #so the client has to key off match_id - `data` alone makes a successful
    #retry look like no match at all.
    return {"data": is_match, "match_id": match_id}
