"""The likes page, the matches list, and one profile seen by another user.

THE LIKES QUERY IS THE HARDEST THING IN THE SCHEMA, and the only one whose
answer depends on WHICH OF TWO SWIPES HAPPENED FIRST. It shows people who
liked you and whom you have not answered - plus people who liked you AFTER you
passed on them, which is the second chance that makes a stale pass forgivable.
Both halves are one SQL condition and neither is visible when it breaks.
"""

import datetime


def days_ago(n: int) -> datetime.datetime:
    return datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=n)


class TestTheLikesPage:
    def test_an_unanswered_like_is_shown(self, as_user, make_user, swipe):
        me, admirer = make_user(name="Me"), make_user(name="Admirer")
        swipe(admirer, me, "like", at=days_ago(1))

        assert [row["id"] for row in as_user(me).get("/likes").json()] == [admirer.id]

    def test_a_like_you_already_returned_is_not_shown(
        self, as_user, make_user, swipe
    ):
        #you matched; it belongs to the match flow now, not to this page
        me, admirer = make_user(name="Me"), make_user(name="Admirer")
        swipe(admirer, me, "like", at=days_ago(2))
        swipe(me, admirer, "like", at=days_ago(1))

        assert as_user(me).get("/likes").json() == []

    def test_a_like_you_passed_on_is_not_shown(self, as_user, make_user, swipe):
        me, admirer = make_user(name="Me"), make_user(name="Admirer")
        swipe(admirer, me, "like", at=days_ago(2))
        swipe(me, admirer, "pass", at=days_ago(1))

        assert as_user(me).get("/likes").json() == []

    def test_liking_you_again_after_a_pass_brings_them_back(
        self, as_user, make_user, swipe
    ):
        #THE SECOND CHANCE. You passed on them months ago in the deck; they
        #have since liked you. The pass was about a profile, the like is about
        #you, and the newer one wins.
        me, admirer = make_user(name="Me"), make_user(name="Admirer")
        swipe(me, admirer, "pass", at=days_ago(30))
        swipe(admirer, me, "like", at=days_ago(1))

        assert [row["id"] for row in as_user(me).get("/likes").json()] == [admirer.id]

    def test_a_super_like_shows_up_too(self, as_user, make_user, swipe):
        me, admirer = make_user(name="Me"), make_user(name="Admirer")
        swipe(admirer, me, "super_like", at=days_ago(1))

        assert [row["id"] for row in as_user(me).get("/likes").json()] == [admirer.id]

    def test_somebody_who_passed_on_you_is_not_a_like(
        self, as_user, make_user, swipe
    ):
        me, other = make_user(name="Me"), make_user(name="Other")
        swipe(other, me, "pass", at=days_ago(1))

        assert as_user(me).get("/likes").json() == []

    def test_a_liker_with_no_photo_still_appears(self, as_user, make_user, swipe):
        #the photo is an outer join: a half-finished account must not silently
        #vanish from a page that is about who liked you
        me = make_user(name="Me")
        admirer = make_user(name="Admirer", photos=0)
        swipe(admirer, me, "like", at=days_ago(1))

        assert [row["id"] for row in as_user(me).get("/likes").json()] == [admirer.id]

    def test_an_age_comes_back_with_each_liker(self, as_user, make_user, swipe):
        me = make_user(name="Me")
        admirer = make_user(name="Admirer", age=23)
        swipe(admirer, me, "like", at=days_ago(1))

        assert as_user(me).get("/likes").json()[0]["age"] == 23


class TestTheMatchesList:
    def complete(self, as_user, swipe, first_liker, completer):
        swipe(first_liker, completer, "like", at=days_ago(1))
        return as_user(completer).post(
            "/swipes", json={"target_id": first_liker.id, "action": "like"}
        ).json()["match_id"]

    def test_both_sides_see_the_same_match(self, as_user, make_user, swipe):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.complete(as_user, swipe, alice, bob)

        hers = as_user(alice).get("/matches").json()
        his = as_user(bob).get("/matches").json()

        assert [m["match_id"] for m in hers] == [match_id]
        assert [m["match_id"] for m in his] == [match_id]

    def test_each_side_sees_the_OTHER_person(self, as_user, make_user, swipe):
        #the row stores user_a and user_b; "the other one" is worked out per
        #caller, and getting it backwards would show someone themselves
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        self.complete(as_user, swipe, alice, bob)

        assert as_user(alice).get("/matches").json()[0]["other_user_name"] == "Bob"
        assert as_user(bob).get("/matches").json()[0]["other_user_name"] == "Alice"

    def test_no_matches_is_an_empty_list(self, as_user, make_user):
        assert as_user(make_user(name="Lonely")).get("/matches").json() == []

    def test_a_declined_match_disappears_from_both(self, as_user, make_user, swipe):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        match_id = self.complete(as_user, swipe, alice, bob)

        as_user(bob).post(f"/matches/{match_id}/decline")

        assert as_user(alice).get("/matches").json() == []
        assert as_user(bob).get("/matches").json() == []

    def test_no_instagram_handle_in_the_list(self, as_user, make_user, swipe):
        #the list is just "who you matched with"; the handle belongs to the
        #confirm endpoint and nowhere else
        alice = make_user(name="Alice", handle="alice_secret")
        bob = make_user(name="Bob")
        self.complete(as_user, swipe, alice, bob)

        assert "alice_secret" not in as_user(bob).get("/matches").text


