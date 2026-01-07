
from sqlalchemy import Column, Integer, String, Boolean, TIMESTAMP, text, ForeignKey
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

    settings = relationship("Settings", back_populates="user", uselist=False, cascade="all, delete")
    photos = relationship("Photos", back_populates="user")

class Likes(Base):
    __tablename__ = "likes"

    id = Column(Integer, primary_key = True, nullable = False)
    liker_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable = False)
    liked_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable = False)
    is_super_like = Column(Boolean, nullable = True, server_default = 'false')
    created_at = Column(TIMESTAMP(timezone=True), nullable = False, server_default = text('now()'))

class Matches(Base):
    __tablename__ = "matches"

    id = Column(Integer, primary_key = True, nullable = False)
    user_a_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable = False)
    user_b_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable = False)
    created_at = Column(TIMESTAMP(timezone=True), nullable = False, server_default = text('now()'))

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
    is_notifications_on = Column(Boolean, nullable = False, default=False)
    language = Column(String, nullable = False, default="en")

    user = relationship("User", back_populates="settings")
