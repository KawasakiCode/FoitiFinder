from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime

#main user schema 
class UserBase(BaseModel):
    username: str
    full_name: str
    firebase_token: str
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


#this adds the fields produced by the database to be returned to the phone
class User(UserBase):
    id: int
    created_at: datetime

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

class Likes(BaseModel):
    liker_id: int
    liked_id: int
    is_super_like: bool

class Matches(BaseModel):
    user_a_id: int
    user_b_id: int

class Messages(BaseModel):
    sender: int
    match_id: int
    content: str

class Photos(BaseModel):
    user_id: int
    photo_url: str
    display_order: int

#user settings schema to add settings to the database
class Settings(BaseModel):
    id: int
    user_id: int
    is_dark_mode: bool
    is_notifications_on: bool
    language: str

    class Config:
        from_attributes = True

#schema to change one or more settings in a single patch endpoint
class SettingsUpdate(BaseModel):
    is_dark_mode: bool | None = None
    is_notifications_on: bool | None = None
    language: str | None = None