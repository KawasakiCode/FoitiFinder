"""The bell: reading the rows, and marking them read.

The rows themselves are written by notifications.notify (the service module of
the same name) - this file only ever reads them back.
"""

import datetime

from sqlalchemy import and_
from sqlalchemy.orm import aliased

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth import current_uid, verified_claims, verified_email_uid
from database import models, schemas
from database.database import get_db

router = APIRouter()

from api_models import NotificationItem
from typing import List

#The bell in the app bar. Mine, newest first - see models.Notifications for
#why this is a table and not a query over matches.
@router.get("/notifications", response_model = List[NotificationItem])
def get_notifications(uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")

    Other = aliased(models.User)
    rows = db.query(
        models.Notifications,
        Other.name.label("other_name"),
        models.Photos.photo_url.label("other_photo_url"),
    ).outerjoin(
        Other, Other.id == models.Notifications.other_user_id
    ).outerjoin(
        #their profile picture, which is photo 0 - one join rather than a
        #query per row
        models.Photos,
        and_(models.Photos.user_id == models.Notifications.other_user_id,
             models.Photos.display_order == 0),
    ).filter(
        models.Notifications.user_id == me.id
    ).order_by(models.Notifications.created_at.desc()).limit(100).all()

    #the matches these point at, in one query rather than one per row
    match_ids = {note.match_id for note, _, _ in rows if note.match_id}
    matches = {
        match.id: match
        for match in db.query(models.Matches).filter(
            models.Matches.id.in_(match_ids)
        ).all()
    } if match_ids else {}

    def other_has_confirmed(note: models.Notifications) -> bool:
        match = matches.get(note.match_id) if note.match_id else None
        if match is None:
            return False
        theirs = (match.b_confirmed_at if match.user_a_id == me.id
                  else match.a_confirmed_at)
        return theirs is not None

    def actionable(note: models.Notifications) -> bool:
        """Is there still anything to do about this?"""
        match = matches.get(note.match_id) if note.match_id else None
        #the match is gone: declined, or one of the accounts was deleted. The
        #notification stays as a record, but there is nothing behind it.
        if match is None:
            return False
        if note.kind == 'match':
            #"they are waiting on you" - true only until you answer. Answering
            #does not change this row, so the row cannot be what decides.
            mine = (match.a_confirmed_at if match.user_a_id == me.id
                    else match.b_confirmed_at)
            return mine is None
        if note.kind == 'match_revealed':
            #the way back to a handle you have already earned
            return True
        #a decline is a statement; there is nowhere to go
        return False

    return [
        {
            "id": note.id,
            "kind": note.kind,
            #null once the match it pointed at is gone (a decline), which is
            #how the app knows there is nothing to open
            "match_id": note.match_id,
            "other_user_id": note.other_user_id,
            "other_name": other_name,
            "other_photo_url": other_photo_url,
            "created_at": note.created_at,
            "read": note.read_at is not None,
            "actionable": actionable(note),
            "other_confirmed": other_has_confirmed(note),
        }
        for note, other_name, other_photo_url in rows
    ]

@router.post("/notifications/{notification_id}/read")
def mark_notification_read(notification_id: int, uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")

    #user_id in the filter, not just the id: without it anyone could mark
    #anyone's notifications read by guessing numbers
    note = db.query(models.Notifications).filter(
        models.Notifications.id == notification_id,
        models.Notifications.user_id == me.id,
    ).first()
    if not note:
        raise HTTPException(status_code=404, detail="Notification not found")

    #idempotent: the first read is the one that counts, and a second tap must
    #not move the timestamp
    if note.read_at is None:
        note.read_at = datetime.datetime.now(datetime.timezone.utc)
        db.commit()
    return {"read": True}
