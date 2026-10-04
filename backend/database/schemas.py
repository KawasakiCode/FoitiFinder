from typing import List, Optional
from pydantic import BaseModel
from datetime import date, datetime

#main user schema
#NOTE: no firebase_uid here. The uid is NOT accepted from the client — it is
#taken from the verified ID token server side (see current_uid in main.py), so
#a caller can only ever create/modify their own row. It is returned in the User
#response below, but never read from a request body.
class UserBase(BaseModel):
    name: str
    bio: str | None = None
    birthday: date | None = None
    height_cm: int | None = None
    gender: str | None = None
    min_age_range: int | None = None
    max_age_range: int | None = None
    min_height_preference: int | None = None
    max_height_preference: int | None = None
    preferred_gender: str | None = None
    has_finished_set_up: bool | None = False
    has_photos: bool | None = False

    #---- profile: single-answer categories ----
    #named after the `key` in the app's constants/profile_options.dart
    alcohol: str | None = None
    smoking: str | None = None
    dating_intention: str | None = None
    kids: str | None = None
    sexual_orientation: str | None = None
    pronouns: str | None = None
    religion: str | None = None
    political_view: str | None = None
    university: str | None = None
    major: str | None = None
    is_currently_studying: bool | None = None
    job: str | None = None
    volunteering: str | None = None
    city: str | None = None
    instagram_handle: str | None = None

    #---- profile: multi-answer categories ----
    #default [] not None, matching the NOT NULL DEFAULT '{}' columns
    interest_tags: List[str] = []
    trait_tags: List[str] = []
    languages_spoken: List[str] = []

    #---- date preferences ----
    preferred_alcohol: List[str] = []
    preferred_smoking: List[str] = []
    preferred_dating_intention: List[str] = []
    preferred_kids: List[str] = []
    preferred_languages: List[str] = []
    show_outside_residence: bool = True

#for patch endpoints to update a single attribute without needing the others too
class UserUpdate(BaseModel):
    name: str | None = None
    bio: str | None = None
    birthday: date | None = None
    height_cm: int | None = None
    gender: str | None = None
    min_age_range: int | None = None
    max_age_range: int | None = None
    min_height_preference: int | None = None
    max_height_preference: int | None = None
    preferred_gender: str | None = None
    has_finished_set_up: bool | None = False
    has_photos: bool | None = False

    #---- profile: single-answer categories ----
    #named after the `key` in the app's constants/profile_options.dart
    alcohol: str | None = None
    smoking: str | None = None
    dating_intention: str | None = None
    kids: str | None = None
    sexual_orientation: str | None = None
    pronouns: str | None = None
    religion: str | None = None
    political_view: str | None = None
    university: str | None = None
    major: str | None = None
    is_currently_studying: bool | None = None
    job: str | None = None
    volunteering: str | None = None
    city: str | None = None
    instagram_handle: str | None = None

    #---- profile: multi-answer categories ----
    #None, NOT [] - update_user uses model_dump(exclude_unset=True), so a field
    #the client never sent must stay absent. Defaulting to [] here would be
    #indistinguishable from the user deliberately clearing every tag.
    interest_tags: List[str] | None = None
    trait_tags: List[str] | None = None
    languages_spoken: List[str] | None = None

    #---- date preferences ----
    preferred_alcohol: List[str] | None = None
    preferred_smoking: List[str] | None = None
    preferred_dating_intention: List[str] | None = None
    preferred_kids: List[str] | None = None
    preferred_languages: List[str] | None = None
    show_outside_residence: bool | None = None


#this adds the fields produced by the database to be returned to the phone
class User(UserBase):
    id: int
    created_at: datetime
    #server-derived, response only (the client reads it back as the user's uid)
    firebase_uid: str
    #the user's photos in display order; [0] is the profile picture. Read
    #only - photos are changed through /photos/sync, never through here.
    photo_urls: List[str] = []

    #allows pydantic to read sqlalchemy objects instead of only dictionaries
    class Config:
        from_attributes = True

#called when creating users to add secret fields like passwords
class UserCreate(UserBase):
    pass

#class when getting user data for the deck of cards
class UserCardResponse(BaseModel):
    id: int
    name: str
    age: Optional[int] = None
    bio: Optional[str] = None
    photos: List[str] = []

    class Config:
        orm_mode = True

class Photos(BaseModel):
    user_id: int
    photo_url: str
    display_order: int
    story: Optional[str] = None

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