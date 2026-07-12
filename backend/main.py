import os
import datetime
from typing import List, Optional
from fastapi import FastAPI, Depends, HTTPException, WebSocket, WebSocketDisconnect
from dotenv import load_dotenv
from pydantic import BaseModel
from sqlalchemy import func
from notifications import send_smart_notification
from database import models
from database.database import SessionLocal, engine, get_db
from database import schemas
from sqlalchemy.orm import Session, aliased, selectinload
from sqlalchemy import and_, or_, case
import json
from firebase_admin import messaging, credentials, firestore
import firebase_admin
import tempfile
import requests
from preferences.preferences import interests_to_genders
#NOTE: get_face_score (Odin: MediaPipe landmarks + XGBoost) is imported lazily
#inside the calculate-rating endpoint, so the server boots fast instead of
#loading the ML stack on startup.

models.Base.metadata.create_all(bind=engine)

load_dotenv()

app = FastAPI()

cred = credentials.Certificate("serviceAccountKey.json")

if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)

firestore_db = firestore.client()

#class that handles the likes 
class LikeRequest(BaseModel):
    firebase_token: str
    liked_id: int 
    is_super_like: bool = False

#class that handles the messsages
class Messages(BaseModel):
    firebase_token: str
    match_id: int
    content: str

#class that handles the like data we need to sent
#we dont return likes but data from the users that liked the currentuser
class LikerProfile(BaseModel):
    id: int
    username: str
    age: Optional[int] = None
    image_url: str

    class Config:
        #this ensures that pydantic can read sqlalchemy objects
        from_attributes = True

#class that handles sending back users photos
class UserPhotos(BaseModel):
    firebase_token: str
    photo_url: str
    display_order: int

    class Config:
        from_attributes = True

#class that is used to return to the frontend card data with photos
class UserCards(BaseModel):
    id: int
    username: str
    age: Optional[int] = None
    bio: Optional[str] = None
    photos: List[str] = []

    class Config:
        from_attributes = True

#class that sends the match aka dm data
class MatchResponse(BaseModel):
    match_id: int
    other_user_id: int
    other_user_name: str
    image_url: Optional[str] = None
    last_message: Optional[str] = None

    class Config:
        from_attributes = True

#class that sends swipe record data
class SwipeRequest(BaseModel):
    firebase_uid: str
    target_id: int
    action: str

#create new user and initialize default settings table for the new user
@app.post("/users/", response_model=schemas.User)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    #check if user with the same firebase.uid already is registered and return and exception if yes
    db_user = db.query(models.User).filter(models.User.firebase_token == user.firebase_token).first()
    if db_user: 
        raise HTTPException(status_code = 400, detail="User already exists")
    
    new_user = models.User(  
        username = user.username,
        full_name=user.full_name,
        has_finished_set_up=user.has_finished_set_up,
        firebase_token=user.firebase_token,
        profile_picture=user.profile_picture,
        bio=user.bio,
        age=user.age,
        gender=user.gender,
        min_age_range=user.min_age_range,
        max_age_range=user.max_age_range,
        show_out_of_range=user.show_out_of_range,
        is_balanced=user.is_balanced,
        interests=user.interests,
        has_photos=user.has_photos,
        score=user.score
    )

    try:
        db.add(new_user)
        db.flush()

        new_settings = models.Settings(  
            user_id=new_user.id,
            is_dark_mode=True,
            is_like_notifications_on=False,
            is_message_notifications_on=False,
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
@app.get("/users/{firebase_token}")
def get_user_data(firebase_token: str, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.firebase_token == firebase_token).first()

    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    return db_user

#update one/multiple user attributes without altering the others
@app.patch("/users/{firebase_token}")
def update_user(firebase_token: str, user_update: schemas.UserUpdate, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.firebase_token == firebase_token).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")

    #make data into a dictionary
    #exclude_unset = True doesnt override data that are null 
    #if updated_data username is null then it wont override the database value because of exclude_unset
    updated_data = user_update.model_dump(exclude_unset=True)
    #loop through the dictionary adding only values that are not null
    for key, value in updated_data.items():
        setattr(db_user, key, value)
    
    db.commit()
    db.refresh(db_user)
    return db_user

#get multiple users for the homepage
@app.get("/users/feed/{firebase_token}", response_model = List[UserCards])
def get_swipe_feed(firebase_token: str, db: Session = Depends(get_db)):
    #first get the current user id to exclude it
    me = db.query(models.User).filter(models.User.firebase_token == firebase_token).first()
    if not me:
        raise HTTPException(status_code=404, detail='Current User not found')

    if me.score is not None and me.score != 0:
        min_score = me.score - 1.5
        max_score = me.score + 1.5
    else:
        min_score = 0
        max_score = 10

    #get users other than you and not users we already saw
    seen_ids = db.query(models.UserSwipes.target_id).filter(
        models.UserSwipes.user_id == me.id
    ).all()

    seen_ids_list = [x[0] for x in seen_ids]

    seen_ids_list.append(me.id)

    #base filters: skip already swiped users and stay within the score band
    filters = [
        models.User.id.notin_(seen_ids_list),
        models.User.score >= min_score,
        models.User.score <= max_score,
    ]

    #age range filter, only applied when the user hasn't opted to see people
    #outside their range. Profiles without an age are kept so they still show.
    if not me.show_out_of_range:
        if me.min_age_range is not None:
            filters.append(or_(models.User.age >= me.min_age_range, models.User.age.is_(None)))
        if me.max_age_range is not None:
            filters.append(or_(models.User.age <= me.max_age_range, models.User.age.is_(None)))

    #gender preference filter derived from the viewer's interests. Candidates
    #with no gender set are kept so incomplete profiles still surface.
    wanted_genders = interests_to_genders(me.interests)
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
            "username": user.username,
            "age": user.age,
            "bio": user.bio,
            "photos": photo_urls,
        })
    return results

