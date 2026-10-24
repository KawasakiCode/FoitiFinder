"""The match flow: the only irreversible thing in the app.

EVERY TEST HERE IS A BUG THAT ALREADY HAPPENED, or one step away from one. A
handle cannot be un-shared, a deleted match cannot be restored, and a
notification sent to the wrong person cannot be recalled - so these are the
rules that a refactor is least allowed to quietly break.
"""


def complete_match(as_user, swipe, alice, bob):
    """bob likes alice, alice likes back -> alice is the completer."""
    swipe(bob, alice, "like")
    response = as_user(alice).post(
        "/swipes", json={"target_id": bob.id, "action": "like"}
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["match_id"] is not None
    return body["match_id"]


class TestTheExchange:
    def test_a_mutual_like_exchanges_nothing_on_its_own(
        self, as_user, make_user, swipe
    ):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)

        #alice completed it and has not confirmed, so there is nothing to see
        answer = as_user(alice).post(f"/matches/{match_id}/confirm").json()
        assert answer["revealed"] is False
        assert answer["instagram_handle"] is None

    def test_the_handle_arrives_only_when_both_have_said_yes(
        self, as_user, make_user, swipe
    ):
        alice = make_user(name="Alice", handle="alice_gr")
        bob = make_user(name="Bob", handle="bob_gr")
        match_id = complete_match(as_user, swipe, alice, bob)

        as_user(alice).post(f"/matches/{match_id}/confirm")
        answer = as_user(bob).post(f"/matches/{match_id}/confirm").json()

        assert answer["revealed"] is True
        assert answer["instagram_handle"] == "alice_gr"

    def test_nothing_is_exchanged_when_one_side_has_no_handle(
        self, as_user, make_user, swipe
    ):
        #a row written before the handle was required. Handing over nothing is
        #worse than saying "not yet", and both confirmations stay on the row
        #so it completes by itself once the handle is filled in.
        alice = make_user(name="Alice", handle=None)
        bob = make_user(name="Bob", handle="bob_gr")
        match_id = complete_match(as_user, swipe, alice, bob)

        as_user(alice).post(f"/matches/{match_id}/confirm")
        answer = as_user(bob).post(f"/matches/{match_id}/confirm").json()

        assert answer["revealed"] is False
        assert answer["instagram_handle"] is None

    def test_confirming_twice_changes_nothing(self, as_user, make_user, swipe):
        #the client retries, so this has to be true
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)

        first = as_user(alice).post(f"/matches/{match_id}/confirm").json()
        second = as_user(alice).post(f"/matches/{match_id}/confirm").json()
        assert first == second


class TestDeclining:
    def test_a_decline_deletes_the_match_and_withdraws_the_like(
        self, as_user, make_user, swipe, db
    ):
        from database import models

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)

        assert as_user(alice).post(f"/matches/{match_id}/decline").status_code == 200

        assert db.query(models.Matches).filter_by(id=match_id).first() is None
        #THE LIKE BECOMES A PASS. Left as a like, alice would reappear in
        #bob's likes page as a fresh like, and the next re-swipe would rebuild
        #the match she just refused.
        withdrawn = db.query(models.UserSwipes).filter_by(
            user_id=alice.id, target_id=bob.id
        ).first()
        assert withdrawn.action == "pass"

    def test_a_completed_match_cannot_be_declined(self, as_user, make_user, swipe):
        #THIS IS THE BUG THAT DELETED A REAL MATCH. Both sides had confirmed
        #and the handle had been read; a stale notification reopened the page
        #and "Not interested" destroyed it.
        alice = make_user(name="Alice", handle="alice_gr")
        bob = make_user(name="Bob", handle="bob_gr")
        match_id = complete_match(as_user, swipe, alice, bob)

        as_user(alice).post(f"/matches/{match_id}/confirm")
        as_user(bob).post(f"/matches/{match_id}/confirm")

        refused = as_user(alice).post(f"/matches/{match_id}/decline")
        assert refused.status_code == 409

    def test_an_outsider_cannot_touch_someone_elses_match(
        self, as_user, make_user, swipe
    ):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        nosy = make_user(name="Nosy")
        match_id = complete_match(as_user, swipe, alice, bob)

        #the same 404 as a match that does not exist: a different answer would
        #let anyone count other people's matches by walking the ids
        assert as_user(nosy).post(f"/matches/{match_id}/confirm").status_code == 404
        assert as_user(nosy).post(f"/matches/{match_id}/decline").status_code == 404


