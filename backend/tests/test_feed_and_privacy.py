"""Who the deck offers, and what another user is allowed to see.

THE FEED'S FILTERS ARE INVISIBLE WHEN THEY BREAK. A missing exclusion does not
raise anything - it just puts somebody in the deck who should not be there, and
the only symptom is a user wondering why they keep seeing the same person.

THE PRIVACY TESTS EXIST BECAUSE A FIELD ADDED TO A MODEL APPEARS EVERYWHERE
BY DEFAULT. instagram_handle is handed over by exactly one endpoint, and the
way that stays true is a test that fails when a payload starts carrying it.
"""


def feed_ids(as_user, viewer):
    response = as_user(viewer).get("/users/feed")
    assert response.status_code == 200, response.text
    return {card["id"] for card in response.json()}


class TestWhoIsInTheDeck:
    def test_a_plain_candidate_is_offered(self, as_user, make_user):
        viewer = make_user(name="Viewer", gender="Male", preferred_gender="Women")
        her = make_user(name="Her", gender="Female")
        assert her.id in feed_ids(as_user, viewer)

    def test_you_are_not_in_your_own_deck(self, as_user, make_user):
        viewer = make_user(name="Viewer")
        assert viewer.id not in feed_ids(as_user, viewer)

    def test_anyone_already_swiped_is_gone(self, as_user, make_user, swipe):
        viewer = make_user(name="Viewer", preferred_gender="Everyone")
        passed = make_user(name="Passed")
        swipe(viewer, passed, "pass")
        assert passed.id not in feed_ids(as_user, viewer)

    def test_someone_who_liked_you_is_offered_without_saying_so(
        self, as_user, make_user, swipe
    ):
        #THEY USED TO BE HELD BACK for a likes page, so that a flick could not
        #pass on a guaranteed match. That page is gone, and with it the premise:
        #nobody was ever going to be told, so a pass here is just a pass.
        #
        #It is also the only way the deck can pay out at all. Every match used
        #to arrive on a separate page, which left the app's main screen unable
        #to produce the thing the app is for.
        viewer = make_user(name="Viewer", preferred_gender="Everyone")
        admirer = make_user(name="Admirer")
        swipe(admirer, viewer, "like")
        assert admirer.id in feed_ids(as_user, viewer)

    def test_the_deck_never_reveals_a_plain_like(
        self, as_user, make_user, swipe
    ):
        #THE HIDING IS THE PRODUCT. A card that announced "they like you" would
        #turn every such swipe into a formality, and it is the thing a "see who
        #liked you" tier would be sold on later. /likes still knows; the deck
        #must not say.
        viewer = make_user(name="Viewer", preferred_gender="Everyone")
        admirer = make_user(name="Admirer")
        swipe(admirer, viewer, "like")

        card = next(c for c in as_user(viewer).get("/users/feed").json()
                    if c["id"] == admirer.id)
        assert card["super_liked_you"] is False

    def test_a_super_like_is_the_one_thing_the_deck_does_say(
        self, as_user, make_user, swipe
    ):
        #THE EXCEPTION IS OPT-IN BY THE SENDER. Telling you before you decide
        #is the whole of what a super like does; they spent one of two a week
        #to waive their own privacy, which is not the same as the deck leaking
        #somebody's interest.
        viewer = make_user(name="Viewer", preferred_gender="Everyone")
        admirer = make_user(name="Admirer")
        swipe(admirer, viewer, "super_like")

        card = next(c for c in as_user(viewer).get("/users/feed").json()
                    if c["id"] == admirer.id)
        assert card["super_liked_you"] is True

    def test_it_says_nothing_about_people_who_did_not(
        self, as_user, make_user, swipe
    ):
        viewer = make_user(name="Viewer", preferred_gender="Everyone")
        stranger = make_user(name="Stranger")
        passer = make_user(name="Passer")
        swipe(passer, viewer, "pass")

        cards = {c["id"]: c for c in as_user(viewer).get("/users/feed").json()}
        assert cards[stranger.id]["super_liked_you"] is False
        assert cards[passer.id]["super_liked_you"] is False

    def test_someone_who_passed_on_you_is_still_offered(
        self, as_user, make_user, swipe
    ):
        #deliberate: hiding them would make an empty deck mean "everyone said
        #no", which is a different decision and not this one
        viewer = make_user(name="Viewer", preferred_gender="Everyone")
        rejector = make_user(name="Rejector")
        swipe(rejector, viewer, "pass")
        assert rejector.id in feed_ids(as_user, viewer)

    def test_the_age_range_is_respected(self, as_user, make_user):
        viewer = make_user(
            name="Viewer", preferred_gender="Everyone",
            min_age_range=20, max_age_range=24,
        )
        too_young = make_user(name="Young", age=18)
        just_right = make_user(name="Right", age=22)
        too_old = make_user(name="Old", age=40)

        offered = feed_ids(as_user, viewer)
        assert just_right.id in offered
        assert too_young.id not in offered
        assert too_old.id not in offered

    def test_the_gender_preference_is_respected(self, as_user, make_user):
        viewer = make_user(name="Viewer", gender="Male", preferred_gender="Women")
        woman = make_user(name="Woman", gender="Female")
        man = make_user(name="Man", gender="Male")

        offered = feed_ids(as_user, viewer)
        assert woman.id in offered
        assert man.id not in offered


