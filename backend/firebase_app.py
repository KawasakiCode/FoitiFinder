"""Firebase, initialised once, for whoever needs it.

Importing this module is what guarantees the Admin SDK is ready: token
verification (auth.py) and push notifications (notifications.py) both depend on
an initialised app, and neither should be the one deciding how it gets set up.
"""

import os

import firebase_admin
from firebase_admin import credentials, firestore

from app_logging import logger

#FOUND RELATIVE TO THIS FILE, not to the working directory. uvicorn is
#started from backend/, pytest may be run from the repo root, and a bare
#relative path quietly means two different places depending on who called.
_SERVICE_ACCOUNT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "serviceAccountKey.json"
)

#ITS ABSENCE IS NOT FATAL, deliberately. A test run overrides the auth
#dependency and never verifies a real token, and CI has no secrets at all -
#both must still be able to import this module. Everything that genuinely
#needs Firebase already treats failure as a logged warning (see _notify), and
#token verification without it simply refuses every request, which is the
#right answer for a server that cannot check them.
firestore_db = None
if os.path.exists(_SERVICE_ACCOUNT):
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(_SERVICE_ACCOUNT))
    firestore_db = firestore.client()
else:
    logger.warning(
        "serviceAccountKey.json not found next to main.py - token verification "
        "and notifications are disabled for this process"
    )