class TestWhoGetsTold:
    def test_completing_a_match_tells_nobody_but_yourself(
        self, as_user, make_user, swipe, pushes
    ):
        #bob liked alice weeks ago and must not be told anything until alice
        #has actually agreed to go ahead
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        complete_match(as_user, swipe, alice, bob)

        assert (bob.firebase_uid, "match") not in pushes

    def test_confirming_tells_the_other_side_it_is_their_turn(
        self, as_user, make_user, swipe, pushes
    ):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)

        as_user(alice).post(f"/matches/{match_id}/confirm")
        assert (bob.firebase_uid, "match") in pushes

    def test_a_retried_confirm_does_not_tell_them_twice(
        self, as_user, make_user, swipe, pushes
    ):
        #A STORED ROW USED TO CARRY THIS, deduplicated on (user, kind, match).
        #With nothing stored, the guarantee has to come from the endpoint: it
        #pushes only when the confirmation actually changed something. A client
        #retrying a confirm whose answer it never saw is the normal case, not
        #a rare one.
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)

        as_user(alice).post(f"/matches/{match_id}/confirm")
        as_user(alice).post(f"/matches/{match_id}/confirm")

        told = [p for p in pushes
                if p[0] == bob.firebase_uid and p[1] == "match"]
        assert len(told) == 1

    def test_declining_first_tells_nobody(
        self, as_user, make_user, swipe, pushes
    ):
        #bob was never told a match existed, so "someone matched with you and
        #changed their mind" would be news of a rejection he could not have
        #seen coming
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)

        as_user(alice).post(f"/matches/{match_id}/decline")
        assert not [p for p in pushes if p[0] == bob.firebase_uid
                    and p[1] == "match_declined"]

    def test_declining_on_someone_who_was_waiting_tells_them(
        self, as_user, make_user, swipe, pushes
    ):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)

        as_user(alice).post(f"/matches/{match_id}/confirm")  # alice says yes
        as_user(bob).post(f"/matches/{match_id}/decline")    # bob says no

        #she is owed an answer: she said yes and was waiting for one
        assert (alice.firebase_uid, "match_declined") in pushes


class TestTheBell:
    """What the notifications table is for now that matches are not in it.

    MATCHES LEFT THE BELL. Every live match is on the matches page, which is
    always reachable and always current, so a stored notification about one
    could only ever be a staler copy of a screen the user can open. The rows
    that used to live here are what made 'match' mean two different things,
    gave the wrong title to whoever completed the match, and sat dead in the
    bell as soon as they had answered.

    THE TABLE AND ITS ENDPOINTS STAY, for the report flow: telling somebody
    what came of a report they filed, or that one was filed about them, is
    exactly a thing with no other home in the app. These tests keep the
    plumbing honest in the meantime.
    """

    def test_a_match_no_longer_writes_anything_to_the_bell(
        self, as_user, make_user, swipe, db
    ):
        from database import models

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)
        as_user(alice).post(f"/matches/{match_id}/confirm")
        as_user(bob).post(f"/matches/{match_id}/confirm")

        assert db.query(models.Notifications).count() == 0
        assert as_user(alice).get("/notifications").json() == []
        assert as_user(bob).get("/notifications").json() == []

    def test_a_decline_leaves_nothing_behind_either(
        self, as_user, make_user, swipe
    ):
        #she is still told, by push - but the match row is deleted and the
        #entry simply disappears from her matches page, which is the honest
        #representation of what happened
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)
        as_user(alice).post(f"/matches/{match_id}/confirm")
        as_user(bob).post(f"/matches/{match_id}/decline")

        assert as_user(alice).get("/notifications").json() == []

    def test_nobody_can_mark_someone_elses_notification_read(
        self, as_user, make_user, db
    ):
        #the endpoint outlives the match notifications, so its authorisation
        #has to be tested on a row written directly rather than by a match
        from database import models

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        row = models.Notifications(user_id=alice.id, kind="report_update")
        db.add(row)
        db.commit()

        assert as_user(bob).post(f"/notifications/{row.id}/read").status_code == 404
        assert as_user(alice).post(f"/notifications/{row.id}/read").status_code == 200


