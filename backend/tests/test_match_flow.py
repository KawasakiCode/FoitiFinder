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


class TestRemovingAMatchFromYourOwnList:
    """DELETE /matches/{id}: the only exit a finished match has.

    decline refuses once both sides have confirmed - a handle that has been
    read cannot be unread - which left the finished state permanent for as
    long as the account existed. These two endpoints now divide every match
    between them: anything unanswered is declined, anything completed is
    removed.

    ONE SIDE AT A TIME, which is the whole point and used to be the opposite.
    Removal was a single hidden_at meaning "gone for both". Per side, because
    a mutual removal is something the other person can NOTICE - and once
    reporting somebody also removes the match, noticing it is how a person
    holding your Instagram handle learns that you reported them.
    """

    def revealed_match(self, as_user, swipe, alice, bob):
        match_id = complete_match(as_user, swipe, alice, bob)
        as_user(alice).post(f"/matches/{match_id}/confirm")
        as_user(bob).post(f"/matches/{match_id}/confirm")
        return match_id

    def test_it_goes_from_the_list_of_whoever_removed_it(
        self, as_user, make_user, swipe
    ):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.revealed_match(as_user, swipe, alice, bob)

        assert as_user(bob).delete(f"/matches/{match_id}").status_code == 200
        assert as_user(bob).get("/matches").json() == []

    def test_and_stays_on_the_other_one_s(self, as_user, make_user, swipe):
        #THE REVERSAL. This used to assert the opposite, on the grounds that a
        #row in their list keeps handing them your Instagram - which takes
        #nothing back, because they have already read it.
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.revealed_match(as_user, swipe, alice, bob)
        as_user(bob).delete(f"/matches/{match_id}")

        body = as_user(alice).get("/matches").json()
        assert len(body) == 1
        assert body[0]["revealed"] is True

    def test_the_other_side_cannot_tell(self, as_user, make_user, swipe):
        #NOT DETECTABLE, which is the property the whole shape exists for. A
        #409 on confirm here would be exactly the detector - and it gives
        #nothing away anyway, since confirm on a revealed match only re-reads
        #a handle they already hold.
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.revealed_match(as_user, swipe, alice, bob)
        as_user(bob).delete(f"/matches/{match_id}")

        response = as_user(alice).post(f"/matches/{match_id}/confirm")
        assert response.status_code == 200
        assert response.json()["revealed"] is True

    def test_nobody_is_told(self, as_user, make_user, swipe, pushes):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.revealed_match(as_user, swipe, alice, bob)

        pushes.clear()
        as_user(bob).delete(f"/matches/{match_id}")
        assert pushes == []

    def test_both_can_remove_it_independently(
        self, db, as_user, make_user, swipe
    ):
        #THE BUG A SHARED COLUMN HAD. With one hidden_by_user_id the second
        #removal overwrote the first, handing the match back to whoever
        #removed it first. Each side writing only its own column cannot.
        from database import models

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.revealed_match(as_user, swipe, alice, bob)

        as_user(bob).delete(f"/matches/{match_id}")
        as_user(alice).delete(f"/matches/{match_id}")

        assert as_user(bob).get("/matches").json() == []
        assert as_user(alice).get("/matches").json() == []

        row = db.query(models.Matches).filter_by(id=match_id).first()
        assert row.hidden_by_a_at is not None
        assert row.hidden_by_b_at is not None

    def test_the_row_survives_for_the_record(
        self, db, as_user, make_user, swipe
    ):
        #hidden, NOT deleted: who confirmed, when, and in which order is the
        #only evidence that two people ever connected - and now who walked
        #away, and when, for each of them separately
        from database import models

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.revealed_match(as_user, swipe, alice, bob)
        as_user(bob).delete(f"/matches/{match_id}")

        row = db.query(models.Matches).filter_by(id=match_id).first()
        assert row is not None
        assert row.a_confirmed_at is not None
        assert row.b_confirmed_at is not None
        #alice completed the match, so bob is user_b
        assert row.hidden_by_b_at is not None
        assert row.hidden_by_a_at is None

    def test_removing_twice_is_not_an_error(self, as_user, make_user, swipe):
        #a retry after a dropped connection is not a different decision, and
        #the row is gone from their list either way
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.revealed_match(as_user, swipe, alice, bob)

        assert as_user(bob).delete(f"/matches/{match_id}").status_code == 200
        assert as_user(bob).delete(f"/matches/{match_id}").status_code == 200

    def test_an_unanswered_match_cannot_be_removed(
        self, as_user, make_user, swipe
    ):
        #DECLINE IS THAT ONE'S EXIT, and it tells whoever was waiting. Letting
        #this through instead would be a silent way to leave somebody waiting
        #on an answer that never comes.
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)

        assert as_user(alice).delete(f"/matches/{match_id}").status_code == 409

    def test_nor_one_that_is_only_half_answered(
        self, as_user, make_user, swipe
    ):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)
        as_user(alice).post(f"/matches/{match_id}/confirm")

        assert as_user(alice).delete(f"/matches/{match_id}").status_code == 409

    def test_a_stranger_cannot_remove_somebody_else_s_match(
        self, as_user, make_user, swipe
    ):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        carol = make_user(name="Carol")
        match_id = self.revealed_match(as_user, swipe, alice, bob)

        assert as_user(carol).delete(f"/matches/{match_id}").status_code == 404

    def test_a_match_you_removed_cannot_be_answered_again(
        self, as_user, make_user, swipe
    ):
        #YOUR OWN removal does stop you, unlike theirs: there is nothing of
        #yours left to answer, and only a stale page could still ask.
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.revealed_match(as_user, swipe, alice, bob)
        as_user(bob).delete(f"/matches/{match_id}")

        assert as_user(bob).post(
            f"/matches/{match_id}/confirm"
        ).status_code == 409



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


