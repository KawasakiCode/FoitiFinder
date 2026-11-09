"""The list of matches you removed, and why it has to exist.

THE HOLE THIS CLOSES. Reporting somebody could only ever be started from
their profile, and the only way to reach the profile of someone you have
matched with is the matches page. So removing a match - the one thing a person
does when they want somebody out of their sight - also silently destroyed
their ability to report that person, at exactly the moment the handle is
already out and misuse becomes possible.

NOTHING HAD TO BE RETAINED to fix it. The row was never deleted: remove sets
one side's hidden_by_*_at and create_report reads the match without consulting
either column. The record was always there and the report always would have
landed. The only thing missing was a screen.
"""


def complete_match(as_user, swipe, alice, bob):
    """bob likes alice, alice likes back -> alice is the completer."""
    swipe(bob, alice, "like")
    response = as_user(alice).post(
        "/swipes", json={"target_id": bob.id, "action": "like"}
    )
    assert response.status_code == 200, response.text
    return response.json()["match_id"]


def revealed_match(as_user, swipe, alice, bob):
    match_id = complete_match(as_user, swipe, alice, bob)
    as_user(alice).post(f"/matches/{match_id}/confirm")
    as_user(bob).post(f"/matches/{match_id}/confirm")
    return match_id


class TestWhatTheListShows:
    def test_a_match_you_removed_is_on_it(self, as_user, make_user, swipe):
        alice = make_user(name="Alice", handle="alice_gr")
        bob = make_user(name="Bob", handle="bob_gr")
        match_id = revealed_match(as_user, swipe, alice, bob)
        as_user(bob).delete(f"/matches/{match_id}")

        body = as_user(bob).get("/matches/removed").json()
        assert [row["other_user_name"] for row in body] == ["Alice"]
        assert body[0]["other_user_id"] == alice.id

    def test_and_a_name_is_all_it_carries(self, as_user, make_user, swipe):
        #NO PHOTO AND NO AGE, deliberately. A removed match is somebody a user
        #chose to stop seeing, and giving the faces back is an un-remove that
        #nobody asked for. Pydantic drops anything extra, so this asserts the
        #response model rather than the handler.
        alice = make_user(name="Alice", handle="alice_gr")
        bob = make_user(name="Bob", handle="bob_gr")
        match_id = revealed_match(as_user, swipe, alice, bob)
        as_user(bob).delete(f"/matches/{match_id}")

        row = as_user(bob).get("/matches/removed").json()[0]
        assert set(row) == {"other_user_id", "other_user_name"}

    def test_a_match_you_still_have_is_not_on_it(
        self, as_user, make_user, swipe
    ):
        alice = make_user(name="Alice", handle="alice_gr")
        bob = make_user(name="Bob", handle="bob_gr")
        revealed_match(as_user, swipe, alice, bob)

        assert as_user(bob).get("/matches/removed").json() == []
        assert len(as_user(bob).get("/matches").json()) == 1

    def test_it_is_empty_for_somebody_who_has_removed_nothing(
        self, as_user, make_user
    ):
        assert as_user(make_user(name="Alice")).get(
            "/matches/removed").json() == []


