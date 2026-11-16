"""Who is allowed to look at whom.

ITS OWN MODULE, FOR THE REASON auth.py IS. Authentication asks who is calling
and the answer is one verified token. This asks what they may see, and the
answer is spread across the deck's filters, the swipe table, the match table
and the report table. Spread out, it is the kind of rule each endpoint ends up
restating slightly differently - and the way /users/{id}/profile and
/single/user/{id} came to have no rule at all was precisely that: both read a
user by id and returned it, and all the privacy work went into WHICH FIELDS
came back rather than WHO WAS ASKING.

WHAT WAS WRONG. User ids are sequential integers. Any account with a verified
university address could walk 1..N and collect every profile in the database -
name, age, city, university, bio, photos, and with them religion, political
view and sexual orientation, which GDPR Art. 9 calls special category data.
Nothing in either endpoint looked at the relationship between the two people.

THE RULE. You may read a profile if the deck could have offered it to you, or
you have already decided about that person, or you are matched with them - and
never if either of you has reported the other.

WHY THE DECK'S OWN FILTERS AND NOT A SECOND SET. feed.py decides who you may
see by age, gender, height and language, in both directions, and those filters
are most of what this app promises about who sees whom. A profile endpoint
applying a looser rule would make all of it a formality, since anything the
deck withheld could be read by asking for it by number. So the eligibility half
below is literally the list of SQL expressions the deck builds - the same list,
from here, used by both - rather than a second copy that would start identical
and drift.

AND WHY ALREADY-SWIPED IS NOT IN IT. The deck excludes people you have decided
about because it has nothing left to offer you, which is not the same as you
having lost the right to look. Passing on somebody and then opening their card
from a match later is ordinary. So the exclusion stays in the deck, where it
belongs, and the rule here adds those people back deliberately.
"""

from sqlalchemy import and_, any_, func, literal, or_
from sqlalchemy.orm import Session

from ages import age_from_birthday, years_ago
from database import models
from preferences.preferences import (gender_to_preference_token,
                                     preference_to_genders)

#the swipe action a report leaves behind. See routers/reports.py: a report
#always ends with a row in this state, which is what takes the person out of
#the deck for good.
REPORTED = "reported"


#WHETHER A CANDIDATE'S OWN GENDER PREFERENCE ACCEPTS THE VIEWER.
#
#preferred_gender is a comma separated string of 'Men'/'Women'/'Everyone', so
#this has to look inside it in SQL. EXACT TOKENS, NOT LIKE '%Men%': 'Women'
#contains the letters of 'Men' in lower case, so a substring match happens to
#work only because Postgres LIKE is case sensitive and the app happens to
#capitalise. That is a trap, not a rule. Splitting on the comma and comparing
#whole tokens cannot be broken by either.
#
#SPACES ARE STRIPPED FIRST because the string is assembled by the client and
#'Men, Women' is as likely as 'Men,Women'.
def accepts_gender(column, gender: str | None):
    token = gender_to_preference_token(gender)
    #NO TOKEN MEANS NO FILTER. A viewer who has not set a gender, or whose
    #gender the preference vocabulary cannot express, must not be hidden from
    #everybody - they are shown, and the other side's preference goes
    #unchecked because it cannot be checked.
    if token is None:
        return None

    #<value> = ANY(string_to_array(...)), via the standalone any_(). The
    #column method of the same name is the ANY(subquery) form and takes no
    #argument, which fails as a TypeError at request time rather than at
    #import - the sort of thing that only a test of the endpoint catches.
    tokens = func.string_to_array(func.replace(column, " ", ""), ",")
    return or_(
        column.is_(None),
        literal("Everyone") == any_(tokens),
        literal(token) == any_(tokens),
    )


#WHETHER A VALUE FALLS INSIDE A RANGE WHOSE ENDS MAY BE MISSING.
#
#Used in both directions for height, and the NULL rule is the same one every
#other filter here follows: a bound nobody set is not a bound, and a value
#nobody entered cannot be judged. Either being absent passes.
def within(value, low, high):
    if value is None:
        return []

    #THE THREE WAYS THIS CAN BE UNANSWERABLE, and all of them pass.
    #
    #THE THIRD ONE IS EASY TO MISS. `value` is sometimes the viewer's own
    #height - a Python int, absent as None, caught by the return above - and
    #sometimes users.height_cm, a COLUMN that is null per row. Checking only
    #the bounds would make `175 <= users.height_cm` evaluate to NULL against a
    #null height, which is not true, so anybody who had not entered a height
    #would disappear from the deck of everybody who had set a height
    #preference.
    unknown = literal(False) if isinstance(value, int) else value.is_(None)
    return [or_(unknown, low.is_(None), low <= value),
            or_(unknown, high.is_(None), high >= value)]


