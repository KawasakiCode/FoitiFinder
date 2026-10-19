"""The swipe deck: who is offered, and who is deliberately not."""

from sqlalchemy import func, or_

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth import current_uid, verified_claims, verified_email_uid
from database import models, schemas
from database.database import get_db

router = APIRouter()

from sqlalchemy.orm import selectinload

from ages import age_from_birthday, years_ago
from api_models import UserCards
from preferences.preferences import preference_to_genders
from typing import List

#get multiple users for the homepage
@router.get("/users/feed", response_model = List[UserCards])
def get_swipe_feed(uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    #first get the current user id to exclude it
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail='Current User not found')

    #get users other than you and not users we already saw
    seen_ids = db.query(models.UserSwipes.target_id).filter(
        models.UserSwipes.user_id == me.id
    ).all()

    seen_ids_list = [x[0] for x in seen_ids]

    seen_ids_list.append(me.id)

    #WHOEVER LIKED YOU IS NOT IN THE DECK. They are on the likes page, and
    #that is the only place they should be decided about.
    #
    #This is not about keeping a surprise. A card in the deck can be passed
    #with a flick, and a pass is written with a newer timestamp than their
    #like - which is exactly what makes the likes query stop surfacing them.
    #So the deck could silently consume a guaranteed match that the user was
    #never told was on offer. Nobody can make an informed decision about
    #someone whose interest is hidden from them at the moment they decide.
    #
    #A pass FROM them is deliberately not excluded: it costs a card in the
    #deck, but hiding people who have already passed on you is a different
    #decision (it would make an empty deck mean "everyone said no") and worth
    #making on purpose rather than as a side effect of this.
    liked_me_ids = [
        x[0] for x in db.query(models.UserSwipes.user_id).filter(
            models.UserSwipes.target_id == me.id,
            models.UserSwipes.action.in_(["like", "super_like"]),
        ).all()
    ]

    #base filter: skip yourself and anyone already swiped.
    #
    #There USED to be a score band here - candidates had to sit within +-1.5 of
    #the viewer's users.score. Nothing ever computed that score (the client sent
    #0 at signup), so the band silently passed everyone, and a patched client
    #could have placed itself in anyone's band. Ranking belongs in the ORDER BY,
    #computed per viewer - see the note in the matching design.
    filters = [
        models.User.id.notin_(seen_ids_list + liked_me_ids),
    ]

    #Age range filter, always applied - the range the user picked is the range
    #they get. Expressed as BIRTHDAY CUTOFFS rather than age comparisons: age is
    #no longer a column, and comparing the raw birthday column to a constant
    #date keeps an index on it usable. Profiles with no birthday are kept so
    #incomplete profiles still surface.
    #
    #  age >= min  <=>  born on or before the day they turned min
    #  age <= max  <=>  born after the day they would have turned max + 1
    if me.min_age_range is not None:
        filters.append(or_(models.User.birthday <= years_ago(me.min_age_range),
                           models.User.birthday.is_(None)))
    if me.max_age_range is not None:
        filters.append(or_(models.User.birthday > years_ago(me.max_age_range + 1),
                           models.User.birthday.is_(None)))

    #gender preference filter derived from the viewer's preferred_gender. Candidates
    #with no gender set are kept so incomplete profiles still surface.
    wanted_genders = preference_to_genders(me.preferred_gender)
    if wanted_genders is not None:
        filters.append(or_(models.User.gender.in_(wanted_genders), models.User.gender.is_(None)))

    #order the users randomly for now and limit then at 10
    #selectinload pulls every user's photos in a single extra query (no N+1)
    users = db.query(models.User).options(
        selectinload(models.User.photos)
    ).filter(*filters).order_by(func.random()).limit(10).all()

    results = []
    for user in users:
        #sort photos by display order
        sorted_photos = sorted(user.photos, key = lambda x: x.display_order)
        photo_urls = [p.photo_url for p in sorted_photos]

        if not photo_urls:
            photo_urls = []
        
        results.append({
            "id": user.id,
            "name": user.name,
            "age": age_from_birthday(user.birthday),
            "job": user.job,
            "bio": user.bio,
            "photos": photo_urls,
        })
    return results
