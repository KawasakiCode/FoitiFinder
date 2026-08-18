from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime

#main user schema
#NOTE: no firebase_token here. The uid is NOT accepted from the client — it is
#taken from the verified ID token server side (see current_uid in main.py), so
#a caller can only ever create/modify their own row. It is returned in the User
#response below, but never read from a request body.
class UserBase(BaseModel):
    username: str
    full_name: str
    profile_picture: str | None = None
    bio: str | None = None
    age: int | None = None 
    gender: str | None = None
    min_age_range: int | None = None
    max_age_range: int | None = None
    show_out_of_range: bool | None = None
    is_balanced: bool | None = None
    interests: str | None = None
    has_finished_set_up: bool | None = False
    has_photos: bool | None = False
    score: float | None = 0

#for patch endpoints to update a single attribute without needing the others too
class UserUpdate(BaseModel):
    username: str | None = None
    full_name: str | None = None
    profile_picture: str | None = None
    bio: str | None = None
    age: int | None = None
    gender: str | None = None
    min_age_range: int | None = None
    max_age_range: int | None = None
    show_out_of_range: bool | None = None
    is_balanced: bool | None = None
    interests: str | None = None
    has_finished_set_up: bool | None = False
    has_photos: bool | None = False
    score: float | None = 0


#this adds the fields produced by the database to be returned to the phone
class User(UserBase):
    id: int
    created_at: datetime
    #server-derived, response only (the client reads it back as the user's uid)
    firebase_token: str

    #allows pydantic to read sqlalchemy objects instead of only dictionaries
    class Config:
        from_attributes = True

#called when creating users to add secret fields like passwords
class UserCreate(UserBase):
    pass

#class when getting user data for the deck of cards
class UserCardResponse(BaseModel):
    id: int
    username: str
    age: Optional[int] = None
    bio: Optional[str] = None
    photos: List[str] = []

    class Config:
        orm_mode = True

class Photos(BaseModel):
    user_id: int
    photo_url: str
    display_order: int

#user settings schema to add settings to the database
class Settings(BaseModel):
    id: int
    user_id: int
    is_dark_mode: bool
    is_like_notifications_on: bool
    language: str

    class Config:
        from_attributes = True

#schema to change one or more settings in a single patch endpoint
class SettingsUpdate(BaseModel):
    is_dark_mode: bool | None = None
    is_like_notifications_on: bool | None = None
    language: str | None = None

#schema for swipe records
class UserSwipes(BaseModel):
    user_id: int
    target_id: int
    action: str