class TestWhatItMustNotLeak:
    def test_their_removal_does_not_appear_on_your_list(
        self, as_user, make_user, swipe
    ):
        #THE DETECTOR THIS WOULD BE. Removal is per side precisely so that
        #neither person can tell the other walked away - a removed-matches
        #list that filled up when THEY removed you would hand that back, and
        #tell somebody holding your handle that you had reported them.
        alice = make_user(name="Alice", handle="alice_gr")
        bob = make_user(name="Bob", handle="bob_gr")
        match_id = revealed_match(as_user, swipe, alice, bob)
        as_user(bob).delete(f"/matches/{match_id}")

        assert as_user(alice).get("/matches/removed").json() == []

    def test_a_reported_stranger_is_not_on_it(
        self, as_user, make_user, swipe
    ):
        #create_report HIDES ITS REPORTER'S COPY of any match it finds, which
        #can be an unconfirmed one - and reporting from the deck leaves a
        #swipe but no match at all. Neither person has a handle of yours, so a
        #list whose premise is "these people have your Instagram" must not
        #name them. Both-confirmed is what keeps them out.
        alice = make_user(name="Alice", handle="alice_gr")
        bob = make_user(name="Bob", handle="bob_gr")
        complete_match(as_user, swipe, alice, bob)

        response = as_user(bob).post("/reports", json={
            "reported_user_id": alice.id,
            "category": "fake_profile",
            "subcategory": "not_the_person_in_the_photos",
        })
        assert response.status_code == 201, response.text
        assert as_user(bob).get("/matches/removed").json() == []

    def test_one_user_s_list_is_their_own(self, as_user, make_user, swipe):
        alice = make_user(name="Alice", handle="alice_gr")
        bob = make_user(name="Bob", handle="bob_gr")
        carol = make_user(name="Carol", handle="carol_gr")
        match_id = revealed_match(as_user, swipe, alice, bob)
        as_user(bob).delete(f"/matches/{match_id}")

        assert as_user(carol).get("/matches/removed").json() == []

    def test_a_deleted_account_drops_off_it(
        self, db, as_user, make_user, swipe
    ):
        #create_report 404s on a user who is gone, so a row for one would be a
        #button that cannot work. There is also nobody left to act against.
        from database import models

        alice = make_user(name="Alice", handle="alice_gr")
        bob = make_user(name="Bob", handle="bob_gr")
        match_id = revealed_match(as_user, swipe, alice, bob)
        as_user(bob).delete(f"/matches/{match_id}")

        db.query(models.User).filter(models.User.id == alice.id).delete()
        db.commit()

        assert as_user(bob).get("/matches/removed").json() == []


class TestThePointOfIt:
    def test_a_removed_match_can_still_be_reported(
        self, as_user, make_user, swipe
    ):
        #THE WHOLE REASON THE LIST EXISTS, and the one assertion here that is
        #about somebody's safety rather than about a query.
        alice = make_user(name="Alice", handle="alice_gr")
        bob = make_user(name="Bob", handle="bob_gr")
        match_id = revealed_match(as_user, swipe, alice, bob)
        as_user(bob).delete(f"/matches/{match_id}")

        target = as_user(bob).get("/matches/removed").json()[0]
        response = as_user(bob).post("/reports", json={
            "reported_user_id": target["other_user_id"],
            "category": "harassment",
            "subcategory": "shared_my_information",
        })
        assert response.status_code == 201, response.text

    def test_the_after_match_category_survives_the_removal(
        self, db, as_user, make_user, swipe
    ):
        #'harassment' is the one category create_report refuses without a
        #match, because it means what somebody did once they had your handle.
        #Removal must not take that away: it is the category the misuse of a
        #handle belongs to, and it becomes possible only after the match.
        from database import models

        alice = make_user(name="Alice", handle="alice_gr")
        bob = make_user(name="Bob", handle="bob_gr")
        match_id = revealed_match(as_user, swipe, alice, bob)
        as_user(bob).delete(f"/matches/{match_id}")

        as_user(bob).post("/reports", json={
            "reported_user_id": alice.id,
            "category": "harassment",
            "subcategory": "abusive_messages",
        })

        report = db.query(models.Reports).filter(
            models.Reports.reporter_id == bob.id).first()
        assert report is not None
        assert report.category == "harassment"

    def test_reporting_one_leaves_it_on_the_list(
        self, as_user, make_user, swipe
    ):
        #A SECOND INCIDENT DESERVES A SECOND REPORT. Filtering out anybody
        #already reported would mean the first report spends the only chance
        #to make another - and two complaints about the same pair is
        #information a reviewer wants, not noise.
        alice = make_user(name="Alice", handle="alice_gr")
        bob = make_user(name="Bob", handle="bob_gr")
        match_id = revealed_match(as_user, swipe, alice, bob)
        as_user(bob).delete(f"/matches/{match_id}")

        as_user(bob).post("/reports", json={
            "reported_user_id": alice.id,
            "category": "harassment",
            "subcategory": "abusive_messages",
        })

        body = as_user(bob).get("/matches/removed").json()
        assert [row["other_user_name"] for row in body] == ["Alice"]
