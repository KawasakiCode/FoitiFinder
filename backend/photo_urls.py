"""Whether a photo URL is one of ours, and whose.

WHAT WAS WRONG. photo_url was a bare `str`, stored exactly as sent and served
to everybody who sees the profile. A patched client could put any address in
it. The fetch happens on the VIEWERS' devices, not on this server, so the
interesting abuse is not SSRF - it is that a URL on somebody else's host is a
tracking pixel, collecting the IP of every person who opens that profile, and
that arbitrary remote content can be made to appear inside the app.

AND WHOSE MATTERS AS MUCH AS WHETHER. Storage paths are users/<uid>/gallery/...
so a URL carries the uploader's uid in it. Checking only that a URL points at
our bucket would still let somebody set their photos to another user's - their
pictures on your profile, which is what reporting exists for and is better
prevented. The owner comes from the verified token, so the path has to match
the caller.

PERMISSIVE WITH NO FIREBASE CONFIGURED, deliberately. A process without
serviceAccountKey.json cannot verify an ID token, so no authenticated request
reaches a photo endpoint there at all - which makes it tests, CI, and a laptop
with the seeder, none of which can be production. Pinning the bucket in those
would mean every photo fixture carrying a hundred-character URL to prove a
point the test is not about. See firebase_app, which disables itself the same
way and for the same reason.

ONLY THE DOWNLOAD URL SHAPE. getDownloadURL() in api_services.dart returns

  https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<encoded path>?alt=media&token=<uuid>

and that token is what lets a viewer read the object, so it is the only form
the app can produce and the only one worth accepting.
"""

from urllib.parse import quote

import firebase_app

#the host getDownloadURL() builds against. Not configurable: a URL on another
#host is exactly what this is here to refuse.
_HOST = "https://firebasestorage.googleapis.com/v0/b/"


def expected_prefix(uid: str) -> str | None:
    """Where this user's photos must live, or None if we cannot know.

    None means no bucket is configured, which the callers read as "accept any
    https URL" - see the note at the top about why that process cannot be
    production.
    """
    bucket = firebase_app.storage_bucket
    if not bucket:
        return None

    #THE PATH IS ENCODED INSIDE THE URL. Storage puts the object name in one
    #path segment, so the slashes in users/<uid>/gallery become %2F - and a
    #prefix built with real slashes would match nothing and refuse every
    #photo the app has ever uploaded.
    path = quote(f"users/{uid}/gallery/", safe="")
    return f"{_HOST}{bucket}/o/{path}"


def is_ours(url: str, uid: str) -> bool:
    """Whether `url` is a Storage download URL for `uid`'s own gallery."""
    if not isinstance(url, str) or not url.startswith("https://"):
        return False

    prefix = expected_prefix(uid)
    if prefix is None:
        #no bucket configured: shape only, which still refuses http://, a
        #javascript: URL and anything that is not a URL at all
        return True

    return url.startswith(prefix)


def reject_foreign(urls, uid: str) -> str | None:
    """The first URL in `urls` that is not this user's, or None if all are.

    Returns the offender rather than a bool so the caller can say which one,
    which matters for /photos/sync where six arrive at once and a flat "no"
    gives the client nothing to act on.
    """
    for url in urls:
        if not is_ours(url, uid):
            return url
    return None