class TestAnotherPersonsProfile:
    def test_it_comes_back(self, as_user, make_user):
        me, other = make_user(name="Me"), make_user(name="Other", photos=3)
        body = as_user(me).get(f"/users/{other.id}/profile").json()
        assert body["name"] == "Other"
        assert len(body["photos"]) == 3

    def test_a_missing_user_is_a_404(self, as_user, make_user):
        assert as_user(make_user(name="Me")).get("/users/999999/profile").status_code == 404

    def test_the_single_user_endpoint_works_for_the_likes_page(
        self, as_user, make_user
    ):
        me, other = make_user(name="Me"), make_user(name="Other")
        body = as_user(me).get(f"/single/user/{other.id}").json()
        assert body["name"] == "Other"

    def test_neither_leaks_private_fields(self, as_user, make_user):
        me = make_user(name="Me")
        other = make_user(name="Other", handle="their_secret")

        for path in (f"/users/{other.id}/profile", f"/single/user/{other.id}"):
            body = as_user(me).get(path).text
            assert "their_secret" not in body
            #who they want to see is their business, and the uid is a key
            assert "preferred_gender" not in body
            assert "firebase_uid" not in body


class TestTheFullStory:
    """A likes B, B likes back, and every way it can end.

    Written as one narrative because the rules only make sense in sequence -
    who has been told what, at each step, is the whole design.
    """

    def setup_match(self, as_user, make_user, swipe):
        a = make_user(name="A", handle="a_handle")
        b = make_user(name="B", handle="b_handle")
        #A likes B and hears nothing: B may never open the app again
        swipe(a, b, "like", at=days_ago(7))
        return a, b

    def test_a_likes_b_and_nothing_happens_yet(self, as_user, make_user, swipe):
        a, b = self.setup_match(as_user, make_user, swipe)
        assert as_user(a).get("/matches").json() == []
        assert as_user(a).get("/notifications").json() == []
        #B sees a like waiting
        assert [row["id"] for row in as_user(b).get("/likes").json()] == [a.id]

    def test_b_likes_back_and_only_b_is_asked(
        self, as_user, make_user, swipe, pushes
    ):
        a, b = self.setup_match(as_user, make_user, swipe)
        as_user(b).post("/swipes", json={"target_id": a.id, "action": "like"})

        #B completed it, so B answers now - and A is told NOTHING, because a
        #match B is about to decline is not news
        assert len(as_user(b).get("/notifications").json()) == 1
        assert as_user(a).get("/notifications").json() == []
        assert not [p for p in pushes if p[0] == a.firebase_uid]

    def test_b_rejects_and_a_never_learns(
        self, as_user, make_user, swipe, pushes, db
    ):
        from database import models

        a, b = self.setup_match(as_user, make_user, swipe)
        match_id = as_user(b).post(
            "/swipes", json={"target_id": a.id, "action": "like"}
        ).json()["match_id"]

        as_user(b).post(f"/matches/{match_id}/decline")

        assert db.query(models.Matches).count() == 0
        assert as_user(a).get("/notifications").json() == []
        assert not [p for p in pushes if p[0] == a.firebase_uid]
        #B's like became a pass, so A does not resurface on B's likes page
        assert as_user(b).get("/likes").json() == []

    def test_b_accepts_and_now_it_is_as_turn(
        self, as_user, make_user, swipe, pushes
    ):
        a, b = self.setup_match(as_user, make_user, swipe)
        match_id = as_user(b).post(
            "/swipes", json={"target_id": a.id, "action": "like"}
        ).json()["match_id"]

        answer = as_user(b).post(f"/matches/{match_id}/confirm").json()
        assert answer["revealed"] is False  # nothing shared yet

        #A is told, and it is actionable with the other side already confirmed
        rows = as_user(a).get("/notifications").json()
        assert len(rows) == 1
        assert rows[0]["kind"] == "match"
        assert rows[0]["actionable"] is True
        assert rows[0]["other_confirmed"] is True
        assert (a.firebase_uid, "match") in pushes

    def test_a_rejects_later_and_b_is_told(
        self, as_user, make_user, swipe, pushes, db
    ):
        from database import models

        a, b = self.setup_match(as_user, make_user, swipe)
        match_id = as_user(b).post(
            "/swipes", json={"target_id": a.id, "action": "like"}
        ).json()["match_id"]
        as_user(b).post(f"/matches/{match_id}/confirm")

        as_user(a).post(f"/matches/{match_id}/decline")

        #B said yes and was waiting, so B is owed an answer
        assert (b.firebase_uid, "match_declined") in pushes
        rows = as_user(b).get("/notifications").json()
        declined = [row for row in rows if row["kind"] == "match_declined"]
        assert len(declined) == 1
        assert declined[0]["match_id"] is None      # nothing left to open
        assert declined[0]["actionable"] is False
        assert db.query(models.Matches).count() == 0

    def test_a_accepts_and_both_get_a_handle(
        self, as_user, make_user, swipe, pushes
    ):
        a, b = self.setup_match(as_user, make_user, swipe)
        match_id = as_user(b).post(
            "/swipes", json={"target_id": a.id, "action": "like"}
        ).json()["match_id"]
        as_user(b).post(f"/matches/{match_id}/confirm")

        #A answers second, so A gets B's handle immediately
        answer = as_user(a).post(f"/matches/{match_id}/confirm").json()
        assert answer["revealed"] is True
        assert answer["instagram_handle"] == "b_handle"

        #and B, who was waiting, is told it completed
        assert (b.firebase_uid, "match_revealed") in pushes
        rows = as_user(b).get("/notifications").json()
        revealed = [row for row in rows if row["kind"] == "match_revealed"]
        assert len(revealed) == 1
        assert revealed[0]["actionable"] is True    # the way back to the handle

        #B collects it by confirming again - idempotent, so this is a read
        collected = as_user(b).post(f"/matches/{match_id}/confirm").json()
        assert collected["revealed"] is True
        assert collected["instagram_handle"] == "a_handle"

    def test_neither_can_undo_it_afterwards(self, as_user, make_user, swipe):
        a, b = self.setup_match(as_user, make_user, swipe)
        match_id = as_user(b).post(
            "/swipes", json={"target_id": a.id, "action": "like"}
        ).json()["match_id"]
        as_user(b).post(f"/matches/{match_id}/confirm")
        as_user(a).post(f"/matches/{match_id}/confirm")

        #a handle that has been read cannot be taken back, so there is nothing
        #honest left to delete
        assert as_user(a).post(f"/matches/{match_id}/decline").status_code == 409
        assert as_user(b).post(f"/matches/{match_id}/decline").status_code == 409


