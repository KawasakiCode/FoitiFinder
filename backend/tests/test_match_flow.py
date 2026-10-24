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
