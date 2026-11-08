"""The swipe deck: who is offered, and who is deliberately not."""

from sqlalchemy import any_, case, extract, func, literal, or_

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth import current_uid, verified_claims, verified_email_uid
from database import models, schemas
from database.database import get_db

router = APIRouter()

from sqlalchemy.orm import selectinload

from ages import age_from_birthday, years_ago
from api_models import UserCards
from preferences.preferences import (gender_to_preference_token,
                                     preference_to_genders)
from typing import List


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
def _accepts_gender(column, gender: str | None):
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
def _within(value, low, high):
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


#=====================================================================
#THE SCORE: what decides the ORDER of whoever survived the filters above.
#
#AN EXPRESSION, NOT A COLUMN, and that is the whole architecture. There is no
#stored desirability number anywhere - no Elo, no rating, nothing attached to
#an account. The score exists for the duration of one request, is computed
#against the candidates already narrowed down by the hard filters, and is
#thrown away. Two consequences worth stating because they are the reasons:
#
#  IT CAN BE PAIRWISE. Shared interests and same-university are facts about a
#  PAIR, so no per-profile number could hold them. Computing them per request
#  is what makes them expressible at all.
#
#  IT CANNOT RUN AWAY WITH ITSELF. A stored popularity score feeds back on
#  itself - rank high, get shown more, collect more likes, rank higher - and
#  on a few hundred users that collapses into the same ten faces in every
#  deck. Nothing here reads how often somebody was liked.
#
#MEASURED THROUGH THIS ENDPOINT, whole request including the photo load: 22ms
#against a 2,000 candidate pool and 112ms against 20,000, so roughly 6us per
#candidate scored. There is no precomputation, no nightly job and no cached
#score, because at the size this service will plausibly reach none of that
#buys anything worth having.
#
#IF THE POOL EVER GETS BIG ENOUGH TO HURT, the fix is not a stored score - it
#is to stop scoring the whole pool. Take a bounded random sample of candidates
#first and rank within it; the deck only needs ten good cards, not the single
#best ten in the country.
#=====================================================================

#A SUPER LIKE IS THE STRONGEST THING ANYBODY CAN SAY, and the only interest
#the deck discloses, so it also comes first. Weighted above activity because
#somebody spending one of their two a week on you is a deliberate act, where
#being online is an accident of timing.
W_SUPER_LIKE = 3.0

#ACTIVITY, which is the whole reason last_active moved into Postgres. A like
#that nobody will ever open is worse than no like.
W_ACTIVITY = 2.0

#ONE POINT PER SHARED INTEREST, as asked. Note the range: the catalogue gives
#everybody a budget of 10 interests, so this term alone runs 0-10 and can
#outweigh every other signal combined. That is a deliberate choice about what
#the deck is for - shared ground over recency - and the number to change if
#it turns out to bury active profiles under dormant ones with the same taste.
W_INTEREST = 1.0

#SAME UNIVERSITY, as a nudge. It is the thing this app has that a general
#dating app does not.
W_SAME_UNIVERSITY = 1.0

#HOW FAST ACTIVITY DECAYS. exp(-age/T): 1.0 for somebody here now, 0.37 at
#three days, 0.05 at nine. A curve rather than a cliff, so there is no
#particular hour at which a person stops counting.
ACTIVITY_DECAY_SECONDS = 3 * 24 * 60 * 60

#NOTHING HERE READS trait_tags, DELIBERATELY. Personality similarity does not
#predict compatibility and neither does complementarity - scoring it means
#picking a sign for introvert x extrovert with no evidence and then imposing
#that guess on everybody. MBTI lands in the same array, which makes the point
#sharper: there is no defensible weight for INTJ x ENFP. Traits earn their
#place on the card by giving the viewer something to react to.
#
#NOR religion, political_view OR sexual_orientation. Those are Article 9
#special category data, and the published privacy statement says in as many
#words that nothing filters or ranks on them. The consent collected covers
#displaying them on a profile, not feeding them into a sort.
#
#NOR languages_spoken, which is a hard filter instead: at least one in
#common, and no credit for more. Two people either understand each other or
#they do not; a third shared language does not make them a better match.
def _score(me: models.User, super_liked_me: set[int]):
    terms = [
        W_ACTIVITY * func.exp(
            -func.coalesce(
                extract("epoch", func.now() - models.User.last_active),
                #no timestamp at all is treated as long dormant rather than as
                #unknown: every row has one by default and the migration
                #backfilled the rest, so this is a corner that should not
                #arise and must not poison the sum if it does
                literal(ACTIVITY_DECAY_SECONDS * 10),
            ) / float(ACTIVITY_DECAY_SECONDS)
        ),
    ]

    #COUNTED IN SQL rather than in Python, because the whole point is that the
    #ORDER BY can see it.
    #
    #ONE TEST PER INTEREST THE VIEWER HAS, summed - not an array intersection
    #subquery. The catalogue caps everybody at 10 interests, so this is at
    #most ten `'tag' = ANY(interest_tags)` checks, each of which the GIN index
    #on interest_tags can answer. The subquery version reads shorter and needs
    #raw SQL to express, which is a bad trade for an expression that decides
    #what people see.
    if me.interest_tags:
        shared = None
        for tag in me.interest_tags:
            hit = case((models.User.interest_tags.any(tag), 1), else_=0)
            shared = hit if shared is None else shared + hit
        terms.append(W_INTEREST * shared)

    if me.university:
        terms.append(W_SAME_UNIVERSITY * case(
            (models.User.university == me.university, 1), else_=0))

    #READS THE SET THE DECK ALREADY FETCHED for the card banner, so this costs
    #no extra query. Skipped entirely when nobody has super liked you, which
    #is the common case and keeps the expression smaller.
    if super_liked_me:
        terms.append(W_SUPER_LIKE * case(
            (models.User.id.in_(super_liked_me), 1), else_=0))

    total = terms[0]
    for term in terms[1:]:
        total = total + term
    return total