def mutual_eligibility_filters(me) -> list:
    """The hard filters deciding whether `me` and a candidate may see each other.

    EVERYTHING THE DECK APPLIES EXCEPT THE ALREADY-SWIPED EXCLUSION, which is
    the deck's own business (see the note at the top of this module) and is
    added by get_swipe_feed on top of this list.

    EVERY CHECK KEEPS NULL. A candidate who has not set an age range or a
    gender preference has not said no to anybody, so they stay - an unfinished
    profile is not a rejection. The same reading applies in both directions
    and to every filter below; it is the single rule that makes these
    composable.
    """
    #A PROFILE THAT CANNOT BE SWIPED IS NOT A CANDIDATE. An unfinished profile
    #should still surface - which is right for a blank FIELD and wrong for a
    #blank CARD. No photo means a grey rectangle with a name on it, and the
    #deck offering one spends a swipe on nothing.
    filters = [
        models.User.has_photos.is_(True),
        models.User.has_finished_set_up.is_(True),
    ]

    #Age range filter, always applied - the range the user picked is the range
    #they get. Expressed as BIRTHDAY CUTOFFS rather than age comparisons: age
    #is not a column, and comparing the raw birthday column to a constant date
    #keeps an index on it usable. Profiles with no birthday are kept so
    #incomplete profiles still surface.
    #
    #  age >= min  <=>  born on or before the day they turned min
    #  age <= max  <=>  born after the day they would have turned max + 1
    if me.min_age_range is not None:
        filters.append(or_(models.User.birthday <= years_ago(me.min_age_range),
                           models.User.birthday.is_(None)))
    if me.max_age_range is not None:
        filters.append(or_(models.User.birthday > years_ago(me.max_age_range + 1),
                           models.User.birthday.is_(None)))

    #gender preference filter derived from the viewer's preferred_gender.
    #Candidates with no gender set are kept so incomplete profiles still
    #surface.
    wanted_genders = preference_to_genders(me.preferred_gender)
    if wanted_genders is not None:
        filters.append(or_(models.User.gender.in_(wanted_genders),
                           models.User.gender.is_(None)))

    #=====================================================================
    #AND NOW THE OTHER DIRECTION.
    #
    #Applying only the viewer's preferences would offer people whose own
    #filters would never offer the viewer back. A right swipe on one of them
    #cannot become a match no matter what they do - they are never going to
    #see the card - and the app would call that "no match yet" when it is
    #structurally impossible, with no way for the user to tell the two apart.
    #=====================================================================
    my_age = age_from_birthday(me.birthday)
    if my_age is not None:
        #their minimum must not be above me, their maximum must not be below
        filters.append(or_(models.User.min_age_range.is_(None),
                           models.User.min_age_range <= my_age))
        filters.append(or_(models.User.max_age_range.is_(None),
                           models.User.max_age_range >= my_age))

    accepts_me = accepts_gender(models.User.preferred_gender, me.gender)
    if accepts_me is not None:
        filters.append(accepts_me)

    #HEIGHT, BOTH WAYS.
    filters.extend(within(models.User.height_cm,
                          literal(me.min_height_preference),
                          literal(me.max_height_preference)))
    filters.extend(within(me.height_cm,
                          models.User.min_height_preference,
                          models.User.max_height_preference))

    #AT LEAST ONE LANGUAGE IN COMMON, and no credit for a second. Two people
    #either understand each other or they do not, so this is a filter rather
    #than a point: a third shared language does not make them a better match.
    #
    #AN EMPTY LIST ON EITHER SIDE PASSES. languages_spoken is NOT NULL with an
    #empty-array default and is not asked for during setup, so a finished
    #profile can legitimately have none - and a strict reading would make
    #every one of those accounts invisible to everybody, in both directions.
    #Nothing stated is not a no.
    if me.languages_spoken:
        filters.append(or_(
            func.cardinality(models.User.languages_spoken) == 0,
            models.User.languages_spoken.overlap(me.languages_spoken),
        ))

    return filters


def _has_reported_either_way(me_id: int, other_id: int, db: Session) -> bool:
    """Whether either of these two has reported the other.

    THE reports TABLE, NOT THE 'reported' SWIPE, even though create_report
    writes both. The swipe is the consequence - it is what empties the deck -
    and the report is the fact. Reading the fact means this stays correct if
    the two ever come apart, and it reads the same in both directions, which
    the swipe does not: a report leaves a row on the REPORTER's side only, so
    asking the swipe table whether somebody reported ME needs the reverse
    lookup anyway.
    """
    return db.query(models.Reports.id).filter(
        or_(
            and_(models.Reports.reporter_id == me_id,
                 models.Reports.reported_user_id == other_id),
            and_(models.Reports.reporter_id == other_id,
                 models.Reports.reported_user_id == me_id),
        )
    ).first() is not None


def may_view_profile(me, user_id: int, db: Session) -> bool:
    """Whether `me` is allowed to read user `user_id`'s profile.

    ORDERED SO THE REFUSAL COMES FIRST. A report outranks every reason to
    allow: being matched with somebody you reported is exactly the case where
    the match exists and the access should not.
    """
    #your own profile, which /users/me serves properly but which should not
    #be a refusal here either
    if user_id == me.id:
        return True

    if _has_reported_either_way(me.id, user_id, db):
        return False

    #MATCHED, whatever the filters say now. Preferences change after a match -
    #an age range narrowed, a language removed - and none of that should take
    #away the profile of somebody already holding your Instagram handle.
    matched = db.query(models.Matches.id).filter(
        or_(
            and_(models.Matches.user_a_id == me.id,
                 models.Matches.user_b_id == user_id),
            and_(models.Matches.user_a_id == user_id,
                 models.Matches.user_b_id == me.id),
        )
    ).first()
    if matched is not None:
        return True

    #ALREADY DECIDED ABOUT THEM. The deck showed them once, so refusing now
    #would mean a card could be opened and then not re-opened - and the queue
    #retries swipes from disk for up to a week, so "decided" and "the server
    #knows it" are not simultaneous. REPORTED is excluded explicitly: it is an
    #action in this same column, and it is the one decision that must not
    #count as permission.
    decided = db.query(models.UserSwipes.id).filter(
        models.UserSwipes.user_id == me.id,
        models.UserSwipes.target_id == user_id,
        models.UserSwipes.action != REPORTED,
    ).first()
    if decided is not None:
        return True

    #THE DECK COULD HAVE OFFERED THEM. The same filters, asked of one id.
    eligible = db.query(models.User.id).filter(
        models.User.id == user_id,
        *mutual_eligibility_filters(me),
    ).first()
    return eligible is not None
