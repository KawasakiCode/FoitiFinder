"""Sentry for the backend, and what it is not allowed to send.

WHY THE SERVER NEEDS THIS AS MUCH AS THE APP. Everything here logs to stdout
and Render keeps that for a matter of days, so a 500 in production is
discoverable only by somebody reading the log stream while it happens. Nine
logger calls across the codebase record the things worth knowing about - a
push that could not be delivered, a token rejected for a reason the client is
deliberately not told, a 422 from a client that should be impossible - and all
of them are written to a stream nobody is watching at 3am.

IMPORTED AND CALLED FROM main, BEFORE THE APP IS BUILT. The FastAPI
integration wraps the ASGI app, so initialising after the routers are included
catches less than you would expect.

NO DSN MEANS NO SENTRY, which is the normal state for a test run and for CI.
Same shape as firebase_app: the absence of a secret is not an error, because
every module here has to be importable without one.

WHAT IT MUST NEVER SEND, and this is the list the published privacy statement
describes:

    the Firebase uid      the single identifier that joins every table here
                          to a person, and it is in the Authorization header
                          of literally every request
    the Authorization
    header                a bearer token - short lived, but a live credential
    an Instagram handle    the one value in this system that cannot be
                          un-shared once it has been read
    the request body      profile text, bios, report details
    the query string      /users/feed carries `exclude`, a list of everybody
                          the deck was holding
"""

import os

from app_logging import logger

#SCRUBBED FROM EVERY EVENT. send_default_pii is already False, which covers
#the common cases; these are named because being specific about the headers
#that carry credentials in THIS app is worth more than trusting a default.
_DROP_HEADERS = {"authorization", "cookie", "x-firebase-appcheck"}


def _scrub(event, hint):
    """Last gate before an event leaves the process."""
    request = event.get("request")
    if request:
        #HEADERS BY ALLOW-LIST LOGIC, not deny-list: anything that is not
        #explicitly dropped is kept, but the three that matter are named, and
        #a header added later that carries a secret has to be added here.
        headers = request.get("headers")
        if headers:
            request["headers"] = {
                name: value
                for name, value in headers.items()
                if name.lower() not in _DROP_HEADERS
            }
        #THE BODY IS NEVER DIAGNOSTIC HERE and is frequently personal: a
        #profile patch is somebody's bio, a report is free text about another
        #person. The endpoint and the traceback say what broke.
        request.pop("data", None)
        request.pop("cookies", None)
        #QUERY STRING GOES WITH IT - see the note in the docstring about
        #`exclude`. The path stays, because that is what identifies the route.
        request.pop("query_string", None)
        url = request.get("url")
        if isinstance(url, str) and "?" in url:
            request["url"] = url.split("?", 1)[0]

    #NO IDENTITY ON ANY REPORT. An error says what broke, not who it broke
    #for. Overwritten rather than deleted so that a later sentry_sdk.set_user
    #anywhere in this codebase cannot put a real uid back.
    event["user"] = {"id": "anonymous"}
    return event


def install() -> None:
    """Start Sentry if a DSN is configured. Safe to call when it is not."""
    dsn = os.getenv("SENTRY_DSN", "").strip()
    if not dsn:
        logger.info("SENTRY_DSN not set - error reporting is disabled")
        return

    import sentry_sdk
    from sentry_sdk.integrations.fastapi import FastApiIntegration
    from sentry_sdk.integrations.starlette import StarletteIntegration

    sentry_sdk.init(
        dsn=dsn,
        #WHICH DEPLOY AN ERROR CAME FROM. Render exposes the commit as
        #RENDER_GIT_COMMIT, so a fix can be told apart from a regression
        #without anybody tagging a release by hand.
        release=os.getenv("RENDER_GIT_COMMIT"),
        environment=os.getenv("SENTRY_ENVIRONMENT", "production"),
        #NO IPs, NO HEADERS, NO BODIES by default. _scrub is the belt to this
        #braces, because the default covers the general case and this app has
        #specific things that must never travel.
        send_default_pii=False,
        #NO PERFORMANCE TRACING. It would make the "no analytics" promise in
        #the privacy statement false, and it is what burns a free quota.
        traces_sample_rate=0.0,
        before_send=_scrub,
        integrations=[
            StarletteIntegration(),
            FastApiIntegration(),
        ],
    )
    logger.info("error reporting enabled")
