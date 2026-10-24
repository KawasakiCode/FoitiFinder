
from sqlalchemy import Column, Integer, String, Boolean, TIMESTAMP, Date, text, ForeignKey, Float, Index
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import relationship
from .database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key = True, nullable = False)
    #ONE name field, not a username plus a real name. A dating profile is not
    #an account handle - nobody searches for anyone here and nothing is @-
    #mentioned, so a second identifier was a field to fill in for no purpose.
    #Users put whatever they want people to call them.
    name = Column(String, nullable = False, index = True)
    #The Firebase UID: a permanent, public IDENTIFIER, not a credential. Named
    #firebase_token until it was renamed, which invited the mix-up with the
    #four things Firebase actually calls tokens (ID, refresh, custom, FCM).
    #This is the only link between a Google identity and a row here, which is
    #why every endpoint's first query filters on it.
    firebase_uid = Column(String, unique = True, nullable = False)
    bio = Column(String, nullable = True)
    #Date, not an age integer: an age is only correct on the day it is
    #written. Age is derived from this wherever it is shown - see ages.py.
    #Date rather than DateTime deliberately: a birthday has no time of day, and
    #a timestamp would shift across timezones and move someone's birthday by a
    #day depending on where the server is.
    birthday = Column(Date, nullable = True)
    #centimetres. An integer because it is a filter in date preferences and a
    #range query on a float is a nuisance for no gain in precision.
    height_cm = Column(Integer, nullable = True)
    created_at = Column(TIMESTAMP(timezone=True), nullable = False, server_default = text('now()'))
    gender = Column(String, nullable = True)
    min_age_range = Column(Integer, nullable = True)
    max_age_range = Column(Integer, nullable = True)
    #height preference in centimetres, same shape as the age range: null means
    #no bound on that side
    min_height_preference = Column(Integer, nullable = True)
    max_height_preference = Column(Integer, nullable = True)
    #the GENDER PREFERENCE: a comma separated string of 'Men'/'Women'/
    #'Everyone'.
    preferred_gender = Column(String, nullable = True)
    has_finished_set_up = Column(Boolean, nullable = False)
    has_photos = Column(Boolean, nullable = False)

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
    #ONE ANSWER EACH, not arrays. They were text[] while the app let people
    #tick several, which allowed Christian + Atheist and Liberal +
    #Conservative at the same time.
    religion = Column(String, nullable = True)
    political_view = Column(String, nullable = True)
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
    languages_spoken = Column(ARRAY(String), nullable = False, server_default = text("'{}'"))

    #=====================================================================
    #DATE PREFERENCES: what the user wants the OTHER person to have
    #
    #Same answer strings as the profile columns above (alcohol, smoking...),
    #but arrays: someone can be fine with a partner who drinks "Never" OR
    #"Sometimes". Empty array = no preference, never a filter that hides
    #everybody. Keys match the kPref* choices in constants/profile_options.dart.
    #=====================================================================
    preferred_alcohol = Column(ARRAY(String), nullable = False, server_default = text("'{}'"))
    preferred_smoking = Column(ARRAY(String), nullable = False, server_default = text("'{}'"))
    preferred_dating_intention = Column(ARRAY(String), nullable = False, server_default = text("'{}'"))
    preferred_kids = Column(ARRAY(String), nullable = False, server_default = text("'{}'"))
    #Languages the other person must speak - at least ONE has to match, not all
    #of them. Empty = no language filter, which is the honest default: a new
    #account has not said anything about who it wants to see.
    preferred_languages = Column(ARRAY(String), nullable = False, server_default = text("'{}'"))
    #false = only show people from my own prefecture (users.city)
    show_outside_residence = Column(Boolean, nullable = False, server_default = text('true'))

    settings = relationship("Settings", back_populates="user", uselist=False, cascade="all, delete", passive_deletes=True)
    photos = relationship("Photos", back_populates="user", cascade="all, delete", passive_deletes=True)

    #THE PROFILE PICTURE IS photo_urls[0], the photo with display_order 0.
    #There used to be a profile_picture column as well, written by a separate
    #upload, and nothing kept the two in step - likes showed one face and
    #matches another. Now there is one fact in one place.
    @property
    def photo_urls(self):
        return [p.photo_url for p in sorted(self.photos, key=lambda p: p.display_order)]

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

    #A MATCH IS NOT AN EXCHANGE YET. Mutual likes create the row; the Instagram
    #handles are only swapped once BOTH sides have said yes again, on the match
    #page. A swipe can be weeks stale, so the confirm is where someone decides
    #with current information - and it is the only "changed my mind" exit,
    #because a handle cannot be un-revealed afterwards.
    #
    #NULL means "has not answered". There is no stored "declined": a decline
    #deletes the row (see POST /matches/{id}/decline), since nothing about a
    #refused match is worth keeping and the likes page must not resurface it.
    #
    #Timestamps rather than booleans: whoever confirmed first is waiting, and
    #that is what decides who gets told when the other one answers.
    a_confirmed_at = Column(TIMESTAMP(timezone=True), nullable = True)
    b_confirmed_at = Column(TIMESTAMP(timezone=True), nullable = True)

    #WITHDRAWN BY ONE SIDE, AND GONE FOR BOTH.
    #
    #A revealed match cannot be declined - a handle that has been read cannot
    #be taken back - but it still sits in the other person's list, handing
    #your Instagram back to them every time they open it. That is the one part
    #of the exchange the app is still responsible for, so either side can end
    #it, and the other is told nothing.
    #
    #HIDDEN, NOT DELETED. Deleting would destroy the only record that two
    #people connected: who confirmed, when, and in which order. The app simply
    #stops returning the row (see get_matches); everything stays for anyone
    #reading the database directly. It is also why this is a timestamp and not
    #a flag - "when did they withdraw" is the question anyone asks afterwards.
    #
    #ONE PAIR, NOT ONE PER SIDE: this is severance, not an archive box. There
    #is no state where one of you can still see it.
    hidden_at = Column(TIMESTAMP(timezone=True), nullable = True)
    hidden_by_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable = True)

