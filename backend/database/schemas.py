from tokenize import String
from pydantic import BaseModel
from datetime import datetime
    
class User(BaseModel):
    id: int
    username: String
    full_name: String
    firebase_token: String
    profile_picture: String
    created_at: datetime

class Likes(BaseModel):
    id: int
    liker_id: int
    liked_id: int
    is_super_like: bool
    created_at: datetime

class Matches(BaseModel):
    id: int
    user_a_id: int
    user_b_id: int
    created_at: datetime

class Messages(BaseModel):
    id: int
    sender: int
    match_id: int
    created_at: datetime

class Photos(BaseModel):
    id: int
    user_id: int
    photo_url: String
    display_order: int
    created_at: datetime