#HOW MANY CARDS A PAGE HOLDS, and the ceiling on what a client may ask for.
#
#THE DEFAULT WAS 10 AND HARDCODED, while the deck declared batchSize = 20 and
#sent nothing - so the client, the server and the README each described a
#different page size. 20 matches what the deck always thought it was getting.
#
#THE CAP EXISTS BECAUSE THE NUMBER ARRIVES FROM A CLIENT. Nothing here is
#expensive per row, but an unbounded limit is an invitation to ask for the
#whole table in one request.
DEFAULT_PAGE = 20
MAX_PAGE = 40

#AND HOW MANY IDS IT WILL ACCEPT BACK. The deck sends what it is holding plus
#whatever is stuck in the swipe queue; both are bounded by how fast somebody
#can swipe between flushes, so this is generous rather than tight. Past it the
#extras are ignored rather than refused: the only cost of a missed exclusion
#is a card the client filters out itself, which is what it did before any of
#this existed.
MAX_EXCLUDE = 200


def _parse_exclude(raw: str) -> list[int]:
    """Read a comma separated id list, ignoring anything that is not one.

    LENIENT ON PURPOSE. These are exclusions: every id here can only ever
    REMOVE a candidate from the caller's own deck, so a malformed one is not
    worth a 422 that breaks the swipe deck. Nothing is disclosed by it and
    nothing but the caller is affected.
    """
    out: list[int] = []
    for part in raw.split(","):
        part = part.strip()
        if not part:
            continue
        try:
            out.append(int(part))
        except ValueError:
            continue
        if len(out) >= MAX_EXCLUDE:
            break
    return out


