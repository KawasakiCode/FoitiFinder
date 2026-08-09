
from sqlalchemy import Column, Integer, String, Boolean, TIMESTAMP, text, ForeignKey, Float
from sqlalchemy.orm import relationship
from .database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key = True, nullable = False)
    username = Column(String, nullable = False, index = True)
    full_name = Column(String, nullable = False)
    firebase_token = Column(String, unique = True, nullable = False)
    profile_picture = Column(String, unique = True, nullable = True)
    bio = Column(String, nullable = True)
    age = Column(Integer, nullable = True)
    created_at = Column(TIMESTAMP(timezone=True), nullable = False, server_default = text('now()'))
    gender = Column(String, nullable = True)
    min_age_range = Column(Integer, nullable = True)
    max_age_range = Column(Integer, nullable = True)
    show_out_of_range = Column(Boolean, nullable = True)
    is_balanced = Column(Boolean, nullable = True)
    interests = Column(String, nullable = True)
    has_finished_set_up = Column(Boolean, nullable = False)
    has_photos = Column(Boolean, nullable = False)
    score = Column(Float, nullable = True)

    settings = relationship("Settings", back_populates="user", uselist=False, cascade="all, delete")
    photos = relationship("Photos", back_populates="user")

#the seen columns help to know when a user saw a match to remove it from the 
#new matches row inside the message page of the app
class Matches(Base):
    __tablename__ = "matches"

    id = Column(Integer, primary_key = True, nullable = False)
    user_a_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable = False)
    user_b_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable = False)
    created_at = Column(TIMESTAMP(timezone=True), nullable = False, server_default = text('now()'))
    user_a_saw = Column(Boolean, nullable=False) #if user a saw the match 
    user_b_saw = Column(Boolean, nullable=False) #if user b saw the match

class Messages(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key = True, nullable = False)
    sender = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable = False)
    #no need for receiver id since we ask between the 2 that matched who send the message, so the other is the receiver
    match_id = Column(Integer, ForeignKey("matches.id", ondelete="CASCADE"), nullable = False)
    content = Column(String, nullable = False)
    created_at = Column(TIMESTAMP(timezone=True), nullable = False, server_default = text('now()'))
    
class Photos(Base):
    __tablename__ = "photos"

    id = Column(Integer, primary_key = True, nullable = False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable = False)
    photo_url = Column(String, unique = True, nullable = False)
    display_order = Column(Integer, nullable = False)
    created_at = Column(TIMESTAMP(timezone=True), nullable = False, server_default = text('now()'))
    
    user = relationship("User", back_populates="photos")

class Settings(Base):
    __tablename__ = "settings"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), unique = True, nullable = False)
    is_dark_mode = Column(Boolean, nullable = False, default=False)
    is_like_notifications_on = Column(Boolean, nullable = False, default=False)
    is_message_notifications_on = Column(Boolean, nullable = False, default=False)
    language = Column(String, nullable = False, default="en")

    user = relationship("User", back_populates="settings")

class UserSwipes(Base):
    __tablename__ = "user_swipes"

    id = Column(Integer, primary_key = True, index = True)
    user_id = Column(Integer, ForeignKey("users.id"))
    target_id = Column(Integer, ForeignKey("users.id"))
    action = Column(String) #like, pass or super like
    timestamp = Column(TIMESTAMP(timezone = True), nullable = False, server_default = text('now()'))
    