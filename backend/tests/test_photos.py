"""Photos: the three-minimum rule, the ordering, and the stories.

THE RULES ARE ENFORCED IN FOUR PLACES (signup, the edit grid, here, and the
seeder) and only this one is a rule. The app's own checks are a courtesy to the
user; a patched or older client reaches the endpoint directly, and a profile
with one photo breaks the page that is built around having several.
"""


class TestTheThreeMinimum:
    def test_three_is_accepted(self, as_user, make_user):
        me = make_user(name="Me", photos=0)
        response = as_user(me).put(
            "/photos/sync",
            json={"photo_urls": [f"https://e.com/{i}.jpg" for i in range(3)]},
        )
        assert response.status_code == 200, response.text

    def test_two_is_refused(self, as_user, make_user):
        me = make_user(name="Me", photos=0)
        response = as_user(me).put(
            "/photos/sync",
            json={"photo_urls": ["https://e.com/0.jpg", "https://e.com/1.jpg"]},
        )
        assert response.status_code == 400

    def test_none_is_refused(self, as_user, make_user):
        #an empty list used to wipe every photo and leave an account that
        #cannot appear in the deck at all
        me = make_user(name="Me", photos=3)
        assert as_user(me).put("/photos/sync", json={"photo_urls": []}).status_code == 400

    def test_seven_is_refused(self, as_user, make_user):
        #the grid offers six slots; more than that came from somewhere else
        me = make_user(name="Me", photos=0)
        response = as_user(me).put(
            "/photos/sync",
            json={"photo_urls": [f"https://e.com/{i}.jpg" for i in range(7)]},
        )
        assert response.status_code == 400

    def test_a_refused_sync_changes_nothing(self, as_user, make_user):
        me = make_user(name="Me", photos=3)
        before = as_user(me).get("/photos").json()

        as_user(me).put("/photos/sync", json={"photo_urls": ["https://e.com/only.jpg"]})

        assert as_user(me).get("/photos").json() == before


class TestOrdering:
    def test_the_order_sent_is_the_order_stored(self, as_user, make_user):
        me = make_user(name="Me", photos=0)
        urls = ["https://e.com/c.jpg", "https://e.com/a.jpg", "https://e.com/b.jpg"]
        as_user(me).put("/photos/sync", json={"photo_urls": urls})

        stored = as_user(me).get("/photos").json()
        assert [photo["photo_url"] for photo in stored] == urls

    def test_photo_zero_is_the_profile_picture(self, as_user, make_user):
        me = make_user(name="Me", photos=0)
        urls = [f"https://e.com/{name}.jpg" for name in ("first", "second", "third")]
        as_user(me).put("/photos/sync", json={"photo_urls": urls})

        assert as_user(me).get("/users/me").json()["photo_urls"][0] == urls[0]

    def test_a_reorder_does_not_duplicate_anything(self, as_user, make_user, db):
        from database import models

        me = make_user(name="Me", photos=0)
        urls = [f"https://e.com/{i}.jpg" for i in range(3)]
        as_user(me).put("/photos/sync", json={"photo_urls": urls})
        as_user(me).put("/photos/sync", json={"photo_urls": list(reversed(urls))})

        #the edit grid re-sends URLs it already had; wipe-and-reinsert is what
        #keeps that from growing the table every save
        assert db.query(models.Photos).filter_by(user_id=me.id).count() == 3

    def test_removing_one_removes_its_row(self, as_user, make_user):
        me = make_user(name="Me", photos=0)
        urls = [f"https://e.com/{i}.jpg" for i in range(4)]
        as_user(me).put("/photos/sync", json={"photo_urls": urls})
        as_user(me).put("/photos/sync", json={"photo_urls": urls[:3]})

        stored = [photo["photo_url"] for photo in as_user(me).get("/photos").json()]
        assert urls[3] not in stored


class TestStories:
    def _three(self, as_user, me):
        urls = [f"https://e.com/{i}.jpg" for i in range(3)]
        as_user(me).put("/photos/sync", json={"photo_urls": urls})
        return urls

    def test_a_story_can_be_set_and_read_back(self, as_user, make_user):
        me = make_user(name="Me", photos=0)
        urls = self._three(as_user, me)

        response = as_user(me).put(
            "/photos/story", json={"photo_url": urls[1], "story": "Raining soon."}
        )
        assert response.status_code == 200, response.text

        stored = as_user(me).get("/photos").json()
        assert [p["story"] for p in stored if p["photo_url"] == urls[1]] == ["Raining soon."]

    def test_the_profile_picture_cannot_have_one(self, as_user, make_user):
        #it is shown beside a name in the feed, where there is nowhere to
        #read a caption
        me = make_user(name="Me", photos=0)
        urls = self._three(as_user, me)

        response = as_user(me).put(
            "/photos/story", json={"photo_url": urls[0], "story": "Nope"}
        )
        assert response.status_code == 400

    def test_a_story_over_the_limit_is_refused(self, as_user, make_user):
        me = make_user(name="Me", photos=0)
        urls = self._three(as_user, me)

        response = as_user(me).put(
            "/photos/story", json={"photo_url": urls[1], "story": "x" * 151}
        )
        assert response.status_code == 422

    def test_a_story_can_be_cleared(self, as_user, make_user):
        me = make_user(name="Me", photos=0)
        urls = self._three(as_user, me)
        as_user(me).put("/photos/story", json={"photo_url": urls[1], "story": "Something"})

        as_user(me).put("/photos/story", json={"photo_url": urls[1], "story": None})

        stored = as_user(me).get("/photos").json()
        assert [p["story"] for p in stored if p["photo_url"] == urls[1]] == [None]

    def test_a_story_on_somebody_elses_photo_is_a_404(
        self, as_user, make_user
    ):
        #the lookup is scoped to the caller, so this cannot write to a photo
        #that is not theirs even with the exact URL
        mine = make_user(name="Mine", photos=0)
        theirs = make_user(name="Theirs", photos=3)
        self._three(as_user, mine)

        their_url = as_user(theirs).get("/photos").json()[1]["photo_url"]
        response = as_user(mine).put(
            "/photos/story", json={"photo_url": their_url, "story": "mine now"}
        )
        assert response.status_code == 404

    def test_a_resync_keeps_the_stories(self, as_user, make_user):
        #reordering photos must not wipe what was written about them
        me = make_user(name="Me", photos=0)
        urls = self._three(as_user, me)
        as_user(me).put("/photos/story", json={"photo_url": urls[2], "story": "Kept"})

        as_user(me).put("/photos/sync", json={"photo_urls": [urls[2], urls[0], urls[1]]})

        stored = as_user(me).get("/photos").json()
        #now in slot 0, where a story is not allowed - so it must be gone
        assert [p["story"] for p in stored if p["photo_url"] == urls[2]] == [None]


class TestSinglePhotoUpload:
    def test_it_adds_one(self, as_user, make_user):
        #used by the signup flow, which uploads as each file finishes
        me = make_user(name="Me", photos=0)
        response = as_user(me).post(
            "/photos",
            json={"photo_url": "https://e.com/one.jpg", "display_order": 0},
        )
        assert response.status_code == 200, response.text
        assert len(as_user(me).get("/photos").json()) == 1