class TestWithdrawingFromAMatch:
    """hidden_at: the one thing the app can still take back.

    A revealed match cannot be declined - decline answers 409, because a handle
    that has been read cannot be unread. But the row goes on handing that
    handle back every time the other person opens their list, and THAT is the
    app's doing rather than the other person's. Hiding ends it.

    NOTHING WRITES THIS YET. The column and the filter are in place; the button
    that sets it is a separate decision. These tests pin the behaviour now so
    the endpoint has something to be correct against when it arrives.
    """

    def hidden_match(self, db, as_user, swipe, alice, bob, by):
        import datetime
        from database import models

        match_id = complete_match(as_user, swipe, alice, bob)
        match = db.query(models.Matches).filter_by(id=match_id).first()
        match.hidden_at = datetime.datetime.now(datetime.timezone.utc)
        match.hidden_by_user_id = by.id
        db.commit()
        return match_id

    def test_it_disappears_for_the_one_who_withdrew(
        self, db, as_user, make_user, swipe
    ):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        self.hidden_match(db, as_user, swipe, alice, bob, by=bob)
        assert as_user(bob).get("/matches").json() == []

    def test_it_disappears_for_the_other_one_too(
        self, db, as_user, make_user, swipe
    ):
        #SEVERANCE, NOT AN ARCHIVE BOX. The whole purpose is that your handle
        #stops being served to somebody you walked away from, so there is no
        #state where one of you can still open it.
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.hidden_match(db, as_user, swipe, alice, bob, by=bob)
        as_user(alice).post(f"/matches/{match_id}/confirm")

        assert as_user(alice).get("/matches").json() == []

    def test_the_row_survives_for_the_record(self, db, as_user, make_user, swipe):
        #hidden, NOT deleted: who confirmed, when, and in which order is the
        #only evidence that two people ever connected
        from database import models

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.hidden_match(db, as_user, swipe, alice, bob, by=bob)

        row = db.query(models.Matches).filter_by(id=match_id).first()
        assert row is not None
        assert row.hidden_by_user_id == bob.id
        assert row.hidden_at is not None