#update one/multiple settings without altering the other
@app.patch("/users/settings/{firebase_token}")
def update_settings(firebase_token: str, settings_update: schemas.SettingsUpdate, db: Session = Depends(get_db)):
    db_user =  db.query(models.User).filter(models.User.firebase_token == firebase_token).first()
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
@app.get("/users/settings/{firebase_token}")
def get_users_settings(firebase_token: str, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.firebase_token == firebase_token).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return db_user.settings

#like endpoints
@app.get("/likes/{firebase_token}", response_model = List[LikerProfile])
def get_likes(firebase_token: str, db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_token == firebase_token).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")
    
    Incoming = aliased(models.UserSwipes) #they liked me
    Outgoing = aliased(models.UserSwipes) #I liked them

    #find all people that like me that i havent seen and
    #all the people that liked me AFTER i passed on them
    liked_by_users = db.query(
        models.User.id,
        models.User.username,
        models.User.age,
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

    #pydantic uses the response_model and automatically 
    #filters only the data specified in the likerProfile class
    return liked_by_users

#get all matches that the user hasnt seen yet
@app.get("/matches/unseen")
def get_unseen_matches(firebase_token: str, db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_token == firebase_token).first()
    if not me:
       raise HTTPException(status_code=404, detail="Current User not found")
    
    new_matches = db.query(  
        models.User.id,
        models.User.username,
        models.User.profile_picture,
        models.Matches.id.label("match_id")
    ).join(  
        models.Matches,
        or_(
            models.Matches.user_a_id == models.User.id,
            models.Matches.user_b_id == models.User.id,
        )
    ).filter(  
        or_(models.Matches.user_a_id == me.id, models.Matches.user_b_id == me.id),
        models.User.id != me.id,
        case(  
            (models.Matches.user_a_id == me.id, models.Matches.user_a_saw == False),
            (models.Matches.user_b_id == me.id, models.Matches.user_b_saw == False),
            else_=False
        )
    ).all()

    results = []
    for row in new_matches:
        results.append({
            "other_user_id": row.id,
            "other_user_name": row.username,
            "image_url": row.profile_picture,
            "match_id": row.match_id
        })
    
    return results

#get matches to load chats
@app.get("/matches/{firebase_token}", response_model = List[MatchResponse])
def get_matches(firebase_token: str, db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_token == firebase_token).first()
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

    #one query for the latest message of every match. We grab the max id per
    #match (ids grow with time) then fetch those rows in a single round trip.
    match_ids = [match.id for match in matches]
    latest_msg_ids = db.query(func.max(models.Messages.id)).filter(
        models.Messages.match_id.in_(match_ids)
    ).group_by(models.Messages.match_id).subquery()

    last_msg_by_match = {
        msg.match_id: msg.content
        for msg in db.query(models.Messages).filter(models.Messages.id.in_(latest_msg_ids)).all()
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
            "other_user_name": other_user.username,
            "image_url": other_user.profile_picture,
            "last_message": last_msg_by_match.get(match.id)
        })

    return results
    
