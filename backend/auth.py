"""Who is calling.

MOVED OUT OF main.py ON PURPOSE. This is the most security-sensitive code in
the project and it is three short functions; buried among twenty endpoints
nobody reads it, and the rule it enforces - identity comes from the token and
from nowhere else - is exactly the kind of thing that gets quietly worked
around when it is inconvenient.

Importing firebase_app is not decoration: verify_id_token needs an initialised
Admin SDK, and this module must not be the one to decide how that happens.
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth

import firebase_app  # noqa: F401  (imported for its initialisation)
from app_logging import logger

# --- Authentication ---------------------------------------------------------
# A Firebase UID is an IDENTIFIER, not a credential: trusting one sent by the
# client means anyone who knows a uid can act as that user. Instead the client
# sends the Firebase ID token (a short-lived JWT signed by Google) as
# `Authorization: Bearer <token>`. We verify the signature here and take the uid
# from the VERIFIED claims, so it can't be forged. Every endpoint that needs to
# know "who is calling" must get it from this dependency — never from a path,
# query or body parameter.
bearer_scheme = HTTPBearer()

def verified_claims(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> dict:
    """Verify the caller's Firebase ID token and return its decoded claims."""
    try:
        return auth.verify_id_token(credentials.credentials)
    except Exception:
        # expired, tampered with, wrong project, or not a token at all
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

def verified_email_uid(claims: dict = Depends(verified_claims)) -> str:
    """Like current_uid, but also requires the caller's email to be verified.

    The token is still fully verified (same verified_claims dependency); this
    only adds a condition. Anyone can sign up with a university address they
    don't own, so without this the "university students only" rule would live in
    the app UI alone and be bypassable by calling the API directly.

    Used by every endpoint EXCEPT account creation and the profile read, which
    both must work before verification: POST /users/ creates the very account
    the user is about to verify, and GET /users/me is what the auth router reads
    to decide whether the account exists at all — a 403 there is
    indistinguishable from "no account" and would sign the user out before they
    could ever reach the verification page.
    """
    if claims.get("email_verified") is not True:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Email not verified",
        )
    return claims["uid"]

def current_uid(claims: dict = Depends(verified_claims)) -> str:
    """The uid of the caller, taken from the verified token claims."""
    return claims["uid"]
