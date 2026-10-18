import datetime
from typing import List, Optional
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from dotenv import load_dotenv
from pydantic import BaseModel, Field
from sqlalchemy import func
from notifications import send_smart_notification
from database import models
from database.database import engine, get_db
from database import schemas
from sqlalchemy.orm import Session, aliased, selectinload
from sqlalchemy import and_, or_
from firebase_admin import messaging, credentials, firestore, auth
import firebase_admin
from preferences.preferences import preference_to_genders
from university_domains import is_university_email, university_name_for_email
from instagram import normalise_instagram_handle
from ages import age_from_birthday, years_ago
import logging

load_dotenv()

#NOT a logger of our own: uvicorn configures the root logger, so a named child
#of it inherits uvicorn's formatting and level and its output lands in the same
#place as the request log. getLogger() returns the SAME object every call, so
#this is a name for that logger rather than a new one.
#
#Used for things that must not fail a request but must not vanish either -
#a notification that could not be delivered, a token rejected for a reason the
#client is deliberately not told. NEVER log a token, a handle or an email: the
#log is readable by anyone with dashboard access.
logger = logging.getLogger("foitifinder")

app = FastAPI()

cred = credentials.Certificate("serviceAccountKey.json")

if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)

firestore_db = firestore.client()

# --- Authentication ---------------------------------------------------------
# A Firebase UID is an IDENTIFIER, not a credential: trusting one sent by the
# client means anyone who knows a uid can act as that user. Instead the client
# sends the Firebase ID token (a short-lived JWT signed by Google) as
# `Authorization: Bearer <token>`. We verify the signature here and take the uid
# from the VERIFIED claims, so it can't be forged. Every endpoint that needs to
# know "who is calling" must get it from this dependency — never from a path,
# query or body parameter.
bearer_scheme = HTTPBearer()


def verified_claims(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> dict:
    """Verify the caller's Firebase ID token and return its decoded claims."""
    try:
        return auth.verify_id_token(credentials.credentials)
    except Exception:
        # expired, tampered with, wrong project, or not a token at all
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

def verified_email_uid(claims: dict = Depends(verified_claims)) -> str:
    """Like current_uid, but also requires the caller's email to be verified.

    The token is still fully verified (same verified_claims dependency); this
    only adds a condition. Anyone can sign up with a university address they
    don't own, so without this the "university students only" rule would live in
    the app UI alone and be bypassable by calling the API directly.

    Used by every endpoint EXCEPT account creation and the profile read, which
    both must work before verification: POST /users/ creates the very account
    the user is about to verify, and GET /users/me is what the auth router reads
    to decide whether the account exists at all — a 403 there is
    indistinguishable from "no account" and would sign the user out before they
    could ever reach the verification page.
    """
    if claims.get("email_verified") is not True:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Email not verified",
        )
    return claims["uid"]

def current_uid(claims: dict = Depends(verified_claims)) -> str:
    """The uid of the caller, taken from the verified token claims."""
    return claims["uid"]

#class that handles the like data we need to sent
#we dont return likes but data from the users that liked the currentuser
class LikerProfile(BaseModel):
    id: int
    name: str
    age: Optional[int] = None
    image_url: str

    class Config:
        #this ensures that pydantic can read sqlalchemy objects
        from_attributes = True

#class that handles sending back users photos
#NOTE: no firebase_uid — the owner is taken from the verified ID token
class UserPhotos(BaseModel):
    photo_url: str
    display_order: int

    class Config:
        from_attributes = True

#class that is used to return to the frontend card data with photos
class UserCards(BaseModel):
    id: int
    name: str
    age: Optional[int] = None
    #shown under the name on the swipe card, so it travels with the card
    job: Optional[str] = None
    bio: Optional[str] = None
    photos: List[str] = []

    class Config:
        from_attributes = True

#class that sends the match data
class MatchResponse(BaseModel):
    match_id: int
    other_user_id: int
    other_user_name: str
    image_url: Optional[str] = None

    class Config:
        from_attributes = True

