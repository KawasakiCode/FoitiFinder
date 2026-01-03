from typing import List
from fastapi import FastAPI, Depends, HTTPException
from dotenv import load_dotenv
from pydantic import BaseModel
from sqlalchemy import func
from database import models
from database.database import engine, get_db
from database import schemas
from sqlalchemy.orm import Session

models.Base.metadata.create_all(bind=engine)

load_dotenv()

app = FastAPI()

#class that stores the user id the user already saw to not allow duplicate showings
class FeedRequest(BaseModel): 
    seen_user_ids: List[int] = []

#class that handled the likes 
class LikeRequest(BaseModel):
    firebase_token: str
    liked_id: int 
    is_super_like: bool = False

#create new user and initialize default settings table for the new user
@app.post("/users/", response_model=schemas.User)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    #chech if user with the same firebase.uid already is registered and return and exception if yes
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
@app.post("/users/feed/{firebase_token}")
def get_swipe_feed(firebase_token: str, seen_users: FeedRequest, db: Session = Depends(get_db)):
    #first get the current user id to exclude it 
    me = db.query(models.User).filter(models.User.firebase_token == firebase_token).first()
    if not me:
        raise HTTPException(status_code=404, detail='Current User not found')
    
    #get users other than you and not users we already saw
    query = db.query(models.User).filter(  
        models.User.id != me.id,
        models.User.id.notin_(seen_users.seen_user_ids)
    )

    #order the users randomly for now and limit then at 10
    users = query.order_by(func.random()).limit(10).all()

    return users

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
@app.post("/likes/{firebase_token}")
def like_user(request: LikeRequest, db: Session = Depends(get_db)):
    #the current user
    me = db.query(models.User).filter(models.User.firebase_token == request.firebase_token).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")
    #the user you liked
    liked_user = db.query(models.User).filter(models.User.id == request.liked_id).first()
    if not liked_user: 
        raise HTTPException(status_code=404, detail="Liked User not found") 
    
    new_like = models.Likes(
        liker_id = me.id, #the current user
        liked_id = liked_user.id, #the liked user
        is_super_like = request.is_super_like,
    )
    
    db.add(new_like)
    
    #if the liked user liked the current user
    reverse_like = db.query(models.Likes).filter(  
        models.Likes.liker_id == liked_user.id,
        models.Likes.liked_id == me.id,
    ).first()

    if reverse_like: 
        new_match = models.Matches(  
           user_a_id = me.id,
           user_b_id = liked_user.id,
        )
        db.add(new_match)
    db.commit()

    return {"is_match": bool(reverse_like)} #if reverse_like returns true then it is a match

#get matches to load chats
@app.get("/matches")
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
                "image_url": "https://picsum.photos/200", #other_users.profile_picture later
                #"last_message": for later
            })
        else: 
            raise HTTPException(status_code=404, detail="Other User not found")

        
        return results