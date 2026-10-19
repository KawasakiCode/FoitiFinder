"""Signing up, reading yourself, editing yourself, and leaving.

THE SIGNUP CHECK IS THE ONLY THING MAKING THIS A STUDENT APP. It reads the
email out of the VERIFIED token, never out of the body, which is what stops
anyone registering with a university address they do not own. A test here is
worth more than it looks: the rule is three lines and deleting it would break
nothing visible.
"""

import datetime


class TestSigningUp:
    def test_a_university_email_gets_an_account(self, as_signup):
        response = as_signup("uid-new", "someone@uom.edu.gr").post(
            "/users/", json={"name": "Someone"}
        )
        assert response.status_code == 200, response.text
        assert response.json()["name"] == "Someone"

    def test_the_university_is_derived_from_the_email(self, as_signup):
        response = as_signup("uid-new", "iis24111@uom.edu.gr").post(
            "/users/", json={"name": "Someone"}
        )
        #not sent by the client, and the app cannot change it afterwards
        assert response.json()["university"] == "University of Macedonia"

    def test_a_client_cannot_choose_its_own_university(self, as_signup):
        response = as_signup("uid-new", "someone@uom.edu.gr").post(
            "/users/", json={"name": "Someone", "university": "Harvard"}
        )
        assert response.json()["university"] == "University of Macedonia"

    def test_a_gmail_address_is_refused(self, as_signup):
        response = as_signup("uid-new", "someone@gmail.com").post(
            "/users/", json={"name": "Someone"}
        )
        assert response.status_code == 403

    def test_no_email_in_the_token_is_refused(self, as_signup):
        #the Admin SDK lookup is the fallback, and in a test it cannot
        #succeed - which is the right outcome: no provable email, no account
        response = as_signup("uid-new", None).post(
            "/users/", json={"name": "Someone"}
        )
        assert response.status_code == 403

    def test_a_new_account_starts_with_settings(self, as_signup, db):
        from database import models

        as_signup("uid-new", "someone@uom.edu.gr").post(
            "/users/", json={"name": "Someone"}
        )
        user = db.query(models.User).filter_by(firebase_uid="uid-new").first()
        #the app reads settings on every launch; a missing row would 404 it
        assert user.settings is not None


class TestReadingYourself:
    def test_your_own_row_comes_back(self, as_user, make_user):
        me = make_user(name="Me", handle="my_handle")
        body = as_user(me).get("/users/me").json()
        assert body["name"] == "Me"
        assert body["instagram_handle"] == "my_handle"

    def test_a_token_with_no_row_is_a_404(self, as_signup):
        #a deleted or banned account still has a valid token for up to an
        #hour, and the app treats this 404 as "sign out"
        assert as_signup("uid-ghost", "ghost@uom.edu.gr").get("/users/me").status_code == 404

    def test_photo_urls_come_back_in_order(self, as_user, make_user):
        me = make_user(name="Me", photos=3)
        urls = as_user(me).get("/users/me").json()["photo_urls"]
        assert len(urls) == 3
        #photo 0 is the profile picture, so order is not cosmetic
        assert urls == sorted(urls, key=lambda u: int(u.rsplit("_", 1)[1][0]))