#upload message to db
@app.post("/messages/store")
def upload_messages(message: Messages, db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_token == message.firebase_token).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")
    
    #check if the user running the query is actually one of the 2 from the conversation
    match = db.query(models.Matches).filter(models.Matches.id == message.match_id).first()
    if not match or (match.user_a_id != me.id and match.user_b_id != me.id):
        raise HTTPException(status_code =403, detail="You are not part of this match")

    if match.user_a_id == me.id:
        other_user_id = match.user_b_id
    elif match.user_b_id == me.id:
        other_user_id = match.user_a_id

    new_message = models.Messages(
        sender = me.id,
        match_id = message.match_id,
        content = message.content
    )

    db.add(new_message)
    db.commit()
    db.refresh(new_message)

    #The message is already saved. Notifying the recipient is best-effort: a
    #missing user, missing fcm token or disabled notifications must NOT turn a
    #successful send into an error for the sender.
    target_user = db.query(models.User).filter(models.User.id == other_user_id).first()
    if target_user:
        try:
            send_smart_notification(target_user.firebase_token, 'message', firestore_db)
        except Exception:
            pass

    return {"status": "ok", "message_id": new_message.id}

#get messages from db
@app.get("/messages/{match_id}")
def get_messages(match_id: int, firebase_token: str, limit: Optional[int] = None, offset: int = 0, db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_token == firebase_token).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")

    match = db.query(models.Matches).filter(models.Matches.id == match_id).first()

    if not match:
        raise HTTPException(status_code = 404, detail="Match not found")

    #newest first. limit/offset are optional so existing callers that pass
    #neither keep getting the full history (backwards compatible), while a
    #paginating client can request a page at a time.
    query = db.query(models.Messages).filter(
        models.Messages.match_id == match_id
    ).order_by(models.Messages.created_at.desc())

    if limit is not None:
        query = query.offset(offset).limit(limit)

    return query.all()

#get users photos
@app.get("/photos/{firebase_token}")
def get_user_photos(firebase_token: str, db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_token == firebase_token).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")
    
    photos = db.query(models.Photos).filter(  
        models.Photos.user_id == me.id
    ).order_by(models.Photos.display_order.asc()).all()
    
    return photos

#store a photo inside the db
@app.post("/photos")
def upload_photo(user_photos: UserPhotos, db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_token == user_photos.firebase_token).first()
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

#register a swipe
@app.post("/swipes")
def record_swipe(swipe: SwipeRequest, db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_token == swipe.firebase_uid).first()
    if not me:
       raise HTTPException(status_code=404, detail="Current User not found")

    query = db.query(models.UserSwipes).filter(  
        models.UserSwipes.user_id == me.id,
        models.UserSwipes.target_id == swipe.target_id
    )

    existing = query.first()

    is_match = False

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
                new_match = models.Matches(user_a_id=me.id, user_b_id=swipe.target_id, user_a_saw=False, user_b_saw=False)
                db.add(new_match)
                db.commit()
                is_match = True

        #The following code is used to grab the target user's fcm token to be able to send 
        #a notification to them
        #Remember firebase uid is NOT the same as the FCM token
        target_user = db.query(models.User).filter(models.User.id == swipe.target_id).first()
        if not target_user:
            raise HTTPException(status_code=404, detail="Target User not found")

        user_ref = firestore_db.collection('users').document(target_user.firebase_token)
        user_doc = user_ref.get()

        if user_doc.exists:
            user_data = user_doc.to_dict()

            target_fcm_token = user_data.get('fcm_token')

            if target_fcm_token:
                if is_match:
                    notify_user_of_like_or_match_or_message(target_fcm_token, 'match')
                    send_smart_notification(target_user.firebase_token, 'match', firestore_db)
                elif not is_match:
                    notify_user_of_like_or_match_or_message(target_fcm_token, 'like')
                    send_smart_notification(target_user.firebase_token, 'like', firestore_db)
                else: 
                    raise HTTPException(status_code=404, detail="Target User not found")
            else: 
                raise HTTPException(status_code=404, detail="Target User not found")

    return {"data": is_match}

#get single user by id
@app.get("/single/user/{user_id}")
def get_single_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    sorted_photos = sorted(user.photos, key = lambda x: x.display_order)
    photos_urls = [p.photo_url for p in sorted_photos]

    return {
        "id": user.id,
        "username": user.username,
        "age": user.age,
        "bio": user.bio,
        "photos": photos_urls,
    }

