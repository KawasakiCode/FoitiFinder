"""Another person, as far as you are allowed to see them."""

from sqlalchemy.orm import selectinload

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth import current_uid, verified_claims, verified_email_uid
from database import models, schemas
from database.database import get_db

router = APIRouter()

from ages import age_from_birthday

#get single user by id
#this one legitimately looks up ANOTHER user, but still requires a valid token so
#only signed-in users can read profiles (uid unused beyond that gate)
#The full profile of ANOTHER user, for the page you reach by tapping a card.
#
#WHAT IS LEFT OUT MATTERS MORE THAN WHAT IS IN: no email, no firebase_uid, no
#preferences (who they want to see is their business), and NO instagram_handle -
#that is handed over on a confirmed match and nowhere else. A field added to
#the model does not appear here unless someone adds it below on purpose.
@router.get("/users/{user_id}/profile")
def get_user_profile(user_id: int, uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    user = db.query(models.User).options(
        selectinload(models.User.photos)
    ).filter(models.User.id == user_id).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    sorted_photos = sorted(user.photos, key=lambda p: p.display_order)

    return {
        "id": user.id,
        "name": user.name,
        "age": age_from_birthday(user.birthday),
        "height_cm": user.height_cm,
        "bio": user.bio,
        #photos carry their stories: the caption belongs to the photo, and the
        #page shows them together
        "photos": [
            {"url": p.photo_url, "story": None if p.display_order == 0 else p.story}
            for p in sorted_photos
        ],
        "job": user.job,
        "volunteering": user.volunteering,
        "university": user.university,
        "major": user.major,
        "is_currently_studying": user.is_currently_studying,
        "city": user.city,
        "languages_spoken": user.languages_spoken,
        "interest_tags": user.interest_tags,
        "trait_tags": user.trait_tags,
        "alcohol": user.alcohol,
        "smoking": user.smoking,
        "dating_intention": user.dating_intention,
        "kids": user.kids,
        "religion": user.religion,
        "political_view": user.political_view,
        "sexual_orientation": user.sexual_orientation,
        "pronouns": user.pronouns,
    }

@router.get("/single/user/{user_id}")
def get_single_user(user_id: int, uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    sorted_photos = sorted(user.photos, key = lambda x: x.display_order)
    photos_urls = [p.photo_url for p in sorted_photos]

    return {
        "id": user.id,
        "name": user.name,
        "age": age_from_birthday(user.birthday),
        "job": user.job,
        "bio": user.bio,
        "photos": photos_urls,
    }
