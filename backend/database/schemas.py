from pydantic import BaseModel, EmailStr, conint
from datetime import datetime
    
class User(BaseModel):
    id: int
    