#update match seen
@app.patch("/matches/seen/{match_id}")
def update_match_seen(match_id: int, firebase_token: str,db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_token == firebase_token).first()
    if not me: 
        raise HTTPException(status_code=404, detail="Current User not found")

    match = db.query(models.Matches).filter(models.Matches.id == match_id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    
    if match.user_a_id == me.id:
        match.user_a_saw = True
    elif match.user_b_id == me.id:
        match.user_b_saw = True
    else: 
        raise HTTPException(status_code=403, detail="You are not part of this match")
    
    db.commit()
    return {"message": "Match seen updated"}

#get user's score using the ai model
@app.post("/users/{firebase_token}/calculate-rating")
def calculate_user_rating(firebase_token: str, db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_token == firebase_token).first()
    if not me: 
        raise HTTPException(status_code=404, detail="Current User not found")
    
    photo_urls = []
    for photo in me.photos:
        photo_urls.append(photo.photo_url)

    if not photo_urls:
        raise HTTPException(status_code=400, detail="User has no photos")

    #Lazy import: loads MediaPipe/XGBoost only now, the first time scoring is
    #actually requested, instead of at server startup.
    #Odin lives at the repo root (one level above backend/), while this process
    #runs with backend/ as its working dir — so put the repo root on sys.path
    #before importing, otherwise a bare `from Odin...` can't be resolved.
    import sys
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if repo_root not in sys.path:
        sys.path.insert(0, repo_root)
    from Odin.main import get_face_score

    #The Odin pipeline needs to know which sex-specific model to use. Gender is
    #stored capitalised ("Male"/"Female"); the models are keyed "male"/"female".
    #Default to "male" when gender is missing/unrecognised so a photo still gets
    #scored rather than silently skipped.
    sex = (me.gender or "").lower()
    if sex not in ("male", "female"):
        sex = "male"

    final_score = None

    #Loop through photos
    for url in photo_urls[:6]:
        temp_path = None
        try: 
            #Download the image from Firebase Storage
            response = requests.get(url, stream=True)
            response.raise_for_status()

            #Create a temp file for the Odin scorer to read
            with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as temp_file:
                for chunk in response.iter_content(chunk_size=8192):
                    temp_file.write(chunk)
                temp_path = temp_file.name
            
            score = get_face_score(temp_path, sex)

            if score is not None:
                final_score = score
                break #Face found stop iterating
        except Exception:
            continue
        finally: 
            if temp_path and os.path.exists(temp_path):
                os.remove(temp_path)

    #fall back to 0 when no face was found in any photo. Use final_score (not
    #the loop variable, which may be unbound if every download failed).
    if final_score is None:
        final_score = 0

    me.score = final_score
    db.commit()

    return {"message": "score given"}

#Connection Manager manages websockets
#Keeps online users and sends messages
class ConnectionManager:
    def __init__(self):
        # Dictionary to map user_id -> active WebSocket connection
        self.active_connections: dict[int, WebSocket] = {}

    async def connect(self, websocket: WebSocket, user_id: int):
        await websocket.accept()
        self.active_connections[user_id] = websocket
        print(f"User {user_id} connected. Total online: {len(self.active_connections)}")

    def disconnect(self, user_id: int):
        if user_id in self.active_connections:
            del self.active_connections[user_id]
            print(f"User {user_id} disconnected.")

    async def send_personal_message(self, message: dict, receiver_id: int):
        # Only send if the recipient is currently online
        if receiver_id in self.active_connections:
            websocket = self.active_connections[receiver_id]
            await websocket.send_json(message)

manager = ConnectionManager()

#websocket endpoint
@app.websocket("/ws/chat/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: int):
    # 1. Open the tunnel
    await manager.connect(websocket, user_id)
    
    try:
        while True:
            # 2. Wait indefinitely for a message from this user
            data = await websocket.receive_text()
            message_payload = json.loads(data)
            
            
            db: Session = SessionLocal()
            try: 
                me = db.query(models.User).filter(models.User.id == user_id).first()
                if not me:
                    raise HTTPException(status_code=404, detail="Current User not found")

                match_id = message_payload.get("match_id")
                receiver_id = message_payload.get("to_user")

                #Validate that the sender is actually part of this match before
                #relaying anything. We only relay here, persistence is handled by
                #the REST /messages/store endpoint the client also calls, so we
                #must NOT insert again or every message ends up stored twice.
                match = db.query(models.Matches).filter(models.Matches.id == match_id).first()
                if match and (match.user_a_id == me.id or match.user_b_id == me.id):
                    message_payload["sender"] = me.id
                    await manager.send_personal_message(message_payload, receiver_id)
            except Exception as e:
                print(e)
            finally:
                db.close()
    except WebSocketDisconnect:
        # 4. Handle the user closing the app
        manager.disconnect(user_id)

def notify_user_of_like_or_match_or_message(target_user_firebase_token: str, caller: str):
    #Make a data message not a notification
    if caller == "like":
        message = messaging.Message(  
            data = {
                'type': 'new_like',
                'count': '1',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK'
            },
            token = target_user_firebase_token
        )
    elif caller == "message":
        message = messaging.Message(
            data = {
                'type': 'new_message',
                'count': '1',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK'
            },
            token = target_user_firebase_token
        )
    else:
        message = messaging.Message(  
            data = {
                'type': 'new_match',
                'count': '1',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK'
            },
            token = target_user_firebase_token
        )
    messaging.send(message)
    