"""Who may read somebody else's profile.

WHAT THESE EXIST BECAUSE OF. /users/{id}/profile took any integer from anybody
signed in and answered it. User ids are sequential, so one account with a
verified university address could walk 1..N and collect the whole database -
including religion, political view and sexual orientation, which GDPR Art. 9
calls special category data. The endpoint had privacy tests already, and they
all passed: they asked which FIELDS came back and never who was asking.

SO THE SHAPE OF THE OLD BUG IS THE SHAPE OF THESE TESTS. Every one of them
builds two people with a stated relationship - none, a swipe, a match, a
report - and asks what one can see of the other. A test that only checks the
happy path would pass against the broken version, which is exactly what
happened the first time.

THEY ALSO PIN THE REFUSAL ITSELF. 404 rather than 403, identical to a user
that does not exist, because a distinguishable refusal rebuilds the list of
real ids and, where a report is the reason, tells somebody they were reported.
"""

import datetime


def profile(as_user, viewer, target_id):
    return as_user(viewer).get(f"/users/{target_id}/profile")


def report(as_user, who, target):
    return as_user(who).post("/reports", json={
        "reported_user_id": target.id,
        "category": "profile_content",
        "subcategory": "nudity_or_sexual",
        "details": "it was bad",
    })


def complete_match(as_user, swipe, first_liker, completer):
    """The two swipes that make a match, as test_likes_and_matches does it."""
    swipe(first_liker, completer, "like",
          at=datetime.datetime.now(datetime.timezone.utc)
          - datetime.timedelta(days=1))
    return as_user(completer).post(
        "/swipes", json={"target_id": first_liker.id, "action": "like"}
    ).json()["match_id"]


class TestSomebodyTheDeckCouldOffer:
    def test_is_readable(self, as_user, make_user):
        #the ordinary case, and the one the old tests covered: two people who
        #pass each other's filters
        me = make_user(name="Me", gender="Male", preferred_gender="Women")
        her = make_user(name="Her", gender="Female", photos=3)

        body = profile(as_user, me, her.id)
        assert body.status_code == 200, body.text
        assert body.json()["name"] == "Her"


class TestSomebodyTheDeckWouldNeverOffer:
    def test_the_wrong_gender_is_a_404(self, as_user, make_user):
        #THE FILTER THE DECK APPLIES, NOW APPLIED HERE TOO. Before this, a
        #viewer who asked only to see women could read every man's profile by
        #id - the deck withheld them and the endpoint handed them over.
        me = make_user(name="Me", gender="Male", preferred_gender="Women")
        him = make_user(name="Him", gender="Male")

        assert profile(as_user, me, him.id).status_code == 404

    def test_outside_my_age_range_is_a_404(self, as_user, make_user):
        me = make_user(name="Me", age=20, max_age_range=25)
        older = make_user(name="Older", age=40)

        assert profile(as_user, me, older.id).status_code == 404

    def test_somebody_whose_range_excludes_me_is_a_404(self, as_user, make_user):
        #THE OTHER DIRECTION COUNTS TOO. The deck will not offer somebody who
        #would never be offered me, and reading their profile by id was a way
        #around that - which matters most for the people who set a narrow
        #range precisely so that strangers outside it would not see them.
        me = make_user(name="Me", age=19)
        her = make_user(name="Her", age=30, min_age_range=28, max_age_range=35)

        assert profile(as_user, me, her.id).status_code == 404

    def test_an_unfinished_profile_is_a_404(self, as_user, make_user):
        me = make_user(name="Me")
        half = make_user(name="Half", has_finished_set_up=False)

        assert profile(as_user, me, half.id).status_code == 404

    def test_the_refusal_is_the_same_as_a_user_who_does_not_exist(
        self, as_user, make_user
    ):
        #THE WHOLE POINT OF 404. If "not for you" and "no such person" differed
        #by a status code or a body, walking the ids would still map out every
        #real account - which is the enumeration this is meant to stop, only
        #one step longer.
        me = make_user(name="Me", gender="Male", preferred_gender="Women")
        him = make_user(name="Him", gender="Male")

        refused = profile(as_user, me, him.id)
        missing = profile(as_user, me, 999999)

        assert refused.status_code == missing.status_code == 404
        assert refused.json() == missing.json()


class TestSomebodyIHaveDecidedAbout:
    def test_a_pass_still_lets_me_look(self, as_user, make_user, swipe):
        #THE DECK DROPS THEM, THIS DOES NOT. Having swiped is why the deck has
        #nothing left to offer, not a reason to lose the card you already saw
        #- and the swipe queue retries from disk for up to a week, so "decided"
        #and "the server knows" are not the same moment.
        me = make_user(name="Me")
        them = make_user(name="Them")
        swipe(me, them, "pass")

        assert profile(as_user, me, them.id).status_code == 200

    def test_but_somebody_i_reported_is_gone(self, as_user, make_user):
        #A REPORT IS ALSO A ROW IN user_swipes, with action 'reported', so
        #"have I decided about them" would say yes and hand the profile back.
        #It is the one decision that must not count as permission.
        me = make_user(name="Me")
        them = make_user(name="Them")
        assert report(as_user, me, them).status_code == 201

        assert profile(as_user, me, them.id).status_code == 404

    def test_and_so_is_somebody_who_reported_me(self, as_user, make_user):
        #THE DIRECTION THE DECK DOES NOT COVER. Being reported leaves its swipe
        #row on the reporter's side, so nothing stopped the reported person
        #from carrying on reading the profile of whoever reported them.
        me = make_user(name="Me")
        them = make_user(name="Them")
        assert report(as_user, them, me).status_code == 201

        assert profile(as_user, me, them.id).status_code == 404


class TestSomebodyIAmMatchedWith:
    def test_is_readable_even_once_my_preferences_would_exclude_them(
        self, db, as_user, make_user, swipe
    ):
        #PREFERENCES CHANGE AFTER A MATCH. Narrowing an age range should not
        #take away the profile of somebody already holding your Instagram
        #handle - the match is the stronger statement, and it outranks the
        #filters that introduced the two of them.
        me = make_user(name="Me", age=20, min_age_range=18, max_age_range=99)
        them = make_user(name="Them", age=24)
        complete_match(as_user, swipe, them, me)

        me.max_age_range = 21
        db.flush()

        assert profile(as_user, me, them.id).status_code == 200

    def test_unless_one_of_us_reported_the_other(
        self, as_user, make_user, swipe
    ):
        #THE ORDER THE RULE IS WRITTEN IN. A report outranks a match, which is
        #precisely the case where the match row still exists and the access
        #should not.
        me = make_user(name="Me")
        them = make_user(name="Them")
        complete_match(as_user, swipe, them, me)
        assert report(as_user, me, them).status_code == 201

        assert profile(as_user, me, them.id).status_code == 404


class TestYourself:
    def test_your_own_profile_is_not_a_refusal(self, as_user, make_user):
        #/users/me is the endpoint for this, but a viewer asking for their own
        #id should not be told they do not exist - and they fail their own
        #gender filter often enough for it to matter.
        me = make_user(name="Me", gender="Male", preferred_gender="Women")

        assert profile(as_user, me, me.id).status_code == 200