#get multiple users for the homepage
@router.get("/users/feed", response_model = List[UserCards])
def get_swipe_feed(
    limit: int = DEFAULT_PAGE,
    #WHAT THE CLIENT IS ALREADY HOLDING: the cards in the deck, plus the
    #targets of swipes still sitting in SwipeQueue waiting for a network.
    #
    #WHY THE SERVER HAS TO BE TOLD. It excludes what it has a swipe row for,
    #and a queued swipe has no row yet - so it keeps offering those people,
    #and the deck throws them away on arrival. That was merely wasteful until
    #the discarded set grew past a page: then a whole page could land inside
    #it, three of those in a row tripped the deck's "nothing new" counter, and
    #the user was told there were no more profiles with people still unseen.
    #Offline, that is reachable in about forty swipes. See the test.
    exclude: str = "",
    uid: str = Depends(verified_email_uid),
    db: Session = Depends(get_db),
):
    #first get the current user id to exclude it
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail='Current User not found')

    #get users other than you and not users we already saw
    seen_ids = db.query(models.UserSwipes.target_id).filter(
        models.UserSwipes.user_id == me.id
    ).all()

    seen_ids_list = [x[0] for x in seen_ids]

    seen_ids_list.append(me.id)
    seen_ids_list.extend(_parse_exclude(exclude))

    #WHOEVER LIKED YOU IS IN THE DECK, AND IS NOT TOLD SO.
    #
    #Holding them back for a separate page would mean the deck could not
    #produce a match at all - every one of them would arrive somewhere else,
    #and the primary screen would never pay out. A pass on somebody whose
    #interest you did not know about is simply a pass.
    #
    #Their interest stays hidden, which is the point: it is what keeps a right
    #swipe honest, and it is the shape a "see who liked you" tier is sold on
    #later. /likes still works and still has its tests.

    #WHO SUPER LIKED ME, which is the only interest the deck discloses. Reads
    #straight off ix_user_swipes_target_action - (target_id, action) is
    #exactly this question.
    super_liked_me = {
        row[0] for row in db.query(models.UserSwipes.user_id).filter(
            models.UserSwipes.target_id == me.id,
            models.UserSwipes.action == "super_like",
        ).all()
    }

    #base filter: skip yourself and anyone already swiped.
    #
    #A PROFILE THAT CANNOT BE SWIPED IS NOT A CANDIDATE. An unfinished profile
    #should still surface - which is right for a blank FIELD and wrong for a
    #blank CARD. No photo means a grey rectangle with a name on it, and the
    #deck offering one spends a swipe on nothing.
    filters = [
        models.User.id.notin_(seen_ids_list),
        models.User.has_photos.is_(True),
        models.User.has_finished_set_up.is_(True),
    ]

    #Age range filter, always applied - the range the user picked is the range
    #they get. Expressed as BIRTHDAY CUTOFFS rather than age comparisons: age is
    #not a column, and comparing the raw birthday column to a constant
    #date keeps an index on it usable. Profiles with no birthday are kept so
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

    #gender preference filter derived from the viewer's preferred_gender. Candidates
    #with no gender set are kept so incomplete profiles still surface.
    wanted_genders = preference_to_genders(me.preferred_gender)
    if wanted_genders is not None:
        filters.append(or_(models.User.gender.in_(wanted_genders), models.User.gender.is_(None)))

    #=====================================================================
    #AND NOW THE OTHER DIRECTION, which is what this endpoint spent its
    #whole life not doing.
    #
    #THE BUG. Only the viewer's preferences were applied, so the deck
    #offered people whose own filters would never have offered the viewer
    #back. A right swipe on one of them could not become a match no matter
    #what they did - they were never going to see the card. The app called
    #that "no match yet"; it was structurally impossible, and the user had
    #no way to tell the two apart.
    #
    #WHY IT IS WORTH THE SMALLER DECK. A deck of people who can match you
    #is smaller than a deck of people who cannot, and on a service with a
    #few thousand students that difference is felt. It is still the right
    #trade: the alternative spends somebody's attention on cards that
    #cannot pay out, and a like that cannot be returned is the most
    #discouraging thing this app can produce.
    #
    #EVERY CHECK KEEPS NULL, exactly as the two above do. A candidate who
    #has not set an age range or a gender preference has not said no to
    #anybody, so they stay - an unfinished profile is not a rejection.
    #=====================================================================
    my_age = age_from_birthday(me.birthday)
    if my_age is not None:
        #their minimum must not be above me, their maximum must not be below
        filters.append(or_(models.User.min_age_range.is_(None),
                           models.User.min_age_range <= my_age))
        filters.append(or_(models.User.max_age_range.is_(None),
                           models.User.max_age_range >= my_age))

    accepts_me = _accepts_gender(models.User.preferred_gender, me.gender)
    if accepts_me is not None:
        filters.append(accepts_me)

    #HEIGHT, BOTH WAYS. The preference columns have existed unused since the
    #date preferences shipped; this is what reads them.
    filters.extend(_within(models.User.height_cm,
                           literal(me.min_height_preference),
                           literal(me.max_height_preference)))
    filters.extend(_within(me.height_cm,
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

    #ORDERED BY WEIGHTED RANDOM SAMPLING, not by the score itself.
    #
    #-ln(random())/weight is the exponential trick for sampling without
    #replacement: a higher score raises the PROBABILITY of coming out early
    #and never guarantees it. Sorting by score directly would hand back the
    #same ten faces on every refresh, so the rest of the pool would never be
    #seen however well it scored - which is the feedback loop this whole
    #design avoids elsewhere, reintroduced in the ORDER BY.
    #
    #It also keeps the deck feeling different each time it refills, which the
    #old random() did for free and would be a real loss.
    #
    #greatest(score, 0.001) because a score of zero would divide by zero. A
    #floor rather than a special case: it means the worst candidate is very
    #unlikely to come first rather than impossible, which is correct - they
    #still passed every hard filter.
    score = _score(me, super_liked_me)
    sampling_key = -func.ln(func.random()) / func.greatest(score, 0.001)

    #CLAMPED, NOT VALIDATED. A client asking for 0 or 500 gets a page rather
    #than a 422: there is one caller, the number is a buffer size rather than
    #a user's intent, and a deck that fails to refill is worse than one that
    #refills by a different amount than it asked for.
    page = max(1, min(limit, MAX_PAGE))

    #selectinload pulls every user's photos in a single extra query (no N+1)
    users = db.query(models.User).options(
        selectinload(models.User.photos)
    ).filter(*filters).order_by(sampling_key).limit(page).all()

    results = []
    for user in users:
        #sort photos by display order
        sorted_photos = sorted(user.photos, key = lambda x: x.display_order)
        photo_urls = [p.photo_url for p in sorted_photos]

        if not photo_urls:
            photo_urls = []
        
        results.append({
            "id": user.id,
            "name": user.name,
            "age": age_from_birthday(user.birthday),
            "job": user.job,
            "bio": user.bio,
            "photos": photo_urls,
            #NOT ORDERED BY IT YET. Surfacing these first belongs with the
            #ranking work, where "what comes next" is decided once for every
            #reason at once rather than bolted on here.
            "super_liked_you": user.id in super_liked_me,
        })
    return results