class TestTheBellItself:
    def test_newest_first(self, as_user, make_user, swipe, db):
        from database import models

        me = make_user(name="Me")
        for index, days in enumerate((5, 1, 3)):
            db.add(models.Notifications(
                user_id=me.id, kind="match_declined",
                created_at=days_ago(days),
            ))
        db.flush()

        rows = as_user(me).get("/notifications").json()
        stamps = [row["created_at"] for row in rows]
        assert stamps == sorted(stamps, reverse=True)

    def test_reading_one_sticks(self, as_user, make_user, swipe, db):
        from database import models

        me = make_user(name="Me")
        db.add(models.Notifications(user_id=me.id, kind="match_declined"))
        db.flush()

        note_id = as_user(me).get("/notifications").json()[0]["id"]
        assert as_user(me).post(f"/notifications/{note_id}/read").status_code == 200
        assert as_user(me).get("/notifications").json()[0]["read"] is True

    def test_reading_twice_does_not_move_the_timestamp(
        self, as_user, make_user, db
    ):
        from database import models

        me = make_user(name="Me")
        note = models.Notifications(user_id=me.id, kind="match_declined")
        db.add(note)
        db.flush()

        as_user(me).post(f"/notifications/{note.id}/read")
        db.refresh(note)
        first = note.read_at

        as_user(me).post(f"/notifications/{note.id}/read")
        db.refresh(note)
        assert note.read_at == first

    def test_you_only_see_your_own(self, as_user, make_user, db):
        from database import models

        me, other = make_user(name="Me"), make_user(name="Other")
        db.add(models.Notifications(user_id=other.id, kind="match_declined"))
        db.flush()

        assert as_user(me).get("/notifications").json() == []