class Notifications(Base):
    """What the bell in the app bar shows: things that happened TO this user.

    A TABLE RATHER THAN A QUERY, and that is the whole reason it exists. Most
    of this is derivable from `matches` - a row with one side confirmed is "your
    turn", both sides confirmed is "you are connected". A DECLINE IS NOT: it
    deletes the match, so the only record that it ever happened would be a push
    notification, which may never arrive and can be swiped away. Stored, the
    app can be told the truth on next launch whatever FCM did.

    This is also the "is anything waiting for me?" check: push is a nudge, and
    this is the delivery.

    LIKES ARE NOT IN HERE. They have their own page and their own badge; a bell
    that fills up with "someone liked you" is a bell nobody reads. Only things
    that need an answer, or carry the answer to one.
    """
    __tablename__ = "notifications"

    id = Column(Integer, primary_key = True, nullable = False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable = False, index = True)

    #'match' (someone is waiting on your answer), 'match_revealed' (you both
    #said yes), 'match_declined' (the person you were waiting on said no).
    #The same strings the FCM payload uses, so one vocabulary covers both.
    kind = Column(String, nullable = False)

    #What to open. SET NULL, NOT CASCADE: a declined match is deleted and this
    #row has to outlive it - there is simply nothing left to open, which is
    #exactly what a null says.
    match_id = Column(Integer, ForeignKey("matches.id", ondelete="SET NULL"), nullable = True)
    #Who it is about, for the name and face in the list. SET NULL again: a
    #deleted account leaves the notification readable rather than vanishing.
    other_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable = True)

    created_at = Column(TIMESTAMP(timezone=True), nullable = False, server_default = text('now()'))
    #NULL until opened. A timestamp rather than a flag, because "when did they
    #see this" is the thing anyone ever asks afterwards.
    read_at = Column(TIMESTAMP(timezone=True), nullable = True)


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

    #THE TWO DIRECTIONS THIS TABLE IS READ IN, and until now neither had an
    #index - only `id`, twice, which no query filters on.
    #
    #  (user_id, target_id)  "what have I done" - the feed's exclusion list,
    #                        and the outgoing side of the likes query
    #  (target_id, action)   "who liked ME" - the likes page, and the feed
    #                        exclusion that keeps those people out of the deck
    #
    #Both are read on every feed request, which is the single hottest query in
    #the app, and both grow with every swipe anyone ever makes.
    __table_args__ = (
        Index("ix_user_swipes_user_target", "user_id", "target_id"),
        Index("ix_user_swipes_target_action", "target_id", "action"),
    )
    