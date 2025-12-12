from fastapi import FastAPI, Depends, HTTPException
from dotenv import load_dotenv
from database import models
from database.database import engine, get_db
from database import schemas
from sqlalchemy import Session

models.Base.metadata.create_all(bind=engine)

load_dotenv()

app = FastAPI()

@app.post("/users/", response_model=schemas.UserCreate)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.firebase_uid == user.firebase_uid).first()
    if db_user: 
        raise HTTPException(status_code = 400, detail="User already exists")
    
    new_user = models.User(  
        username = user.username,
        email=user.email,
        firebase_token=user.firebase.uid,
        profile_picture=user.image_url,
        bio=user.bio,
        age=user.age,
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return new_user
