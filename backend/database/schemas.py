from pydantic import BaseModel
from datetime import datetime
    
class UserBase(BaseModel):
    username: str
    full_name: str
    firebase_token: str
    profile_picture: str | None = None
    bio: str | None = None
    age: int | None = None 

class UserCreate(UserBase):
    pass

class User(UserBase):
    id: int
    created_at: datetime

class Config:
    from_attributes = True

class UserImageUpdate(BaseModel):
    profile_picture: str

class Likes(BaseModel):
    id: int
    liker_id: int
    liked_id: int
    is_super_like: bool

class Matches(BaseModel):
    id: int
    user_a_id: int
    user_b_id: int

class Messages(BaseModel):
    id: int
    sender: int
    match_id: int

class Photos(BaseModel):
    id: int
    user_id: int
    photo_url: str
    display_order: int