class TestAnUnansweredMatchRunsOut:
    """match_expiry: three days from whenever it became somebody's turn.

    WHY THIS EXISTS AT ALL. The match page lets the person who completed a
    match back out of answering it, which leaves a match only they can see -
    get_matches hides it from the other side until the completer confirms. So
    without a deadline, a mutual like becomes a row nobody is told about and
    nothing ever clears.

    NOTHING IS WRITTEN TO EXPIRE A MATCH. The state is derived from created_at
    and a_confirmed_at, so these tests move those timestamps rather than
    calling an endpoint - there is no endpoint, and that is the design.
    """

    def age(self, db, match_id, *, created=None, confirmed=None):
        """Backdate a match, as though it had been sitting there."""
        import datetime

        from database import models

        now = datetime.datetime.now(datetime.timezone.utc)
        match = db.query(models.Matches).filter_by(id=match_id).first()
        if created is not None:
            match.created_at = now - created
        if confirmed is not None:
            match.a_confirmed_at = now - confirmed
        db.commit()
        return match

    def only_match(self, response):
        body = response.json()
        assert len(body) == 1, body
        return body[0]

    def test_a_fresh_unanswered_match_is_not_expired(
        self, as_user, make_user, swipe
    ):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        complete_match(as_user, swipe, alice, bob)

        row = self.only_match(as_user(alice).get("/matches"))
        assert row["expired"] is False
        assert row["expires_at"] is not None

    def test_nobody_answered_for_three_days(
        self, db, as_user, make_user, swipe
    ):
        import datetime

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)
        self.age(db, match_id, created=datetime.timedelta(days=3, hours=1))

        #STILL THERE, SAYING SO. Alice backed out of answering and this is how
        #she learns it lapsed, rather than finding it missing.
        row = self.only_match(as_user(alice).get("/matches"))
        assert row["expired"] is True

    def test_past_the_grace_window_it_is_gone(
        self, db, as_user, make_user, swipe
    ):
        import datetime

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)
        self.age(db, match_id, created=datetime.timedelta(days=6))

        assert as_user(alice).get("/matches").json() == []

    def test_the_clock_restarts_when_somebody_commits(
        self, db, as_user, make_user, swipe
    ):
        """THE DISTINCTION THE WHOLE RULE TURNS ON.

        A match can sit unanswered for days before somebody confirms, and that
        wait belongs to the person who had not answered yet - not to the one
        now waiting on a reply. So the clock runs from a_confirmed_at, and an
        old match that was confirmed a minute ago has three fresh days.
        """
        import datetime

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)
        self.age(db, match_id, created=datetime.timedelta(days=2, hours=20))

        as_user(alice).post(f"/matches/{match_id}/confirm")

        row = self.only_match(as_user(alice).get("/matches"))
        assert row["expired"] is False

    def test_waiting_on_them_expires_three_days_after_the_commit(
        self, db, as_user, make_user, swipe
    ):
        import datetime

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)
        as_user(alice).post(f"/matches/{match_id}/confirm")
        self.age(db, match_id, confirmed=datetime.timedelta(days=3, hours=1))

        row = self.only_match(as_user(alice).get("/matches"))
        assert row["expired"] is True

    def test_a_finished_exchange_never_expires(
        self, db, as_user, make_user, swipe
    ):
        #BOTH HANDLES ARE OUT, so there is nothing a deadline could take back -
        #it would only destroy the record of a connection that did happen.
        import datetime

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = complete_match(as_user, swipe, alice, bob)
        as_user(alice).post(f"/matches/{match_id}/confirm")
        as_user(bob).post(f"/matches/{match_id}/confirm")
        self.age(db, match_id, created=datetime.timedelta(days=400),
                 confirmed=datetime.timedelta(days=400))

        row = self.only_match(as_user(alice).get("/matches"))
        assert row["expired"] is False
        assert row["revealed"] is True
        #nothing to count down to
        assert row["expires_at"] is None


