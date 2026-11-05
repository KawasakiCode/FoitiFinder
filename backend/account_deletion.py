"""Everything about a user that is NOT a row in Postgres.

DELETING THE USER ROW USED TO BE THE WHOLE OF ACCOUNT DELETION, and it left
two things behind in Firebase:

    users/<uid>/...          the photo FILES in Cloud Storage. The photos
                             table cascades, so nothing in the app pointed at
                             them any more - but every download URL kept
                             working, forever, for anybody who had one. A
                             dating profile's photos surviving its deletion is
                             the worst version of this bug: the rows that say
                             who they were of are the part that went.

    users/<uid>              the Firestore document holding fcm_token,
                             last_active and match_notifications. A live push
                             token for an account that no longer exists.

Both are now deleted here, and the privacy statement and the account deletion
page say so, which is the real reason this module exists: those documents are
published and a promise in one of them has to be true in code.

FIREBASE FIRST, POSTGRES SECOND, and the order is the point. The user row is
the proof that the account exists; delete it first and a failure here leaves
files nobody can find, attached to nobody, with no account left to retry from.
Everything in here is idempotent - deleting an absent document or an absent
blob is not an error - so failing halfway and being called again is safe,
which is what makes "raise and let them retry" the right response to a
Firebase outage rather than "log it and carry on".

BY PREFIX, NOT BY URL. The photo rows hold download URLs, and deriving an
object path back out of one is parsing somebody else's URL format. The objects
live under users/<uid>/ because that is where the app uploads them, so the
prefix is the authority - and it sweeps up anything an earlier partial delete
or a removed photo left behind, which the URL list by definition cannot.
"""

from app_logging import logger

#"ALREADY GONE" IS A SUCCESS, and this is how it arrives. Imported
#defensively: google-api-core comes with google-cloud-storage and both are
#pinned, but this module has to import in a process with no Firebase at all,
#and a missing dependency must not be the thing that stops the rest of the
#backend starting. With no real bucket there are no blobs to fail on either.
try:
    from google.api_core.exceptions import NotFound as _NotFound
except ImportError:  # pragma: no cover - google-cloud-storage is pinned
    class _NotFound(Exception):
        pass

#SENTINEL, NOT None. None is a legitimate value for both of these - it is what
#a process with no service account has - so None cannot also mean "go and find
#the real one", or a test could not ask for the no-op behaviour explicitly.
_DEFAULT = object()

#where the app uploads, from api_services.dart: users/<uid>/gallery/<name>.jpg.
#Everything the user owns is under users/<uid>/, so that is what is swept.
_PREFIX = "users/{uid}/"


def _bucket():
    """The Storage bucket, or None if this process has no Firebase."""
    import firebase_app

    if not firebase_app.storage_bucket:
        return None
    from firebase_admin import storage

    return storage.bucket()


def purge(uid: str, firestore_db=_DEFAULT, bucket=_DEFAULT) -> None:
    """Delete the Firestore document and the Storage objects for one uid.

    Raises whatever Firebase raises. The caller is deleting an account and
    must not go on to delete the rest if this did not work.

    A PROCESS WITH NO SERVICE ACCOUNT DOES NOTHING, which is the same choice
    firebase_app and notifications make: CI has no secrets and the test suite
    overrides the auth dependency, so every module here has to be importable
    and callable without Firebase. Nothing is silently skipped in production,
    because a backend that cannot verify a token serves no requests at all.
    """
    if firestore_db is _DEFAULT:
        import firebase_app
        firestore_db = firebase_app.firestore_db
    if bucket is _DEFAULT:
        bucket = _bucket()

    if firestore_db is None and bucket is None:
        logger.warning(
            "account deletion: no Firebase in this process, leaving the "
            "Firestore document and photo files for uid %s", uid
        )
        return

    if firestore_db is not None:
        #DELETING A DOCUMENT THAT IS NOT THERE IS NOT AN ERROR in Firestore,
        #so this needs no exists() check - and a check would be a race anyway.
        firestore_db.collection("users").document(uid).delete()

    if bucket is not None:
        blobs = list(bucket.list_blobs(prefix=_PREFIX.format(uid=uid)))
        for blob in blobs:
            #ONE AT A TIME, NOT delete_blobs(). The batch helper stops at the
            #first error, which on a half-deleted account means a retry cannot
            #get past whatever failed. A blob that has already gone is the
            #expected case on a retry, so it is not a failure.
            try:
                blob.delete()
            except _NotFound:
                continue
        logger.info("account deletion: removed %d stored file(s) for uid %s",
                    len(blobs), uid)