class TestTheLikesPage:
    def test_it_shows_someone_who_liked_you(self, as_user, make_user, swipe):
        viewer = make_user(name="Viewer")
        admirer = make_user(name="Admirer")
        swipe(admirer, viewer, "like")

        likes = as_user(viewer).get("/likes").json()
        assert [like["id"] for like in likes] == [admirer.id]

    def test_a_pass_is_not_a_like(self, as_user, make_user, swipe):
        viewer = make_user(name="Viewer")
        indifferent = make_user(name="Indifferent")
        swipe(indifferent, viewer, "pass")

        assert as_user(viewer).get("/likes").json() == []


class TestWhatOthersCanSee:
    def test_a_profile_never_carries_an_instagram_handle(
        self, as_user, make_user
    ):
        viewer = make_user(name="Viewer")
        other = make_user(name="Other", handle="secret_handle")

        body = as_user(viewer).get(f"/users/{other.id}/profile").text
        assert "secret_handle" not in body
        assert "instagram" not in body.lower()

    def test_a_feed_card_never_carries_one_either(self, as_user, make_user):
        viewer = make_user(name="Viewer", preferred_gender="Everyone")
        make_user(name="Other", handle="secret_handle")

        assert "secret_handle" not in as_user(viewer).get("/users/feed").text

    def test_the_likes_page_does_not_leak_one(self, as_user, make_user, swipe):
        viewer = make_user(name="Viewer")
        admirer = make_user(name="Admirer", handle="secret_handle")
        swipe(admirer, viewer, "like")

        assert "secret_handle" not in as_user(viewer).get("/likes").text

    def test_your_own_handle_comes_back_to_you(self, as_user, make_user):
        #it has to: the match page names it in the confirm dialog
        me = make_user(name="Me", handle="my_handle")
        assert as_user(me).get("/users/me").json()["instagram_handle"] == "my_handle"


class TestAConsideredNo:
    """not_interested: the same outcome as a pass, kept as a different fact.

    A PASS IS A THUMB MOVING AT SPEED over a card. This is somebody who opened
    the whole profile, opened a menu inside it and chose the option - the
    strongest negative signal the app can collect, and the only one that says
    the person thought about it.

    STORED NOW BECAUSE IT CANNOT BE STORED LATER. There is no way to look at a
    pile of passes afterwards and work out which were deliberate, so ranking
    either has this from the beginning or never has it at all - the same
    argument as the minimum-build check shipping before anything needed it.
    """

    def test_it_is_accepted(self, as_user, make_user):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        response = as_user(alice).post(
            "/swipes", json={"target_id": bob.id, "action": "not_interested"})
        assert response.status_code == 200

    def test_it_is_stored_as_itself(self, db, as_user, make_user):
        #NOT FOLDED INTO pass, which is the whole point of the value existing
        from database import models

        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        as_user(alice).post(
            "/swipes", json={"target_id": bob.id, "action": "not_interested"})

        swipe = db.query(models.UserSwipes).filter_by(
            user_id=alice.id, target_id=bob.id).one()
        assert swipe.action == "not_interested"

    def test_they_leave_the_deck(self, as_user, make_user):
        #the deck excludes on target_id whatever the action was, so a new
        #negative value needs no change there - this is what proves it
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        as_user(alice).post(
            "/swipes", json={"target_id": bob.id, "action": "not_interested"})

        assert bob.id not in [card["id"] for card in
                              as_user(alice).get("/users/feed").json()]

    def test_it_cannot_make_a_match(self, as_user, make_user, swipe):
        #every match check asks which actions count as INTEREST rather than
        #which do not, so this must not complete one even against a like
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        swipe(bob, alice, "like")

        body = as_user(alice).post(
            "/swipes",
            json={"target_id": bob.id, "action": "not_interested"}).json()
        assert body["match_id"] is None

    def test_nor_show_up_as_a_like(self, as_user, make_user):
        alice, bob = make_user(name="Alice"), make_user(name="Bob")
        as_user(bob).post(
            "/swipes", json={"target_id": alice.id, "action": "not_interested"})

        assert as_user(alice).get("/likes").json() == []


class TestTheSwipeItself:
    def test_a_nonsense_action_is_refused(self, as_user, make_user):
        #an unconstrained string used to be stored happily and then behave
        #like nothing at all: not a like, so no match and no likes-page entry,
        #but still a swipe, so that person was gone from the deck forever
        viewer, other = make_user(name="Viewer"), make_user(name="Other")
        response = as_user(viewer).post(
            "/swipes", json={"target_id": other.id, "action": "liek"}
        )
        assert response.status_code == 422

    def test_re_swiping_the_same_way_is_harmless(
        self, as_user, make_user, db
    ):
        #the retry queue depends on this being true
        from database import models

        viewer, other = make_user(name="Viewer"), make_user(name="Other")
        for _ in range(3):
            assert as_user(viewer).post(
                "/swipes", json={"target_id": other.id, "action": "like"}
            ).status_code == 200

        rows = db.query(models.UserSwipes).filter_by(
            user_id=viewer.id, target_id=other.id
        ).all()
        assert len(rows) == 1

    def test_changing_your_mind_overwrites_the_swipe(
        self, as_user, make_user, db
    ):
        from database import models

        viewer, other = make_user(name="Viewer"), make_user(name="Other")
        as_user(viewer).post("/swipes", json={"target_id": other.id, "action": "pass"})
        as_user(viewer).post("/swipes", json={"target_id": other.id, "action": "like"})

        rows = db.query(models.UserSwipes).filter_by(
            user_id=viewer.id, target_id=other.id
        ).all()
        assert len(rows) == 1
        assert rows[0].action == "like"
