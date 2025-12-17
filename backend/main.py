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
        gender=user.gender,
        min_age_range=user.min_age_range,
        max_age_range=user.max_age_range,
        show_out_of_range=user.show_out_of_range,
        is_balanced=user.is_balanced,
        interests=user.interests,
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

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