#One row of the bell.
#
#NO INSTAGRAM HANDLE, and no text. The handle is only ever handed over by
#/matches/{id}/confirm, so a notification list that carried it would be a
#second, unguarded route to the same thing. The wording lives in the app,
#where it is already translated - the server sends what happened, not how to
#say it.
class NotificationItem(BaseModel):
    id: int
    kind: str
    #null when the match it referred to is gone, which is a notification with
    #nothing to open
    match_id: Optional[int] = None
    other_user_id: Optional[int] = None
    other_name: Optional[str] = None
    other_photo_url: Optional[str] = None
    created_at: datetime.datetime
    read: bool

    class Config:
        from_attributes = True

#class that sends swipe record data
#NOTE: no firebase_uid — the swiper is taken from the verified ID token; only
#the target (someone else) may come from the client
class SwipeRequest(BaseModel):
    target_id: int
    action: str

#create new user and initialize default settings table for the new user
@app.post("/users/", response_model=schemas.User)
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
            is_like_notifications_on=False,
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
@app.get("/users/me", response_model=schemas.User)
def get_user_data(uid: str = Depends(current_uid), db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.firebase_uid == uid).first()

    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    return db_user

#delete a user completely from the database
@app.delete("/users/me")
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
@app.patch("/users/me")
def update_user(user_update: schemas.UserUpdate, uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")

    #make data into a dictionary
    #exclude_unset = True doesnt override data that are null 
    #if updated_data name is null then it wont override the database value because of exclude_unset
    updated_data = user_update.model_dump(exclude_unset=True)

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

#get multiple users for the homepage
@app.get("/users/feed", response_model = List[UserCards])
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

    #base filter: skip yourself and anyone already swiped.
    #
    #There USED to be a score band here - candidates had to sit within +-1.5 of
    #the viewer's users.score. Nothing ever computed that score (the client sent
    #0 at signup), so the band silently passed everyone, and a patched client
    #could have placed itself in anyone's band. Ranking belongs in the ORDER BY,
    #computed per viewer - see the note in the matching design.
    filters = [
        models.User.id.notin_(seen_ids_list),
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

#update one/multiple settings without altering the other
@app.patch("/users/settings")
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
@app.get("/users/settings")
def get_users_settings(uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return db_user.settings

#like endpoints
@app.get("/likes", response_model = List[LikerProfile])
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

#get every match the user currently has
@app.get("/matches", response_model = List[MatchResponse])
def get_matches(uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")
    
    matches = db.query(models.Matches).filter(
        (models.Matches.user_a_id == me.id) | (models.Matches.user_b_id == me.id),
    ).all()

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
        other_user_id = match.user_b_id if match.user_a_id == me.id else match.user_a_id
        other_user = users_by_id.get(other_user_id)

        #a match with a deleted user is skipped rather than failing the whole call
        if not other_user:
            continue

        results.append({
            "match_id": match.id,
            "other_user_id": other_user.id,
            "other_user_name": other_user.name,
            "image_url": picture_by_user.get(other_user.id),
        })

    return results

#Keep-alive target for an external pinger (UptimeRobot / cron-job.org), hit
#every ~10 minutes so Render never reaches its 15-minute spin-down and users
#stop paying the ~60s cold start.
#
#IT MUST NOT TOUCH THE DATABASE. No Depends(get_db), no query, nothing. Neon's
#free plan allows ~400 compute hours a month and suspends after 5 minutes of
#inactivity, so a ping that opens a connection would keep the compute awake
#half of every hour - roughly 365 hours a month, almost the entire allowance
#burnt on pings before a single real user. Over the limit Neon suspends the
#project until the next billing period.
#
#So: Render stays warm, Neon sleeps normally and wakes only for real traffic
#(transparently - see pool_pre_ping in database/database.py).
@app.get("/health")
def health():
    return {"status": "ok"}

#get users photos
@app.get("/photos")
def get_user_photos(uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")
    
    photos = db.query(models.Photos).filter(  
        models.Photos.user_id == me.id
    ).order_by(models.Photos.display_order.asc()).all()
    
    return photos

#store a photo inside the db
@app.post("/photos")
def upload_photo(user_photos: UserPhotos, uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")
    
    new_photo = models.Photos(  
        user_id = me.id,
        photo_url = user_photos.photo_url,
        display_order = user_photos.display_order,
    ) 

    db.add(new_photo)
    db.commit()
    db.refresh(new_photo)

#body for replacing a user's whole photo set in order
#NOTE: no firebase_uid — the owner is taken from the verified ID token
class PhotoSync(BaseModel):
    photo_urls: List[str]

#Reconcile a user's photos to the given ordered list. The edit-profile page
#uploads only NEW files to Firebase Storage (existing photos keep their URL),
#then sends the final ordered URLs here. We wipe and re-insert the rows so
#unchanged photos are never duplicated, removed ones are deleted, and
#The app's own bounds (kMinPhotos / kMaxPhotos in widgets/photo_card.dart),
#enforced here so they hold even when the request does not come from the app.
MIN_PHOTOS = 3
MAX_PHOTOS = 6

#display_order matches the order the user arranged. Only the photo rows are
#touched — the Firebase Storage objects of kept photos are reused via their URL.
@app.put("/photos/sync")
def sync_photos(payload: PhotoSync, uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")

    #EVERY ACCOUNT KEEPS AT LEAST THREE PHOTOS. This endpoint replaces the
    #whole set, so a short list means "delete the rest" - and the profile page
    #is built around three (one after the answers, one after the hobbies, the
    #rest at the end), while the swipe card asks "want to see more?".
    #
    #The app already prevents it (signup will not continue under three, and the
    #edit grid refuses the removal), but that is a rule in one client. A patched
    #build, a crash mid-upload, or a direct call would otherwise leave an
    #account with a profile nobody wants to look at.
    if len(payload.photo_urls) < MIN_PHOTOS:
        raise HTTPException(
            status_code=400,
            detail=f"At least {MIN_PHOTOS} photos are required",
        )

    #...and no more than the grid can hold. The app offers exactly MAX_PHOTOS
    #slots, so a longer list can only come from a patched client or a bug, and
    #the extra rows would be stored and then never shown anywhere.
    if len(payload.photo_urls) > MAX_PHOTOS:
        raise HTTPException(
            status_code=400,
            detail=f"At most {MAX_PHOTOS} photos are allowed",
        )

    #This endpoint wipes and re-inserts, so a photo's story would be destroyed
    #every time the user merely REORDERED their photos. Remember the stories by
    #URL first and re-attach them: a photo that survives the sync keeps its
    #story, one that was removed takes its story with it.
    existing_stories = {
        p.photo_url: p.story
        for p in db.query(models.Photos).filter(
            models.Photos.user_id == me.id
        ).all()
    }

    db.query(models.Photos).filter(
        models.Photos.user_id == me.id
    ).delete(synchronize_session=False)

    for order, photo_url in enumerate(payload.photo_urls):
        db.add(models.Photos(
            user_id=me.id,
            photo_url=photo_url,
            display_order=order,
            #position 0 is the profile picture, which has no story - a photo
            #dragged into that slot leaves its story behind rather than
            #keeping one nothing will ever display
            story=None if order == 0 else existing_stories.get(photo_url),
        ))

    me.has_photos = len(payload.photo_urls) > 0
    db.commit()
    return {"message": "photos synced"}


#body for setting one photo's story
#NOTE: no firebase_uid - the owner is taken from the verified ID token, and
#the photo is looked up scoped to that owner so one user cannot caption
#another user's photo by guessing a URL.
class PhotoStory(BaseModel):
    photo_url: str
    #150 matches kStoryMaxLength in the app. The field there stops typing; this
    #stops a patched client, which is the only reason a length rule in one
    #place is not a rule at all.
    story: Optional[str] = Field(default=None, max_length=150)

#Set (or clear) the story attached to a single photo.
#
#Separate from /photos/sync on purpose: writing a caption should not require
#re-uploading and re-ordering the whole photo set, and this way the story page
#saves one row without touching anything else.
@app.put("/photos/story")
def set_photo_story(payload: PhotoStory, uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")

    photo = db.query(models.Photos).filter(
        models.Photos.user_id == me.id,
        models.Photos.photo_url == payload.photo_url,
    ).first()
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")

    #The profile picture gets no story. It is shown beside a name in the feed,
    #the likes list and matches, where there is nowhere to put a caption, so a
    #story on it would be written and never read. The app hides the option;
    #this is what makes it a rule rather than a UI convention.
    if photo.display_order == 0:
        raise HTTPException(
            status_code=400,
            detail="The profile picture cannot have a story",
        )

    story = (payload.story or "").strip()
    #an empty box means "remove the story", not "store a blank one"
    photo.story = story if story else None

    db.commit()
    return {"message": "story saved"}

#register a swipe
@app.post("/swipes")
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

    #match_id so the client can confirm or decline the match it just created.
    #`data` keeps its name: older builds read it and only care whether it is
    #a match at all.
    return {"data": is_match, "match_id": match_id}

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


def _notify(db: Session, user: models.User, kind: str, *,
            match_id: int | None = None, other_user_id: int | None = None) -> None:
    """Record a notification AND try to push it, in that order.

    THE ROW IS THE DELIVERY, the push is a nudge. Firebase can be down, the
    device can have no token, the user can have swiped the banner away before
    reading it - none of which may lose the fact that something happened. The
    row is written on the caller's session and committed with whatever else
    the caller is doing, so a notification cannot exist without the change
    that caused it, or the other way round.
    """
    db.add(models.Notifications(
        user_id=user.id,
        kind=kind,
        match_id=match_id,
        other_user_id=other_user_id,
    ))
    try:
        send_smart_notification(user.firebase_uid, kind, firestore_db)
    except Exception as exc:
        #already recorded, so the app will show it on next launch regardless
        logger.warning("push failed (%s): %s: %s", kind, type(exc).__name__, exc)


#The bell in the app bar. Mine, newest first - see models.Notifications for
#why this is a table and not a query over matches.
@app.get("/notifications", response_model = List[NotificationItem])
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
        }
        for note, other_name, other_photo_url in rows
    ]


@app.post("/notifications/{notification_id}/read")
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


@app.post("/matches/{match_id}/confirm")
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
    _notify(
        db, other,
        'match_revealed' if revealed else 'match',
        match_id=match.id,
        other_user_id=me.id,
    )
    db.commit()

    return {
        "revealed": revealed,
        "name": other.name,
        "instagram_handle": other.instagram_handle if revealed else None,
    }


@app.post("/matches/{match_id}/decline")
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
            #match_id is deliberately left out: the row above has just been
            #deleted, and a notification pointing at a match that no longer
            #exists is how a dead end gets tapped
            _notify(db, other, 'match_declined', other_user_id=me.id)
            db.commit()

    return {"declined": True}


#get single user by id
#this one legitimately looks up ANOTHER user, but still requires a valid token so
#only signed-in users can read profiles (uid unused beyond that gate)
#The full profile of ANOTHER user, for the page you reach by tapping a card.
#
#WHAT IS LEFT OUT MATTERS MORE THAN WHAT IS IN: no email, no firebase_uid, no
#preferences (who they want to see is their business), and NO instagram_handle -
#that is handed over on a confirmed match and nowhere else. A field added to
#the model does not appear here unless someone adds it below on purpose.
@app.get("/users/{user_id}/profile")
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

@app.get("/single/user/{user_id}")
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

def notify_user_of_like_or_match(target_fcm_token: str, caller: str):
    #Make a data message not a notification
    if caller == "like":
        message = messaging.Message(
            data = {
                'type': 'new_like',
                'count': '1',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK'
            },
            token = target_fcm_token
        )
    else:
        message = messaging.Message(  
            data = {
                'type': 'new_match',
                'count': '1',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK'
            },
            token = target_fcm_token
        )
    messaging.send(message)
    