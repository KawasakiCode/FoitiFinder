
from sqlalchemy import Column, Integer, String, Boolean, TIMESTAMP,text, ForeignKey
from .database import Base
# from sqlalchemy.orm import relationship

class User(Base):
    __tablename__ = "users"


    

    
