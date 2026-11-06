"""What the deck shows, and in what order.

TWO DIFFERENT KINDS OF TEST LIVE HERE and the difference matters.

THE HARD FILTERS ARE DETERMINISTIC. A candidate either survives them or does
not, so those tests assert exactly who comes back. Every one of them has a
counterpart asserting that the same profile with the field UNSET is shown -
the pair is the rule, and only one half of it is the bug.

THE ORDER IS NOT DETERMINISTIC, on purpose. The feed sorts by
-ln(random())/score, which is weighted sampling without replacement: a better
score raises the PROBABILITY of coming out early and never guarantees it.
Sorting by score directly would hand back the same ten faces on every refresh
and starve the rest of the pool. So the ordering tests sample the endpoint
repeatedly and assert a tendency, with the two candidates set up far enough
apart that the margin is not close - a test of a random process that fails one
run in fifty is worse than no test.
"""


def feed_ids(as_user, viewer):
    return [card["id"] for card in as_user(viewer).get("/users/feed").json()]


#HOW MANY DRAWS EACH ORDERING TEST TAKES, and how dominant the favoured
#candidate has to be.
#
#A DECISIVE MARGIN RATHER THAN "MORE THAN THE OTHER ONE", which is what these
#asserted first and why two runs in fifty-five failed. `strong > weak` is a
#fair question to ask of a coin weighted 60/40 and the wrong one to ask of a
#test: it fails by chance often enough to be ignored, which is worse than not
#existing. Every signal here is set up to win about 999 times in 1000, so a
#three-quarters floor passes without drama - and it fails reliably if somebody
#drops a term, because then the split goes to 50/50.
ROUNDS = 32
DOMINANT = 0.75


def first_place_counts(as_user, viewer, rounds=ROUNDS):
    """How often each candidate comes out of the deck first."""
    counts: dict[int, int] = {}
    for _ in range(rounds):
        ids = feed_ids(as_user, viewer)
        if ids:
            counts[ids[0]] = counts.get(ids[0], 0) + 1
    return counts


def assert_favoured(counts, winner, loser):
    won = counts.get(winner.id, 0)
    assert won >= ROUNDS * DOMINANT, (
        f"{winner.name} came first {won}/{ROUNDS} times, "
        f"{loser.name} {counts.get(loser.id, 0)} - expected "
        f"{winner.name} to dominate. {counts}")


def dormant(db, user, days):
    import datetime

    user.last_active = (datetime.datetime.now(datetime.timezone.utc)
                        - datetime.timedelta(days=days))
    db.flush()
    return user


class TestAProfileYouCannotSwipe:
    """has_photos and has_finished_set_up are now hard filters.

    THEY USED NOT TO BE, on the principle that an unfinished profile should
    still surface - which is right for a blank FIELD and wrong for a blank
    CARD. A candidate with no photo is a grey rectangle with a name on it, and
    offering one spends a swipe on nothing.
    """

    def test_somebody_with_no_photos_is_not_offered(self, as_user, make_user):
        me = make_user(name="Me")
        make_user(name="Faceless", photos=0)

        assert feed_ids(as_user, me) == []

    def test_somebody_mid_setup_is_not_offered(self, db, as_user, make_user):
        me = make_user(name="Me")
        them = make_user(name="Halfway")
        them.has_finished_set_up = False
        db.flush()

        assert feed_ids(as_user, me) == []

    def test_a_finished_profile_with_a_photo_is(self, as_user, make_user):
        me = make_user(name="Me")
        them = make_user(name="Ready", photos=2)

        assert feed_ids(as_user, me) == [them.id]


