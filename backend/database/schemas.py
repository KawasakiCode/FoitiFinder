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
    show_out_of_age_range: bool | None = None
    isBalanced: bool | None = None

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
    show_out_of_age_range: bool | None = None
    isBalanced: bool | None = None

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

class Photos(BaseModel):
    user_id: int
    photo_url: str
    display_order: int

class Settings(BaseModel):
    id: int
    user_id: int
    is_dark_mode: bool
    is_notifications_on: bool
    language: str

    class Config:
        from_attributes = True

class SettingsUpdate(BaseModel):
    is_dark_mode: bool | None = None
    is_notifications_on: bool | None = None
    language: str | None = None