class TestReportingSomebody:
    """'reported' is a pass that cannot be undone."""

    def test_it_is_accepted_as_a_swipe(self, as_user, make_user):
        me, them = make_user(name="Me"), make_user(name="Them")
        response = as_user(me).post(
            "/swipes", json={"target_id": them.id, "action": "reported"}
        )
        assert response.status_code == 200
        assert response.json() == {"data": False, "match_id": None}

    def test_they_leave_the_deck(self, as_user, make_user):
        me = make_user(name="Me", preferred_gender="Everyone")
        them = make_user(name="Them")
        as_user(me).post("/swipes", json={"target_id": them.id, "action": "reported"})

        ids = [card["id"] for card in as_user(me).get("/users/feed").json()]
        assert them.id not in ids

    def test_a_later_like_cannot_undo_it(self, as_user, make_user, db):
        #THE QUEUE IS WHY. A like that failed to send is retried from disk
        #later, so it can arrive AFTER the report - and overwriting would put
        #somebody the user reported back in play.
        from database import models

        me, them = make_user(name="Me"), make_user(name="Them")
        as_user(me).post("/swipes", json={"target_id": them.id, "action": "reported"})
        as_user(me).post("/swipes", json={"target_id": them.id, "action": "like"})

        row = db.query(models.UserSwipes).filter_by(
            user_id=me.id, target_id=them.id
        ).first()
        assert row.action == "reported"

    def test_a_reported_person_cannot_become_a_match(
        self, as_user, make_user, swipe
    ):
        #they liked first, so a like from this side would normally complete a
        #match on the spot
        me, them = make_user(name="Me"), make_user(name="Them")
        swipe(them, me, "like")

        as_user(me).post("/swipes", json={"target_id": them.id, "action": "reported"})
        answer = as_user(me).post(
            "/swipes", json={"target_id": them.id, "action": "like"}
        ).json()

        assert answer["match_id"] is None
        assert as_user(me).get("/matches").json() == []

    def test_a_typo_is_still_refused(self, as_user, make_user):
        #the Literal is what makes a 422 here mean something
        me, them = make_user(name="Me"), make_user(name="Them")
        assert as_user(me).post(
            "/swipes", json={"target_id": them.id, "action": "report"}
        ).status_code == 422


class TestSuperLikesAreScarce:
    """Two a week, and the limit is what makes the badge mean anything."""

    def test_the_first_two_go_through(self, as_user, make_user):
        me = make_user(name="Me")
        for name in ("One", "Two"):
            them = make_user(name=name)
            assert as_user(me).post(
                "/swipes", json={"target_id": them.id, "action": "super_like"}
            ).status_code == 200

    def test_the_third_is_refused(self, as_user, make_user):
        me = make_user(name="Me")
        for name in ("One", "Two"):
            as_user(me).post("/swipes", json={
                "target_id": make_user(name=name).id, "action": "super_like"})

        third = make_user(name="Three")
        response = as_user(me).post(
            "/swipes", json={"target_id": third.id, "action": "super_like"}
        )
        #409 AND NOT 429: a 429 is retryable, and SwipeQueue would bring this
        #back off disk days later to land on somebody long since swiped past
        assert response.status_code == 409

    def test_a_plain_like_is_never_limited(self, as_user, make_user):
        me = make_user(name="Me")
        for name in ("One", "Two"):
            as_user(me).post("/swipes", json={
                "target_id": make_user(name=name).id, "action": "super_like"})

        them = make_user(name="Three")
        assert as_user(me).post(
            "/swipes", json={"target_id": them.id, "action": "like"}
        ).status_code == 200

    def test_resending_the_same_one_does_not_spend_a_second(
        self, as_user, make_user
    ):
        #the queue flushing something the server already has, or a double tap
        me = make_user(name="Me")
        them = make_user(name="Them")
        body = {"target_id": them.id, "action": "super_like"}
        assert as_user(me).post("/swipes", json=body).status_code == 200
        assert as_user(me).post("/swipes", json=body).status_code == 200

        left = as_user(me).get("/swipes/super-likes").json()
        assert left["left"] == 1

    def test_one_older_than_the_window_does_not_count(
        self, as_user, make_user, swipe
    ):
        import datetime

        long_ago = (datetime.datetime.now(datetime.timezone.utc)
                    - datetime.timedelta(days=8))
        me = make_user(name="Me")
        swipe(me, make_user(name="Old"), "super_like", at=long_ago)
        assert as_user(me).get("/swipes/super-likes").json()["left"] == 2

    def test_the_count_is_what_the_app_asks_before_spending_one(
        self, as_user, make_user
    ):
        me = make_user(name="Me")
        assert as_user(me).get("/swipes/super-likes").json() == {
            "left": 2, "per_window": 2, "window_days": 7,
        }