class TestHeightIsFilteredBothWays:
    """The height preference columns have existed unused since date
    preferences shipped. These are what reads them - in both directions, like
    age and gender.
    """

    def test_too_short_for_my_preference(self, as_user, make_user):
        me = make_user(name="Me", min_height_preference=175)
        make_user(name="Shorter", height_cm=160)

        assert feed_ids(as_user, me) == []

    def test_too_tall_for_my_preference(self, as_user, make_user):
        me = make_user(name="Me", max_height_preference=170)
        make_user(name="Taller", height_cm=190)

        assert feed_ids(as_user, me) == []

    def test_and_i_must_fit_theirs(self, as_user, make_user):
        me = make_user(name="Me", height_cm=165)
        make_user(name="Picky", height_cm=180, min_height_preference=175)

        assert feed_ids(as_user, me) == []

    def test_inside_both_preferences_is_fine(self, as_user, make_user):
        me = make_user(name="Me", height_cm=180,
                       min_height_preference=160, max_height_preference=175)
        them = make_user(name="Fits", height_cm=170,
                         min_height_preference=175, max_height_preference=190)

        assert feed_ids(as_user, me) == [them.id]

    def test_no_preference_set_filters_nobody(self, as_user, make_user):
        me = make_user(name="Me", height_cm=150)
        them = make_user(name="Anyone", height_cm=200)

        assert feed_ids(as_user, me) == [them.id]

    def test_and_a_candidate_with_no_height_is_kept(self, as_user, make_user):
        #a bound nobody can be measured against is not a bound
        me = make_user(name="Me", min_height_preference=175,
                       max_height_preference=185)
        them = make_user(name="Unmeasured", height_cm=None)

        assert feed_ids(as_user, me) == [them.id]


class TestLanguagesAreAFilterNotAScore:
    """AT LEAST ONE IN COMMON, AND NO CREDIT FOR A SECOND.

    Two people either understand each other or they do not, so this belongs
    in the WHERE clause: a third shared language does not make them a better
    match, and giving it a point would say that it does.
    """

    def test_no_common_language_is_not_offered(self, as_user, make_user):
        me = make_user(name="Me", languages_spoken=["Greek"])
        make_user(name="Them", languages_spoken=["German"])

        assert feed_ids(as_user, me) == []

    def test_one_in_common_is_enough(self, as_user, make_user):
        me = make_user(name="Me", languages_spoken=["Greek", "English"])
        them = make_user(name="Them", languages_spoken=["English", "French"])

        assert feed_ids(as_user, me) == [them.id]

    def test_an_empty_list_on_their_side_passes(self, as_user, make_user):
        """LANGUAGES ARE NOT ASKED FOR DURING SETUP, so a finished profile can
        legitimately have none. Reading the filter strictly would make every
        one of those accounts invisible to everybody, in both directions, for
        a field they were never prompted to fill in.
        """
        me = make_user(name="Me", languages_spoken=["Greek"])
        them = make_user(name="Them", languages_spoken=[])

        assert feed_ids(as_user, me) == [them.id]

    def test_and_an_empty_list_on_mine_filters_nobody(
        self, as_user, make_user
    ):
        me = make_user(name="Me", languages_spoken=[])
        them = make_user(name="Them", languages_spoken=["Swahili"])

        assert feed_ids(as_user, me) == [them.id]

    def test_sharing_three_is_not_better_than_sharing_one(
        self, db, as_user, make_user
    ):
        """THE POINT OF THIS CLASS, stated as an ordering test.

        Both candidates are identical except that one shares every language
        and the other shares exactly one. If languages scored, the first would
        dominate first place. They should be indistinguishable.
        """
        me = make_user(name="Me",
                       languages_spoken=["Greek", "English", "German"])
        many = make_user(name="Many",
                         languages_spoken=["Greek", "English", "German"])
        one = make_user(name="One", languages_spoken=["Greek"])

        counts = first_place_counts(as_user, me, rounds=40)

        #NOT an assertion that the split is 20/20 - that would be testing the
        #random number generator. Only that neither is shut out, which is what
        #a scored language term would have done.
        assert counts.get(many.id, 0) >= 5, counts
        assert counts.get(one.id, 0) >= 5, counts