class TestAnExpiredMatchCannotBeActedOn:
    """The list and the two endpoints have to agree about what is over.

    A CLIENT HOLDING A STALE PAGE is the way around any rule the list enforces
    on its own. Confirming hands over an Instagram handle and declining tells
    the other side something - neither belongs to a match that already lapsed.
    """

    def expired_match(self, db, as_user, swipe, alice, bob):
        import datetime

        from database import models

        match_id = complete_match(as_user, swipe, alice, bob)
        match = db.query(models.Matches).filter_by(id=match_id).first()
        match.created_at = (datetime.datetime.now(datetime.timezone.utc)
                            - datetime.timedelta(days=3, hours=1))
        db.commit()
        return match_id

    def test_confirming_is_refused(self, db, as_user, make_user, swipe):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.expired_match(db, as_user, swipe, alice, bob)

        response = as_user(alice).post(f"/matches/{match_id}/confirm")
        assert response.status_code == 409

    def test_no_handle_escapes_through_it(self, db, as_user, make_user, swipe):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.expired_match(db, as_user, swipe, alice, bob)

        response = as_user(alice).post(f"/matches/{match_id}/confirm")
        assert "instagram" not in response.text.lower()

    def test_declining_is_refused(self, db, as_user, make_user, swipe):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.expired_match(db, as_user, swipe, alice, bob)

        response = as_user(alice).post(f"/matches/{match_id}/decline")
        assert response.status_code == 409

    #A MATCH THE OTHER SIDE REMOVED IS DELIBERATELY NOT REFUSED. There was a
    #test here asserting the opposite, written when removal still meant "gone
    #for both" - a 409 then protected a handle the withdrawing side had
    #already said yes to. Per-side removal reverses it: refusing would tell me
    #they walked away, and confirm on a revealed match only re-reads a handle
    #I already hold. See TestRemovingAMatchFromYourOwnList.

