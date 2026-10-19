"""Who liked you."""

from sqlalchemy import and_, or_
from sqlalchemy.orm import aliased

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth import current_uid, verified_claims, verified_email_uid
from database import models, schemas
from database.database import get_db

router = APIRouter()

from ages import age_from_birthday
from api_models import LikerProfile
from typing import List

#like endpoints
@router.get("/likes", response_model = List[LikerProfile])
def get_likes(uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")
    
    Incoming = aliased(models.UserSwipes) #they liked me
    Outgoing = aliased(models.UserSwipes) #I liked them

    #find all people that like me that i havent seen and
    #all the people that liked me AFTER i passed on them
    liked_by_users = db.query(
        models.User.id,
        models.User.name,
        models.User.birthday,
        models.Photos.photo_url.label("image_url")
    ).join(
        Incoming, 
        Incoming.user_id == models.User.id
    ).outerjoin(
        Outgoing,
        and_(
            Outgoing.user_id == me.id,
            Outgoing.target_id == models.User.id 
        )
    ).outerjoin(
        models.Photos,
        and_(
            models.Photos.user_id == models.User.id,
            models.Photos.display_order == 0
        )
    ).filter(
        Incoming.target_id == me.id,
        Incoming.action.in_(["like", "super_like"]),
        or_(
            Outgoing.id.is_(None),
            Incoming.timestamp > Outgoing.timestamp,
        ),
    ).all()

    #age is derived here rather than stored, so the rows are mapped by hand
    #instead of handed straight to the response_model
    return [
        {
            "id": row.id,
            "name": row.name,
            "age": age_from_birthday(row.birthday),
            "image_url": row.image_url,
        }
        for row in liked_by_users
    ]