class TestWhatLiftsAProfile:
    """The three things that earn points, each shown to actually earn them.

    SAMPLED, NOT ASSERTED ONCE. See the module docstring: the order is a
    weighted draw, so the question is always how lopsided the split is.

    EVERY TEST BUT THE ACTIVITY ONE MAKES BOTH CANDIDATES DORMANT, and that is
    the thing that makes these reliable rather than a coin weighted slightly.
    A fresh profile carries the full 2.0 activity term, so comparing two fresh
    candidates on a 1.0 university bonus is a 3-against-2 draw - a 60/40 split
    that loses roughly one run in three. Dormant for sixty days the activity
    term is worth about 2 x exp(-20), near enough nothing, which leaves the
    signal under test as the only thing separating them. Isolating the term
    was the right way to write these in the first place; the flakiness is just
    what noticed.
    """

    def test_a_super_like_comes_first(self, db, as_user, make_user, swipe):
        #university=None SO THE SHARED BONUS DOES NOT DILUTE THIS. make_user
        #puts everybody at the same university, so both candidates would
        #collect +1.0 - and because the draw is proportional to total score
        #rather than to the gap, that turns a 3-against-0 signal into
        #4-against-1. See the note on assert_favoured.
        me = make_user(name="Me", university=None)
        admirer = dormant(db, make_user(name="Admirer"), days=60)
        stranger = dormant(db, make_user(name="Stranger"), days=60)
        swipe(admirer, me, "super_like")

        counts = first_place_counts(as_user, me)

        assert_favoured(counts, admirer, stranger)

    def test_shared_interests_lift(self, db, as_user, make_user):
        #ten shared interests against none, which is the full width of the
        #catalogue budget and therefore the strongest this term can get
        tags = ["music", "hiking", "films", "gym", "cooking",
                "reading", "travel", "art", "football", "coffee"]
        me = make_user(name="Me", interest_tags=tags, university=None)
        alike = dormant(db, make_user(name="Alike", interest_tags=tags), 60)
        unalike = dormant(
            db, make_user(name="Unalike", interest_tags=["chess"]), 60)

        counts = first_place_counts(as_user, me)

        assert_favoured(counts, alike, unalike)

    def test_being_recently_active_lifts(self, db, as_user, make_user):
        #THE ONE TEST THAT MUST NOT NEUTRALISE ACTIVITY, since it is the term
        #under test. Nothing else differs, so the draw is 2.0 against ~0.
        me = make_user(name="Me", university=None)
        here_now = make_user(name="Here")
        gone = dormant(db, make_user(name="Gone"), days=60)

        counts = first_place_counts(as_user, me)

        assert_favoured(counts, here_now, gone)

    def test_the_same_university_lifts(self, db, as_user, make_user):
        me = make_user(name="Me", university="University of Macedonia")
        classmate = dormant(db, make_user(
            name="Classmate", university="University of Macedonia"), 60)
        elsewhere = dormant(db, make_user(
            name="Elsewhere", university="National Technical University"), 60)

        counts = first_place_counts(as_user, me)

        assert_favoured(counts, classmate, elsewhere)


class TestRankingIsNotFiltering:
    def test_the_worst_possible_candidate_is_still_shown(
        self, db, as_user, make_user
    ):
        """THE LINE BETWEEN THE WHERE CLAUSE AND THE ORDER BY.

        Dormant for a year, nothing in common, a different university: this
        profile scores about as low as the expression allows. It passed every
        hard filter, so it is in the deck. A score is a position, never a
        reason to hide somebody - and the floor under the sampling key exists
        so that a score of zero cannot divide by zero and drop them.
        """
        me = make_user(name="Me", interest_tags=["music"],
                       university="University of Macedonia")
        nobody = dormant(db, make_user(name="Nobody", interest_tags=["chess"],
                                       university="Elsewhere"), days=365)

        assert feed_ids(as_user, me) == [nobody.id]

    def test_and_so_is_everybody_when_nobody_scores(
        self, db, as_user, make_user
    ):
        #a viewer with no interests and no university scores every candidate
        #identically at the activity term alone; all of them must still come
        #back rather than the expression collapsing
        me = make_user(name="Me", interest_tags=[], university=None)
        pool = [make_user(name=f"P{i}") for i in range(4)]

        assert sorted(feed_ids(as_user, me)) == sorted(p.id for p in pool)
