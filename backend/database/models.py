
from sqlalchemy import Column, Integer, String, Boolean, TIMESTAMP, text, ForeignKey, Float, Index
from sqlalchemy.dialects.postgresql import ARRAY
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
    #the GENDER PREFERENCE: a comma separated string of 'Men'/'Women'/
    #'Everyone'. Was called `interests`, which read as profile interests and
    #invited exactly the mix-up the warning below describes.
    preferred_gender = Column(String, nullable = True)
    has_finished_set_up = Column(Boolean, nullable = False)
    has_photos = Column(Boolean, nullable = False)
    score = Column(Float, nullable = True)

    #=====================================================================
    #PROFILE: single-answer categories
    #
    #Every column below is named after the `key` in the app's
    #constants/profile_options.dart, so a PATCH body is a straight map of
    #key -> value with no translation layer in between.
    #
    #NULL means "not answered yet", which is deliberately different from an
    #empty string - the app's dialogs normalise a cleared answer to NULL.
    #=====================================================================
    alcohol = Column(String, nullable = True)
    smoking = Column(String, nullable = True)
    dating_intention = Column(String, nullable = True)
    kids = Column(String, nullable = True)
    sexual_orientation = Column(String, nullable = True)
    pronouns = Column(String, nullable = True)

    #Background. `university` is derived from the user's email domain by the
    #app, but stored here because the backend never sees the email - and
    #another user's profile has to be able to display it.
    university = Column(String, nullable = True)
    major = Column(String, nullable = True)
    is_currently_studying = Column(Boolean, nullable = True)
    job = Column(String, nullable = True)
    volunteering = Column(String, nullable = True)
    occupation_other = Column(String, nullable = True)
    city = Column(String, nullable = True)

    #handed over when two people match; not shown before that
    instagram_handle = Column(String, nullable = True)

    #=====================================================================
    #PROFILE: multi-answer categories
    #
    #NOT NULL DEFAULT '{}' on purpose. cardinality(NULL) is NULL rather than
    #0, so a nullable array silently poisons every scoring expression in the
    #matching query. An empty array is the honest value for "picked nothing".
    #
    #The section a tag came from (Activities, Music, Sports...) is NOT stored:
    #it is recoverable from constants/interest_catalogue.dart, and duplicating
    #it here would turn "move a tag to another section" into a data migration.
    #=====================================================================
    #Profile tags. Note these are NOT preferred_gender above - that one drives
    #discovery filtering, these describe the user.
    interest_tags = Column(ARRAY(String), nullable = False, server_default = text("'{}'"))
    trait_tags = Column(ARRAY(String), nullable = False, server_default = text("'{}'"))
    religion = Column(ARRAY(String), nullable = False, server_default = text("'{}'"))
    political_view = Column(ARRAY(String), nullable = False, server_default = text("'{}'"))
    languages_spoken = Column(ARRAY(String), nullable = False, server_default = text("'{}'"))

    settings = relationship("Settings", back_populates="user", uselist=False, cascade="all, delete", passive_deletes=True)
    photos = relationship("Photos", back_populates="user", cascade="all, delete", passive_deletes=True)
    qna = relationship("UserQnA", back_populates="user", cascade="all, delete", passive_deletes=True)

    #GIN indexes back the overlap operators (&&) and the shared-tag counting
    #the feed batch uses to score candidates. Only the two tag arrays get one:
    #religion and political_view are display-only until something filters on
    #them, and an unused index is just write cost.
    __table_args__ = (
        Index("ix_users_interest_tags", "interest_tags", postgresql_using="gin"),
        Index("ix_users_trait_tags", "trait_tags", postgresql_using="gin"),
    )


#a match row exists only while the pairing is live; there are no seen flags
#because a match is acted on (instagram handles exchanged) and then removed
class Matches(Base):
    __tablename__ = "matches"

    id = Column(Integer, primary_key = True, nullable = False)
    user_a_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable = False)
    user_b_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable = False)
    created_at = Column(TIMESTAMP(timezone=True), nullable = False, server_default = text('now()'))

class Photos(Base):
    __tablename__ = "photos"

    id = Column(Integer, primary_key = True, nullable = False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable = False)
    photo_url = Column(String, unique = True, nullable = False)
    display_order = Column(Integer, nullable = False)
    #the caption the owner attached to this photo. NULL = no story, which is
    #different from "" only in intent, so the endpoint normalises "" to NULL.
    story = Column(String, nullable = True)
    created_at = Column(TIMESTAMP(timezone=True), nullable = False, server_default = text('now()'))
    
    user = relationship("User", back_populates="photos")

#The user's answers to the prompt catalogue.
#
#A table rather than an array or a jsonb blob: each entry is a PAIR (which
#prompt, what answer) plus an order, one user has any number of them, and a
#child table gives cascade delete and per-answer moderation queries for free.
class UserQnA(Base):
    __tablename__ = "user_qna"

    id = Column(Integer, primary_key = True, nullable = False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable = False, index = True)
    #STABLE KEY, never the question text. The key is what survives rewording
    #the prompt or translating it to Greek - same reasoning as the canonical
    #strings behind l10n/catalogue_labels.dart.
    prompt_key = Column(String, nullable = False)
    answer = Column(String, nullable = False)
    display_order = Column(Integer, nullable = False, server_default = text("0"))

    user = relationship("User", back_populates="qna")


class Settings(Base):
    __tablename__ = "settings"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), unique = True, nullable = False)
    is_dark_mode = Column(Boolean, nullable = False, default=False)
    is_like_notifications_on = Column(Boolean, nullable = False, default=False)
    language = Column(String, nullable = False, default="en")

    user = relationship("User", back_populates="settings")

class UserSwipes(Base):
    __tablename__ = "user_swipes"

    id = Column(Integer, primary_key = True, index = True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    target_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    action = Column(String) #like, pass or super like
    timestamp = Column(TIMESTAMP(timezone = True), nullable = False, server_default = text('now()'))
    