class TestEditingYourself:
    def test_one_field_changes_and_the_rest_do_not(self, as_user, make_user):
        me = make_user(name="Me", handle="my_handle")
        as_user(me).patch("/users/me", json={"city": "Thessaloniki"})

        body = as_user(me).get("/users/me").json()
        assert body["city"] == "Thessaloniki"
        assert body["name"] == "Me"
        assert body["instagram_handle"] == "my_handle"

    def test_an_empty_string_clears_a_field(self, as_user, make_user):
        #THE APP CLEARS BY SENDING "", because a null would be dropped by
        #exclude_unset and read as "leave it alone"
        me = make_user(name="Me", city="Patras")
        as_user(me).patch("/users/me", json={"city": ""})
        assert as_user(me).get("/users/me").json()["city"] is None

    def test_the_university_cannot_be_patched(self, as_user, make_user):
        me = make_user(name="Me")
        as_user(me).patch("/users/me", json={"university": "Harvard"})
        #dropped rather than refused, so an older build that still sends it
        #keeps working
        assert as_user(me).get("/users/me").json()["university"] == "University of Macedonia"

    def test_a_pasted_instagram_link_becomes_a_handle(self, as_user, make_user):
        me = make_user(name="Me")
        as_user(me).patch(
            "/users/me",
            json={"instagram_handle": "https://www.instagram.com/maria.pap/?igsh=XYZ"},
        )
        assert as_user(me).get("/users/me").json()["instagram_handle"] == "maria.pap"

    def test_a_handle_that_cannot_be_one_is_refused(self, as_user, make_user):
        me = make_user(name="Me", handle="my_handle")
        response = as_user(me).patch("/users/me", json={"instagram_handle": "maria pap"})
        assert response.status_code == 422
        #and the old one survives: a refused edit must not clear it
        assert as_user(me).get("/users/me").json()["instagram_handle"] == "my_handle"

    def test_the_handle_cannot_be_emptied(self, as_user, make_user):
        #there is no Clear button, and an empty handle is an account that
        #cannot match
        me = make_user(name="Me", handle="my_handle")
        assert as_user(me).patch(
            "/users/me", json={"instagram_handle": ""}
        ).status_code == 422

    def test_a_null_array_means_nothing_picked(self, as_user, make_user):
        #the columns are NOT NULL, so an explicit null would be a 500
        me = make_user(name="Me", interest_tags=["Jazz"])
        as_user(me).patch("/users/me", json={"interest_tags": None})
        assert as_user(me).get("/users/me").json()["interest_tags"] == []

    def test_a_bio_over_the_limit_is_refused(self, as_user, make_user):
        me = make_user(name="Me")
        response = as_user(me).patch("/users/me", json={"bio": "x" * 301})
        assert response.status_code == 422

    def test_tags_round_trip(self, as_user, make_user):
        me = make_user(name="Me")
        as_user(me).patch(
            "/users/me",
            json={"interest_tags": ["Jazz", "Hiking"], "trait_tags": ["Calm"]},
        )
        body = as_user(me).get("/users/me").json()
        assert body["interest_tags"] == ["Jazz", "Hiking"]
        assert body["trait_tags"] == ["Calm"]


class TestSettings:
    def test_they_come_back(self, as_signup, db):
        as_signup("uid-new", "someone@uom.edu.gr").post(
            "/users/", json={"name": "Someone"}
        )
        body = as_signup("uid-new", "someone@uom.edu.gr").get("/users/settings").json()
        assert "is_dark_mode" in body

    def test_one_can_be_changed(self, as_signup):
        client = as_signup("uid-new", "someone@uom.edu.gr")
        client.post("/users/", json={"name": "Someone"})

        client.patch("/users/settings", json={"language": "el"})
        assert client.get("/users/settings").json()["language"] == "el"

    def test_a_user_with_no_settings_row_is_a_404(self, as_user, make_user):
        #make_user does not create settings, which is exactly the broken state
        #worth answering clearly
        me = make_user(name="Me")
        assert as_user(me).patch(
            "/users/settings", json={"language": "el"}
        ).status_code == 404


class TestLeaving:
    def test_the_account_goes_and_takes_its_data_with_it(
        self, as_user, make_user, swipe, db
    ):
        from database import models

        me = make_user(name="Me", photos=2)
        other = make_user(name="Other")
        swipe(me, other, "like")
        my_id = me.id

        assert as_user(me).delete("/users/me").status_code == 200

        assert db.query(models.User).filter_by(id=my_id).first() is None
        #CASCADE, not orphans: a photo or a swipe belonging to nobody would
        #still be joined onto by the feed and the likes page
        assert db.query(models.Photos).filter_by(user_id=my_id).count() == 0
        assert db.query(models.UserSwipes).filter_by(user_id=my_id).count() == 0

    def test_deleting_twice_is_a_404(self, as_user, make_user):
        me = make_user(name="Me")
        client = as_user(me)
        assert client.delete("/users/me").status_code == 200
        assert client.delete("/users/me").status_code == 404

    def test_a_deleted_account_takes_its_matches(
        self, as_user, make_user, swipe, db
    ):
        from database import models

        me, other = make_user(name="Me"), make_user(name="Other")
        swipe(other, me, "like")
        as_user(me).post("/swipes", json={"target_id": other.id, "action": "like"})
        assert db.query(models.Matches).count() == 1

        as_user(me).delete("/users/me")
        #a match with a missing side is not a match
        assert db.query(models.Matches).count() == 0


class TestHealth:
    def test_it_needs_no_token(self, client):
        #the only unauthenticated endpoint, for Render's health check
        assert client.get("/health").status_code == 200
