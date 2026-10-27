
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

    #REMOVED FROM ONE LIST, AND ONLY THAT ONE.
    #
    #A revealed match cannot be declined - a handle that has been read cannot
    #be taken back - so without this it is the one state in the app with no
    #exit at all, permanent for as long as the account exists.
    #
    #ONE PER SIDE, which is a reversal of what this was. It started as a
    #single hidden_at/hidden_by_user_id pair meaning "withdrawn by one, gone
    #for both", on the grounds that a row in their list keeps handing them
    #your Instagram. That reads stronger than it is: the handle has already
    #been read, saved, or followed, so hiding it from them takes nothing back.
    #
    #What it WOULD do is make the removal visible to them - and if reporting
    #somebody also removed the match, a match disappearing would tell the
    #person who has your Instagram handle that you reported them. The one
    #action meant to get someone away from a harasser would announce itself
    #to the harasser, off-platform, where this app can do nothing. So each
    #side only ever hides its own copy, and neither can tell.
    #
    #AND IT MAKES THE WRITE CONFLICT-FREE. With one shared column, the second
    #person to remove a match had to read whether the first already had, and
    #two removals landing together would leave the match standing for whoever
    #lost the race. Each side writing only its own column cannot conflict.
    #
    #HIDDEN, NOT DELETED. Deleting would destroy the only record that two
    #people connected: who confirmed, when, and in which order. The app simply
    #stops returning the row (see get_matches); everything stays for anyone
    #reading the database directly. Timestamps rather than flags for the same
    #reason as the pair above - "when did they walk away" is the question
    #anyone asks afterwards, and per side it answers it for both of them.
    hidden_by_a_at = Column(TIMESTAMP(timezone=True), nullable = True)
    hidden_by_b_at = Column(TIMESTAMP(timezone=True), nullable = True)

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
    is_match_notifications_on = Column(Boolean, nullable = False, default=False)
    language = Column(String, nullable = False, default="en")

    user = relationship("User", back_populates="settings")

class UserSwipes(Base):
    __tablename__ = "user_swipes"

    id = Column(Integer, primary_key = True, index = True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    target_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    #WHAT THE VIEWER DECIDED, validated as a Literal in api_models:
    #
    #  like, super_like   wants them; either can complete a match
    #  pass               flicked past in the deck
    #  not_interested     THE SAME OUTCOME AS pass AND A DIFFERENT FACT. A
    #                     pass is a thumb moving at speed over a card; this
    #                     is somebody who opened the whole profile, opened a
    #                     menu inside it and chose this - a considered no, and
    #                     the strongest negative signal the app can collect.
    #                     Kept apart from pass because the two cannot be told
    #                     apart afterwards: there is no way to look at a pile
    #                     of passes later and recover which were deliberate,
    #                     so ranking either has this from the start or never.
    #  reported           also a no, and final - see record_swipe
    #
    #EVERY QUERY THAT BRANCHES ON THIS ASKS WHICH ACTIONS COUNT AS INTEREST
    #(like, super_like) rather than which ones do not, so a new negative value
    #needs no changes anywhere: the deck excludes on target_id whatever the
    #action was, and nothing here can build a match.
    action = Column(String)
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
    

class Reports(Base):
    """Somebody telling us about somebody else.

    A TABLE, NOT A PUSH TO AN INBOX, because a report has to survive being
    read. The reporter is anonymous TO THE REPORTED USER, which is not the
    same as anonymous: reporter_id is kept, and has to be, or the same person
    cannot be seen reporting fifteen profiles in an afternoon and nothing can
    be weighed against the account's other history.

    WHY THE SWIPE IS NOT ENOUGH. user_swipes already takes 'reported' as an
    action, which is what removes the person from the deck for good - but an
    action with no reason attached says only that somebody objected, and every
    report here needs a reviewer to know WHAT to look at. The swipe is the
    consequence; this is the content.

    NOTHING IS DELETED WHEN A USER IS. Both sides are ON DELETE SET NULL
    rather than CASCADE, which is the opposite of the choice everywhere else
    in this schema: a report whose subject deleted their account is precisely
    the record worth keeping, since leaving is what somebody does after being
    reported. The codes and the text stay readable with no user attached.
    """
    __tablename__ = "reports"

    id = Column(Integer, primary_key = True, nullable = False)
    reporter_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable = True)
    reported_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable = True)

    #CODES, validated against report_reasons.REASONS before they are written.
    #Two columns rather than one joined string: "how many reports mention a
    #minor" is the question that gets asked, and it should not need LIKE.
    category = Column(String, nullable = False)
    subcategory = Column(String, nullable = False)

    #WHAT THE REPORTER TYPED, and often the only thing that makes a report
    #actionable - the codes say which drawer to look in, this says what
    #happened. Nullable because insisting on it would turn "I do not want to
    #write this out" into "I will not report it".
    details = Column(String, nullable = True)

    created_at = Column(TIMESTAMP(timezone=True), nullable = False, server_default = text('now()'))

    #WHEN SOMEBODY LOOKED, not whether they agreed. There is no outcome column
    #on purpose: what was done about a report is a decision about an account
    #and belongs wherever that is recorded, while this only answers "has this
    #been seen" - which is the question a review queue needs and the one a
    #boolean would answer worse, since "seen when" is what tells you the queue
    #is keeping up.
    reviewed_at = Column(TIMESTAMP(timezone=True), nullable = True)

    #THE TWO QUESTIONS A REVIEWER ASKS, and neither is answered by a scan.
    #
    #  reviewed_at IS NULL   "what is waiting for me" - the queue itself, and
    #                        PARTIAL, because the rows that have been dealt
    #                        with are the ones that accumulate forever and the
    #                        queue never wants to see them again
    #  reported_user_id      "what else has been said about this account" -
    #                        the first thing worth knowing about any single
    #                        report, since one complaint and the fifth
    #                        complaint are not the same report
    __table_args__ = (
        Index("ix_reports_pending", "created_at",
              postgresql_where=text("reviewed_at IS NULL")),
        Index("ix_reports_reported_user", "reported_user_id"),
    )
