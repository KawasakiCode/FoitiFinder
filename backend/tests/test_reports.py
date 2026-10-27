"""Reporting somebody: what it writes, what it changes, and what it hides.

THE RULE THAT MATTERS MOST IS AN ABSENCE. A report hides the match from the
REPORTER only. If it hid it from both, a match disappearing would tell a
person who already holds your Instagram handle that you reported them - which
is the one outcome the whole per-side design exists to prevent, and the kind
of thing a later refactor "tidies up" into symmetry without noticing.
"""

import report_reasons


def matched(as_user, swipe, alice, bob):
    """A revealed match between the two, so reports can be made against it."""
    swipe(bob, alice, "like")
    match_id = as_user(alice).post(
        "/swipes", json={"target_id": bob.id, "action": "like"}
    ).json()["match_id"]
    as_user(alice).post(f"/matches/{match_id}/confirm")
    as_user(bob).post(f"/matches/{match_id}/confirm")
    return match_id


def report(as_user, who, target, category="profile_content",
           subcategory="nudity_or_sexual", details="it was bad"):
    return as_user(who).post("/reports", json={
        "reported_user_id": target.id,
        "category": category,
        "subcategory": subcategory,
        "details": details,
    })


class TestFilingOne:
    def test_it_is_accepted_and_stored(self, db, as_user, make_user):
        from database import models

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        assert report(as_user, alice, bob).status_code == 201

        row = db.query(models.Reports).one()
        assert row.reporter_id == alice.id
        assert row.reported_user_id == bob.id
        assert row.category == "profile_content"
        assert row.subcategory == "nudity_or_sexual"
        assert row.details == "it was bad"
        assert row.reviewed_at is None

    def test_the_reporter_is_kept(self, db, as_user, make_user):
        #ANONYMOUS TO THEM IS NOT ANONYMOUS. The reported user is never told
        #who said it; a reviewer has to be able to see one person reporting
        #fifteen profiles in an afternoon.
        from database import models

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        report(as_user, alice, bob)
        assert db.query(models.Reports).one().reporter_id == alice.id

    def test_nothing_about_it_comes_back(self, as_user, make_user):
        #not even an id: the app has no screen that would show one, and a
        #report id in a client is a handle on somebody else's accusation
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        body = report(as_user, alice, bob).json()
        assert body == {"reported": True}

    def test_blank_details_are_stored_as_nothing(self, db, as_user, make_user):
        #so "did anybody write anything" is a null check rather than a check
        #for null or empty or whitespace
        from database import models

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        report(as_user, alice, bob, details="   ")
        assert db.query(models.Reports).one().details is None

    def test_details_are_optional(self, as_user, make_user):
        #requiring them turns "I would rather not write this out" into "I
        #will not report it"
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        response = as_user(alice).post("/reports", json={
            "reported_user_id": bob.id,
            "category": "profile_content",
            "subcategory": "other",
        })
        assert response.status_code == 201


class TestWhatItAlsoDoes:
    def test_they_leave_the_deck(self, as_user, make_user):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        assert bob.id in [card["id"] for card in
                          as_user(alice).get("/users/feed").json()]

        report(as_user, alice, bob)
        assert bob.id not in [card["id"] for card in
                              as_user(alice).get("/users/feed").json()]

    def test_the_swipe_records_why(self, db, as_user, make_user):
        from database import models

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        report(as_user, alice, bob)

        swipe = db.query(models.UserSwipes).filter_by(
            user_id=alice.id, target_id=bob.id).one()
        assert swipe.action == "reported"

    def test_an_earlier_like_is_overwritten(self, db, as_user, make_user):
        #reporting somebody you had liked has to beat the like, or the next
        #swipe they make rebuilds a match with somebody just reported
        from database import models

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        as_user(alice).post("/swipes",
                            json={"target_id": bob.id, "action": "like"})
        report(as_user, alice, bob)

        swipe = db.query(models.UserSwipes).filter_by(
            user_id=alice.id, target_id=bob.id).one()
        assert swipe.action == "reported"

    def test_the_match_goes_from_the_reporter_s_list(
        self, as_user, make_user, swipe
    ):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        matched(as_user, swipe, alice, bob)

        report(as_user, alice, bob, category="harassment",
               subcategory="made_me_feel_unsafe")
        assert as_user(alice).get("/matches").json() == []

    def test_and_stays_on_the_other_one_s(self, as_user, make_user, swipe):
        """THE ONE THAT MUST NOT BE 'FIXED' INTO SYMMETRY.

        If reporting removed the match for both sides, a match disappearing
        would tell the reported person - who holds the reporter's Instagram
        handle - that they had been reported. The report is meant to get
        somebody away from a harasser, not to announce itself to them.
        """
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        matched(as_user, swipe, alice, bob)

        report(as_user, alice, bob, category="harassment",
               subcategory="threats_or_stalking")
        assert len(as_user(bob).get("/matches").json()) == 1

    def test_and_nobody_is_pushed_anything(
        self, as_user, make_user, swipe, pushes
    ):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        matched(as_user, swipe, alice, bob)

        pushes.clear()
        report(as_user, alice, bob, category="harassment",
               subcategory="abusive_messages")
        assert pushes == []

    def test_the_row_survives_the_reported_account_being_deleted(
        self, db, as_user, make_user
    ):
        #SET NULL, NOT CASCADE, which is the opposite of every other foreign
        #key here: leaving is a thing people do after being reported, so that
        #is exactly the row worth keeping.
        from database import models

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        report(as_user, alice, bob)
        as_user(bob).delete("/users/me")

        row = db.query(models.Reports).one()
        assert row.reported_user_id is None
        assert row.subcategory == "nudity_or_sexual"
        assert row.details == "it was bad"


