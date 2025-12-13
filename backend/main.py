from fastapi import FastAPI, Depends, HTTPException
from dotenv import load_dotenv
from database import models
from database.database import engine, get_db
from database import schemas
from sqlalchemy.orm import Session

models.Base.metadata.create_all(bind=engine)

load_dotenv()

app = FastAPI()

#create new user
@app.post("/users/", response_model=schemas.User)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    #chech if user with the same firebase.uid already is registered and return and exception if yes
    db_user = db.query(models.User).filter(models.User.firebase_token == user.firebase_token).first()
    if db_user: 
        raise HTTPException(status_code = 400, detail="User already exists")
    
    new_user = models.User(  
        username = user.username,
        full_name=user.full_name,
        firebase_token=user.firebase_token,
        profile_picture=user.profile_picture,
        bio=user.bio,
        age=user.age,
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return new_user

#update users profile picture
@app.patch("/users/{firebase_token}/image")
def update_profile_image(firebase_token: str, profile_picture: schemas.UserImageUpdate, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.firebase_token == firebase_token).first()

    if not db_user: 
        raise HTTPException(status_code = 404, detail = "User not found")
    
    db_user.profile_picture = profile_picture.profile_picture
    db.commit()
    db.refresh(db_user)

    return {"message":"Image updated successfully", "new_url": db_user.profile_picture}

#get users data
@app.get("/users/{firebase_token}")
def get_user_data(firebase_token: str, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.firebase_token == firebase_token).first()

    if not db_user: 
        raise HTTPException(status_code=404, details = "User not found")
    
    return db_user

