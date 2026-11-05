"""Deleting an account deletes what Firebase holds as well.

THE BUG THIS FILE IS ABOUT. DELETE /users/me deleted the user row and let the
cascade take the photos, swipes, matches, settings and notifications - and
left two things standing in Firebase:

    users/<uid>/...   the photo FILES in Cloud Storage. Every download URL
                      kept working, forever, for anybody who had one. The rows
                      that said whose face it was are the part that went.
    users/<uid>       the Firestore document with fcm_token in it: a live push
                      token for an account that no longer exists.

WHY IT IS WORTH A TEST FILE OF ITS OWN rather than two more asserts in
TestLeaving. Neither of these can be checked against the database, so they are
the only part of deletion that no existing test could see - which is how they
survived. And they are now written down in a published privacy statement and
an account deletion page, so the promise and the code have to be checked
against each other by something other than memory.

THE FAKES ARE DELIBERATELY DUMB. They record what was asked of them and
nothing else: the point is which paths are reached, which is the whole of the
bug. A real Firebase round trip would test Google's code.
"""

import pytest

import account_deletion


class FakeDocument:
    def __init__(self, store, path):
        self._store = store
        self._path = path

    def delete(self):
        self._store.append(self._path)


class FakeCollection:
    def __init__(self, store, name):
        self._store = store
        self._name = name

    def document(self, doc_id):
        return FakeDocument(self._store, f"{self._name}/{doc_id}")


class FakeFirestore:
    """Records every document delete as 'collection/id'."""

    def __init__(self):
        self.deleted = []

    def collection(self, name):
        return FakeCollection(self.deleted, name)


class FakeBlob:
    def __init__(self, bucket, name, missing=False):
        self._bucket = bucket
        self.name = name
        self._missing = missing

    def delete(self):
        if self._missing:
            raise account_deletion._NotFound(self.name)
        self._bucket.deleted.append(self.name)


class FakeBucket:
    """Holds named objects and records which ones were deleted."""

    def __init__(self, names, missing=()):
        self._names = list(names)
        self._missing = set(missing)
        self.deleted = []
        self.prefixes_listed = []

    def list_blobs(self, prefix):
        self.prefixes_listed.append(prefix)
        return [
            FakeBlob(self, name, missing=name in self._missing)
            for name in self._names
            if name.startswith(prefix)
        ]


MINE = [
    "users/uid-alice/gallery/one.jpg",
    "users/uid-alice/gallery/two.jpg",
]
THEIRS = ["users/uid-bob/gallery/one.jpg"]


class TestThePurgeItself:
    def test_the_firestore_document_goes(self):
        """WHERE THE PUSH TOKEN LIVES, and the reason this is not optional:
        a token left behind is a notification sent to a phone whose owner
        deleted their account.
        """
        store = FakeFirestore()
        account_deletion.purge("uid-alice", firestore_db=store, bucket=None)

        assert store.deleted == ["users/uid-alice"]

    def test_the_photo_files_go(self):
        bucket = FakeBucket(MINE)
        account_deletion.purge("uid-alice", firestore_db=None, bucket=bucket)

        assert sorted(bucket.deleted) == sorted(MINE)

    def test_and_only_this_user_s_files(self):
        """THE ASSERTION THAT MATTERS MOST HERE. A prefix is a powerful thing
        to hand a delete loop, and a uid that was not anchored to the start of
        the path - or a prefix of 'users/' - would take everybody's photos on
        the first deletion.
        """
        bucket = FakeBucket(MINE + THEIRS)
        account_deletion.purge("uid-alice", firestore_db=None, bucket=bucket)

        assert sorted(bucket.deleted) == sorted(MINE)
        assert bucket.prefixes_listed == ["users/uid-alice/"]

    def test_a_file_already_gone_is_not_a_failure(self):
        """SO A RETRY AFTER A HALF-FINISHED PURGE GETS THROUGH. The endpoint
        refuses to delete the row if this raises, so the user retries - and
        the second attempt meets everything the first one managed. If 'already
        deleted' counted as an error, the retry could never get past it.
        """
        bucket = FakeBucket(MINE, missing=[MINE[0]])
        account_deletion.purge("uid-alice", firestore_db=None, bucket=bucket)

        assert bucket.deleted == [MINE[1]]

    def test_a_real_failure_is_raised(self):
        #anything that is not "already gone" has to reach the caller: the row
        #must not be deleted on the strength of a purge that did not happen
        class Exploding(FakeBucket):
            def list_blobs(self, prefix):
                raise RuntimeError("storage is down")

        with pytest.raises(RuntimeError):
            account_deletion.purge(
                "uid-alice", firestore_db=None, bucket=Exploding([]))

    def test_a_process_with_no_firebase_does_nothing(self):
        """CI HAS NO SERVICE ACCOUNT and the suite overrides the auth
        dependency, so every module that touches Firebase has to be callable
        without it. Nothing is silently skipped in production: a backend that
        cannot verify a token answers no requests at all.
        """
        account_deletion.purge("uid-alice", firestore_db=None, bucket=None)


class TestTheEndpoint:
    def test_it_purges_firebase_for_the_calling_uid(
        self, as_user, make_user, monkeypatch, db
    ):
        from database import models

        purged = []
        monkeypatch.setattr(account_deletion, "purge", purged.append)

        me = make_user(name="Me", photos=2)
        my_id = me.id
        my_uid = me.firebase_uid

        assert as_user(me).delete("/users/me").status_code == 200

        #THE UID FROM THE VERIFIED TOKEN, never one from the body - the same
        #rule as every other endpoint, and the one that decides whose photos
        #a delete loop is pointed at.
        assert purged == [my_uid]
        assert db.query(models.User).filter_by(id=my_id).first() is None

    def test_a_firebase_failure_deletes_nothing(
        self, as_user, make_user, monkeypatch, db
    ):
        """FIREBASE FIRST, POSTGRES SECOND, and this is why the order is not
        the other way round. The user row is the only index of which files
        exist; delete it first and a failure here leaves photo files nobody
        can find, attached to nobody, with no account left to retry from.

        So the request fails and the account survives intact, which is a state
        the user can do something about.
        """
        from database import models

        def explode(uid):
            raise RuntimeError("storage is down")

        monkeypatch.setattr(account_deletion, "purge", explode)

        me = make_user(name="Me", photos=2)
        my_id = me.id

        response = as_user(me).delete("/users/me")

        assert response.status_code == 502
        assert db.query(models.User).filter_by(id=my_id).first() is not None
        assert db.query(models.Photos).filter_by(user_id=my_id).count() == 2

    def test_and_says_nothing_was_deleted(
        self, as_user, make_user, monkeypatch
    ):
        #the one message the user needs, because the alternative reading of a
        #failed deletion is "it half worked and I should not try again"
        def explode(uid):
            raise RuntimeError("storage is down")

        monkeypatch.setattr(account_deletion, "purge", explode)

        me = make_user(name="Me")
        body = as_user(me).delete("/users/me").json()

        assert "nothing was deleted" in body["detail"].lower()
