import datetime
from typing import List, Optional
from fastapi import FastAPI, Depends, HTTPException
from dotenv import load_dotenv
from pydantic import BaseModel
from sqlalchemy import func
from database import models
from database.database import engine, get_db
from database import schemas
from sqlalchemy.orm import Session, aliased
from sqlalchemy import and_, or_, case

models.Base.metadata.create_all(bind=engine)

load_dotenv()

app = FastAPI()

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
    #this later will become the profile photos (not pfp)
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

    class Config:
        from_attributes = True

#class that sends swipe record data
class SwipeRequest(BaseModel):
    firebase_token: str
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
    )

    try:
        db.add(new_user)
        db.flush()

        new_settings = models.Settings(  
            user_id=new_user.id,
            is_dark_mode=False,
            is_notifications_on=False,
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
    
    #get users other than you and not users we already saw
    seen_ids = db.query(models.UserSwipes.target_id).filter(  
        models.UserSwipes.user_id == me.id
    ).all()

    seen_ids_list = [x[0] for x in seen_ids]

    seen_ids_list.append(me.id)
    print(seen_ids_list)
    #order the users randomly for now and limit then at 10
    users = db.query(models.User).filter(  
        models.User.id.notin_(seen_ids_list)
    ).order_by(func.random()).limit(10).all()

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
        Incoming.action == "like" or Incoming.action == "super_like",
        or_(
            Outgoing.id == None,
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

    results = []
    for match in matches:
        other_user_id = match.user_a_id if match.user_a_id != me.id else match.user_b_id
        other_user = db.query(models.User).filter(models.User.id == other_user_id).first()

        if other_user: 
            results.append({  
                "match_id": match.id,
                "other_user_id": other_user.id,
                "other_user_name": other_user.username,
                "image_url": other_user.profile_picture,
                #"last_message": for later
            })
        else: 
            raise HTTPException(status_code=404, detail="Other User not found")

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
        raise HTTPException(status_code =403, detail="You are not part of thie match")

    new_message = models.Messages(  
        sender = me.id,
        match_id = message.match_id,
        content = message.content
    )

    db.add(new_message)
    db.commit()

#get messages from db
@app.get("/messages/{match_id}")
def get_messages(match_id: int, firebase_token: str, db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_token == firebase_token).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")
    
    match = db.query(models.Matches).filter(models.Matches.id == match_id).first()

    if not match:
        raise HTTPException(status_code = 404, detail="Match not found")

    messages = db.query(models.Messages).filter(  
        models.Messages.match_id == match_id
    ).order_by(models.Messages.created_at.desc()).all()

    return messages

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
    me = db.query(models.User).filter(models.User.firebase_token == swipe.firebase_token).first()
    if not me:
       raise HTTPException(status_code=404, detail="Current User not found")
    
    query = db.query(models.UserSwipes).filter(  
        models.UserSwipes.user_id == me.id,
        models.UserSwipes.target_id == swipe.target_id
    )

    existing = query.first()

    is_match = False

    if existing:
        if existing.action == swipe.action:
            db.commit()
        else: 
            query.update({models.UserSwipes.action: swipe.action,
                        models.UserSwipes.timestamp: datetime.utcnow()}, synchronize_session=False)
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