class TestAnUnansweredMatchBelongsToOnePerson:
    """Who can SEE an undecided match, and who can therefore act on it.

    THE RULE: until the person who completed the match answers it, it is
    theirs alone. The other side has never been told it exists, which is what
    makes backing out of the match page harmless - there is nobody to
    disappoint, and nothing of theirs changes if it quietly runs out.

    IT HAS TO BE ENFORCED TWICE. get_matches hides the row, and
    _match_for_participant refuses to act on it - because match ids are
    sequential integers, so a list that merely omits a match is not a rule,
    it is a suggestion. Each of these is the second half of that.
    """

    def undecided(self, as_user, swipe, alice, bob):
        """bob liked alice first, alice swiped back -> alice is user_a."""
        swipe(bob, alice, "like")
        response = as_user(alice).post(
            "/swipes", json={"target_id": bob.id, "action": "like"}
        )
        return response.json()["match_id"]

    def test_the_one_who_made_it_sees_it(self, as_user, make_user, swipe):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        self.undecided(as_user, swipe, alice, bob)

        body = as_user(alice).get("/matches").json()
        assert len(body) == 1
        assert body[0]["other_user_name"] == "Bob"
        assert body[0]["i_confirmed"] is False

    def test_the_other_one_does_not(self, as_user, make_user, swipe):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        self.undecided(as_user, swipe, alice, bob)

        assert as_user(bob).get("/matches").json() == []

    def test_nor_can_they_confirm_it_by_guessing_the_id(
        self, as_user, make_user, swipe
    ):
        #THE SAME 404 A STRANGER GETS. Anything else would confirm that a
        #match they were never shown exists.
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.undecided(as_user, swipe, alice, bob)

        response = as_user(bob).post(f"/matches/{match_id}/confirm")
        assert response.status_code == 404

    def test_nor_decline_it(self, as_user, make_user, swipe):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.undecided(as_user, swipe, alice, bob)

        response = as_user(bob).post(f"/matches/{match_id}/decline")
        assert response.status_code == 404

    def test_a_refused_confirm_writes_nothing(
        self, db, as_user, make_user, swipe
    ):
        #b_confirmed_at IS WHAT MAKES A MATCH IMMORTAL - a finished exchange
        #must never expire - so a confirm that slipped through here would also
        #have produced a match that outlived its own deadline forever.
        from database import models

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.undecided(as_user, swipe, alice, bob)
        as_user(bob).post(f"/matches/{match_id}/confirm")

        row = db.query(models.Matches).filter_by(id=match_id).first()
        assert row.b_confirmed_at is None

    def test_and_tells_the_other_side_nothing(
        self, as_user, make_user, swipe, pushes
    ):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.undecided(as_user, swipe, alice, bob)

        pushes.clear()
        as_user(bob).post(f"/matches/{match_id}/confirm")
        assert pushes == []

    def test_it_becomes_theirs_the_moment_the_maker_answers(
        self, as_user, make_user, swipe
    ):
        #and this is the whole flow working: alice answers, and only then does
        #bob have a match to see and something to answer
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.undecided(as_user, swipe, alice, bob)
        as_user(alice).post(f"/matches/{match_id}/confirm")

        body = as_user(bob).get("/matches").json()
        assert len(body) == 1
        assert body[0]["they_confirmed"] is True
        assert as_user(bob).post(
            f"/matches/{match_id}/confirm"
        ).status_code == 200

    def test_the_maker_can_still_answer_their_own(
        self, as_user, make_user, swipe
    ):
        #the rule is about user_b only; it must not lock the owner out of the
        #one match they are supposed to be deciding on
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.undecided(as_user, swipe, alice, bob)

        assert as_user(alice).post(
            f"/matches/{match_id}/confirm"
        ).status_code == 200

    def test_or_decline_it(self, as_user, make_user, swipe):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.undecided(as_user, swipe, alice, bob)

        assert as_user(alice).post(
            f"/matches/{match_id}/decline"
        ).status_code == 200
