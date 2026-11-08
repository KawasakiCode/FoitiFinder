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
    stack frame locals    the one that was actually leaking. Sent by default,
                          and in an ASGI app every frame has `scope` in scope
                          - which is the whole request, headers included. See
                          include_local_variables below.
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

    #AND NO FRAME LOCALS, as a second line behind include_local_variables.
    #
    #That option is what actually keeps them out, and this is here because it
    #defaults to ON: anybody who sets it back - or any SDK release that
    #changes the default - reintroduces a leak of the Authorization header
    #through every ASGI frame's `scope`. Cheap to do twice for something whose
    #failure is silent and publishes a credential.
    for exception in (event.get("exception") or {}).get("values") or []:
        for frame in (exception.get("stacktrace") or {}).get("frames") or []:
            frame.pop("vars", None)

    return event


def install(transport=None) -> None:
    """Start Sentry if a DSN is configured. Safe to call when it is not.

    [transport] exists for the test that proves an unhandled exception in a
    route reaches before_send at all. tools/check_sentry.py captures an
    exception by hand, which tests the DSN and the network but NOT the
    FastAPI integration - and the integration is the part that carries every
    real 500. Passing a list's append here makes that assertable without
    anything leaving the process.
    """
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
        #NO STACK FRAME LOCALS, AND THIS ONE IS NOT A PRECAUTION - IT IS A FIX.
        #
        #sentry-sdk sends the local variables of every frame by default, and
        #it is the richest thing it offers: the actual values that produced the
        #crash. In an ASGI app it is also a disclosure. Every Starlette frame
        #has `scope` in its locals, and `scope` holds the complete request -
        #so each report carried the Authorization header (a live Firebase ID
        #token) and the full query string, including the `exclude` list of
        #everybody in one person's deck.
        #
        #before_send cannot sensibly fix that. It is handed a dict whose
        #request.headers were already cleaned, while the same values sit
        #untouched inside exception.values[].stacktrace.frames[].vars - which
        #is exactly why the scrubbing tests passed and the integration tests
        #did not.
        #
        #The cost is real: debugging without locals is harder. The published
        #privacy statement says a report does not carry "anything you had
        #typed", and a frame holding a bio, a report's free text or a revealed
        #Instagram handle makes that a lie.
        include_local_variables=False,
        #NO PERFORMANCE TRACING. It would make the "no analytics" promise in
        #the privacy statement false, and it is what burns a free quota.
        traces_sample_rate=0.0,
        before_send=_scrub,
        integrations=[
            StarletteIntegration(),
            FastApiIntegration(),
        ],
        transport=transport,
    )
    logger.info("error reporting enabled")
