"""That a photo URL is one of ours, and the right user's.

THE STRICT PATH DOES NOT RUN IN THE REST OF THE SUITE. photo_urls falls back
to accepting any https URL when no Storage bucket is configured, and no test
process has one - which is correct (see the module docstring) and means the
checking that matters in production would otherwise be covered by nothing at
all. Every test here names a bucket so the real branch is the one exercised.
"""

import pytest

import firebase_app
import photo_urls

BUCKET = "foitifinder.firebasestorage.app"
UID = "uid-abc"


def url_for(uid=UID, name="1700000000.jpg", bucket=BUCKET):
    """What getDownloadURL() hands back for an upload by `uid`."""
    return (f"https://firebasestorage.googleapis.com/v0/b/{bucket}/o/"
            f"users%2F{uid}%2Fgallery%2F{name}?alt=media&token=a-token")


@pytest.fixture
def bucket(monkeypatch):
    monkeypatch.setattr(firebase_app, "storage_bucket", BUCKET)


class TestWithABucketConfigured:
    def test_our_own_upload_passes(self, bucket):
        assert photo_urls.is_ours(url_for(), UID)

    def test_another_users_upload_is_refused(self, bucket):
        #THE ONE THAT MATTERS MOST. Checking only the bucket would let
        #somebody set their photos to another user's - their pictures on your
        #profile, which is a thing reporting exists for and is better
        #prevented than reviewed.
        assert not photo_urls.is_ours(url_for(uid="somebody-else"), UID)

    def test_another_bucket_is_refused(self, bucket):
        assert not photo_urls.is_ours(url_for(bucket="attacker.appspot.com"), UID)

    def test_another_host_is_refused(self, bucket):
        #the tracking pixel: an address on somebody else's server, fetched by
        #every device that opens the profile
        assert not photo_urls.is_ours("https://evil.example/pixel.jpg", UID)

    def test_a_uid_that_merely_starts_the_same_is_refused(self, bucket):
        #uid-abc must not match uid-abcdef. The prefix ends with the encoded
        #slash, which is what makes this false rather than true.
        assert not photo_urls.is_ours(url_for(uid=UID + "def"), UID)

    def test_plain_http_is_refused(self, bucket):
        assert not photo_urls.is_ours(url_for().replace("https://", "http://"), UID)

    def test_rubbish_is_refused(self, bucket):
        for value in ["", "not a url", "javascript:alert(1)", "/relative.jpg"]:
            assert not photo_urls.is_ours(value, UID), value

    def test_reject_foreign_names_the_offender(self, bucket):
        good_a, good_b = url_for(name="1.jpg"), url_for(name="2.jpg")
        bad = "https://evil.example/pixel.jpg"

        assert photo_urls.reject_foreign([good_a, good_b], UID) is None
        assert photo_urls.reject_foreign([good_a, bad, good_b], UID) == bad


class TestWithNoBucketConfigured:
    """A process with no Firebase cannot verify a token, so no authenticated
    request reaches a photo endpoint there - see the module docstring."""

    def test_any_https_url_passes(self, monkeypatch):
        monkeypatch.setattr(firebase_app, "storage_bucket", None)
        assert photo_urls.is_ours("https://example.com/0.jpg", UID)

    def test_but_the_shape_is_still_checked(self, monkeypatch):
        monkeypatch.setattr(firebase_app, "storage_bucket", None)
        assert not photo_urls.is_ours("http://example.com/0.jpg", UID)
        assert not photo_urls.is_ours("javascript:alert(1)", UID)
