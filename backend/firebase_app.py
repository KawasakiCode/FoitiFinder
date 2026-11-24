"""Firebase, initialised once, for whoever needs it.

Importing this module is what guarantees the Admin SDK is ready: token
verification (auth.py) and push notifications (notifications.py) both depend on
an initialised app, and neither should be the one deciding how it gets set up.
"""

import os

import firebase_admin
from firebase_admin import credentials, firestore

from app_logging import logger

#WHERE THE KEY IS LOOKED FOR, IN ORDER, AND WHY THERE IS MORE THAN ONE PLACE.
#
#THIS USED TO BE A SINGLE HARDCODED PATH and it cost a deployment. The key is
#gitignored, so on Render it arrives as a Secret File - and Render puts those
#at /etc/secrets/<filename> plus, for non-Docker services, in the SERVICE'S
#ROOT DIRECTORY. That root directory is a dashboard setting. Leave it blank
#and the file lands at the repository root while this module looks next to
#itself in backend/, so the key is present, correctly uploaded, and invisible.
#
#WHAT THAT LOOKS LIKE FROM THE OUTSIDE IS AN AUTH BUG. No key means no
#initialised app, which means verify_id_token raises for every request, which
#means 401 "Invalid or expired token" on every endpoint for every user -
#including a freshly created account, which is the detail that sends you
#looking at the signup flow instead of at the deploy. The account is fine. The
#server cannot check anybody's token.
#
#/etc/secrets IS THE ONE THAT IS ALWAYS RIGHT on Render, whatever the root
#directory is set to, so it is here permanently rather than as a workaround.
#
#GOOGLE_APPLICATION_CREDENTIALS FIRST, because it is the standard name for
#exactly this and an explicit setting should beat a guess. It is a PATH, not
#the key itself - nothing here ever takes a private key from an environment
#variable, where it would end up in `env` output and process listings.
_LOCAL = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "serviceAccountKey.json"
)


def _candidates() -> list[str]:
    """Every path that might hold the key, in the order they are tried."""
    return [p for p in (
        os.getenv("GOOGLE_APPLICATION_CREDENTIALS"),
        _LOCAL,
        "/etc/secrets/serviceAccountKey.json",
    ) if p]


def no_key_warning() -> str:
    """What to say when there is no key anywhere.

    A FUNCTION BECAUSE THE WORDING IS THE WHOLE FEATURE. This log line is the
    only symptom the failure ever has, so it has to name the CONSEQUENCE and
    not just the missing file - the version that said "serviceAccountKey.json
    not found" read as housekeeping and was scrolled past while every request
    in production answered 401. Tested, in tests/test_firebase_credentials.py.
    """
    return (
        "NO FIREBASE SERVICE ACCOUNT FOUND - every request will be refused "
        "with 401 \"Invalid or expired token\", including from accounts "
        "created seconds ago, because this process cannot verify anybody's "
        "token. Looked in: " + ", ".join(_candidates()) + ". On Render, add "
        "the key as a Secret File: it is readable at "
        "/etc/secrets/serviceAccountKey.json whatever the service's root "
        "directory is set to."
    )


def service_account_path() -> str | None:
    """The first service-account file that exists, or None.

    A FUNCTION SO IT CAN BE TESTED. The result of this decides whether the
    whole backend can authenticate anybody, and the failure mode is a log line
    nobody reads; a pure function over the filesystem can at least be asserted
    on - see tests/test_firebase_credentials.py.
    """
    for path in _candidates():
        if os.path.exists(path):
            return path
    return None


#ITS ABSENCE IS NOT FATAL, deliberately. A test run overrides the auth
#dependency and never verifies a real token, and CI has no secrets at all -
#both must still be able to import this module. Everything that genuinely
#needs Firebase already treats failure as a logged warning (see _notify), and
#token verification without it simply refuses every request, which is the
#right answer for a server that cannot check them.
firestore_db = None

#THE STORAGE BUCKET HAS TO BE NAMED AT INIT, or storage.bucket() raises
#"Storage bucket name not specified" - and deleting a user's photos is the one
#thing in this backend that touches Storage, so it would have failed only on
#the path nobody runs twice. Derived from the service account's own project id
#rather than configured, because the two cannot then disagree; the env var is
#there for a project whose bucket was not named after it.
storage_bucket = None

#WHICH PROJECT THIS PROCESS WILL ACCEPT TOKENS FROM. Read by nothing; logged,
#which is the point - see below.
project_id = None

_path = service_account_path()

if _path:
    _cred = credentials.Certificate(_path)
    project_id = _cred.project_id
    storage_bucket = (os.getenv("FIREBASE_STORAGE_BUCKET")
                      or f"{_cred.project_id}.firebasestorage.app")
    if not firebase_admin._apps:
        firebase_admin.initialize_app(_cred, {"storageBucket": storage_bucket})
    firestore_db = firestore.client()

    #SAYS WHICH PROJECT, FOR THE SECOND WAY THIS FAILS. verify_id_token checks
    #a token's issuer and audience against this project, so an app built from
    #one Firebase project and a backend holding another project's key rejects
    #every token with the same 401 as having no key at all - and that one
    #cannot be seen by looking for a missing file. The project id is not a
    #secret (it ships inside the app, in firebase_options.dart), and having it
    #in the first few lines of the log turns an invisible mismatch into a
    #comparison anybody can make. Says WHERE the key came from too, because
    #"it is in the dashboard" and "this process found it" are different facts.
    logger.info("firebase: project %s, key from %s", project_id, _path)
else:
    #LOUD, AND IT SAYS WHAT TO DO. The old version named one path and left the
    #reader to conclude the file was simply absent; it is more often present
    #and somewhere else.
    logger.warning("%s", no_key_warning())