class TestWhatIsRefused:
    def test_a_reason_that_does_not_exist(self, as_user, make_user):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        assert report(as_user, alice, bob, category="profile_content",
                      subcategory="invented").status_code == 422

    def test_a_category_that_does_not_exist(self, as_user, make_user):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        assert report(as_user, alice, bob, category="invented",
                      subcategory="other").status_code == 422

    def test_a_real_subcategory_under_the_wrong_category(
        self, as_user, make_user
    ):
        #THE REASON THIS IS A MAPPING AND NOT TWO LISTS. Both codes exist, and
        #the pair means nothing - a flat check would have filed it.
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        assert report(as_user, alice, bob, category="fake_profile",
                      subcategory="minor_sexual_content").status_code == 422

    def test_reporting_yourself(self, as_user, make_user):
        alice = make_user(name="Alice")
        assert report(as_user, alice, alice).status_code == 400

    def test_reporting_somebody_who_does_not_exist(self, as_user, make_user):
        alice = make_user(name="Alice")
        response = as_user(alice).post("/reports", json={
            "reported_user_id": 999999,
            "category": "profile_content",
            "subcategory": "other",
        })
        assert response.status_code == 404

    def test_harassment_without_a_match(self, as_user, make_user):
        #It means what somebody did once they had your handle, which cannot
        #have happened to a stranger in the deck. The app hides the group
        #before a match; this is the backstop, because the two reads have to
        #agree or a stale page is the way around the rule.
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        assert report(as_user, alice, bob, category="harassment",
                      subcategory="sexual_assault").status_code == 409

    def test_but_it_is_allowed_once_there_is_one(
        self, as_user, make_user, swipe
    ):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        matched(as_user, swipe, alice, bob)
        assert report(as_user, alice, bob, category="harassment",
                      subcategory="sexual_assault").status_code == 201

    def test_details_cannot_be_used_as_storage(self, as_user, make_user):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        response = as_user(alice).post("/reports", json={
            "reported_user_id": bob.id,
            "category": "profile_content",
            "subcategory": "other",
            "details": "x" * 2001,
        })
        assert response.status_code == 422

    def test_the_reporter_comes_from_the_token(self, client, make_user):
        """Nobody can file a report as somebody else.

        THE BODY NAMES ONLY THE REPORTED USER. There is no reporter field to
        put a different id in - identity comes from the verified token and
        nowhere else, which is why `client` (whose override identifies a uid
        with no row) gets nowhere rather than filing an anonymous report.

        A genuinely absent token cannot be exercised here: conftest replaces
        the identity dependency, which is the seam the whole suite runs on.
        """
        bob = make_user(name="Bob")
        response = client.post("/reports", json={
            "reported_user_id": bob.id,
            "category": "profile_content",
            "subcategory": "other",
        })
        assert response.status_code == 404


class TestTheTaxonomyItself:
    def test_every_category_offers_a_way_out(self):
        #WITHOUT 'other' PEOPLE PICK THE NEAREST WRONG THING, which is worse
        #than a free-text report: it files an accusation under a heading that
        #was not meant.
        for category, subcategories in report_reasons.REASONS.items():
            assert "other" in subcategories, category

    def test_the_urgent_ones_are_real_reasons(self):
        #a typo here would silently stop the loudest reports being loud
        every = {sub for subs in report_reasons.REASONS.values() for sub in subs}
        assert report_reasons.URGENT <= every

    def test_the_after_match_category_exists(self):
        assert report_reasons.AFTER_MATCH_ONLY in report_reasons.REASONS

    def test_minors_are_their_own_category(self):
        #NEVER FOLDED INTO ANOTHER. There is no server-side age check in this
        #app at all, so this group is the only backstop there is - and one of
        #its codes carries legal reporting duties.
        assert "underage" in report_reasons.REASONS
        assert "minor_sexual_content" in report_reasons.REASONS["underage"]
        assert report_reasons.is_urgent("minor_sexual_content")
