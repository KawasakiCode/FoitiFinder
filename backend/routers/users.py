"""The account itself: creating it, reading it, editing it, deleting it."""

from firebase_admin import auth

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth import current_uid, verified_claims, verified_email_uid
from database import models, schemas
from database.database import get_db

router = APIRouter()

from ages import MINIMUM_AGE, is_old_enough
from app_logging import logger
from instagram import normalise_instagram_handle
from university_domains import is_university_email, university_name_for_email

#create new user and initialize default settings table for the new user
@router.post("/users/", response_model=schemas.User)
def create_user(
    user: schemas.UserCreate,
    uid: str = Depends(current_uid),
    claims: dict = Depends(verified_claims),
    db: Session = Depends(get_db),
):
    #the signup page already blocks non-university emails, but a client can be
    #patched or the endpoint called directly, so re-check server side. The email
    #comes from the VERIFIED token claims (never from the request body); if the
    #token carries none we ask the Admin SDK for the account's address.
    email = claims.get("email")
    if not email:
        try:
            email = auth.get_user(uid).email
        except Exception:
            email = None

    if not is_university_email(email):
        raise HTTPException(
            status_code=403,
            detail="Email domain is not a supported university domain",
        )

    #the row is keyed to the VERIFIED uid, so a caller can only ever create their
    #own account — any firebase_uid in the body is ignored
    db_user = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if db_user:
        raise HTTPException(status_code = 400, detail="User already exists")

    #OLD ENOUGH, OR NOTHING IS CREATED. The app's date picker will not offer
    #an under-age date, so this only ever refuses a request that did not come
    #from it - which is the point: a client-side cap is one line in one
    #widget, and the column has to mean something regardless of what sent it.
    #See ages.is_old_enough for what this does and does not catch.
    if not is_old_enough(user.birthday):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"You must be at least {MINIMUM_AGE} to use FoitiFinder",
        )

    new_user = models.User(
        name = user.name,
        #DERIVED HERE, never taken from the request. It comes from the same
        #verified email the domain check above just passed, which is what makes
        #"studies at X" worth anything - see university_name_for_email.
        university = university_name_for_email(email),
        has_finished_set_up=user.has_finished_set_up,
        firebase_uid=uid,
        bio=user.bio,
        birthday=user.birthday,
        height_cm=user.height_cm,
        gender=user.gender,
        min_age_range=user.min_age_range,
        max_age_range=user.max_age_range,
        min_height_preference=user.min_height_preference,
        max_height_preference=user.max_height_preference,
        preferred_gender=user.preferred_gender,
        has_photos=user.has_photos,
    )

    try:
        db.add(new_user)
        db.flush()

        new_settings = models.Settings(  
            user_id=new_user.id,
            is_dark_mode=True,
            is_match_notifications_on=False,
            language='el'
        )

        db.add(new_settings)
        db.commit()
        db.refresh(new_user)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

    return new_user

#get users data
@router.get("/users/me", response_model=schemas.User)
def get_user_data(uid: str = Depends(current_uid), db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.firebase_uid == uid).first()

    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    return db_user

#delete a user completely from the database
@router.delete("/users/me")
def delete_user(
    uid: str = Depends(current_uid),
    db: Session = Depends(get_db),
):
    db_user = db.query(models.User).filter(models.User.firebase_uid == uid).first()

    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")

    db.delete(db_user)
    db.commit()

#update one/multiple user attributes without altering the others
@router.patch("/users/me")
def update_user(user_update: schemas.UserUpdate, uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")

    #make data into a dictionary
    #exclude_unset = True doesnt override data that are null 
    #if updated_data name is null then it wont override the database value because of exclude_unset
    updated_data = user_update.model_dump(exclude_unset=True)

    #THE OTHER DOOR. Account settings lets somebody change their birthday
    #after signup, so a check only at creation would be a check somebody can
    #walk around by editing afterwards. Only validated when a birthday is
    #actually being sent: exclude_unset means an absent key is "leave it
    #alone", and the stored value has already passed this once.
    if "birthday" in updated_data and not is_old_enough(updated_data["birthday"]):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"You must be at least {MINIMUM_AGE} to use FoitiFinder",
        )

    #The app clears a free-text field by sending "", because a null would be
    #dropped by exclude_unset and read as "leave it alone". Store NULL for
    #those so "never set" and "cleared" are the same state in the database.
    #Only fields the user is allowed to empty - name is
    #required and are validated before they ever get here.
    #`university` is derived from the verified email at signup and is not the
    #client's to change. Dropping it here rather than erroring keeps old app
    #builds working: they simply cannot move it.
    updated_data.pop("university", None)

    #The single-answer choices (alcohol, smoking...) are cleared the same way.
    for key in ("city", "job", "volunteering", "major",
                "alcohol", "smoking", "dating_intention", "kids",
                "sexual_orientation", "pronouns",
                "religion", "political_view"):
        if isinstance(updated_data.get(key), str) and not updated_data[key].strip():
            updated_data[key] = None

    #THE HANDLE IS CLEANED SERVER SIDE TOO, not only in the app. It is the
    #entire payoff of a match (there is no chat), it is the one field another
    #user will be handed, and an old or patched client must not be able to put
    #"@maria pap" or a share link with a tracking query string into the column.
    #None back from the normaliser means it cannot be a handle at all - and
    #since a handle is required, that is an error rather than "cleared".
    if "instagram_handle" in updated_data:
        handle = normalise_instagram_handle(updated_data["instagram_handle"])
        if handle is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="instagram_handle is not a valid Instagram username",
            )
        updated_data["instagram_handle"] = handle

    #These columns are NOT NULL, so an explicit null would be a 500 from the
    #database. For the arrays null can only mean "nothing picked", so store
    #that; for the rest there is no sensible meaning, so leave the value alone.
    for key in ("interest_tags", "trait_tags",
                "languages_spoken", "preferred_alcohol", "preferred_smoking",
                "preferred_dating_intention", "preferred_kids",
                "preferred_languages"):
        if key in updated_data and updated_data[key] is None:
            updated_data[key] = []
    for key in ("name", "has_finished_set_up", "has_photos", "show_outside_residence"):
        if key in updated_data and updated_data[key] is None:
            del updated_data[key]

    #loop through the dictionary adding only values that are not null
    for key, value in updated_data.items():
        setattr(db_user, key, value)
    
    db.commit()
    db.refresh(db_user)
    return db_user

#update one/multiple settings without altering the other
@router.patch("/users/settings")
def update_settings(settings_update: schemas.SettingsUpdate, uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    db_user =  db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    #since we defined relationship in models.py we can instantly grab the settings 
    db_user_settings = db_user.settings
    if not db_user_settings:
        raise HTTPException(status_code=404, detail="Settings not found for this user")
    
    #same logic with update_user
    updated_data = settings_update.model_dump(exclude_unset=True)

    for key, value in updated_data.items():
        setattr(db_user_settings, key, value)
    
    db.commit()
    db.refresh(db_user_settings)
    return db_user_settings

#get user's settings
@router.get("/users/settings")
def get_users_settings(uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return db_user.settings
