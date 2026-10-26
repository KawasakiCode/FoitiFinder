"""The app itself: everything else lives next door.

WHAT USED TO BE HERE. One 1,300-line file with twenty-one endpoints, the
pydantic models they answer with, the auth dependencies, the notification
helper and the Firebase setup. Nothing was wrong with any of it except that
nobody can hold it in their head, and the three functions that decide who is
calling were buried in the middle of it.

  auth.py            who is calling, and nothing else
  firebase_app.py    the Admin SDK, initialised once
  app_logging.py     the logger everything shares
  api_models.py      the shapes endpoints answer with
  notifications.py   sending a push AND recording the row
  routers/           the endpoints, grouped by what they are about

THE INCLUDE ORDER BELOW IS LOAD-BEARING. FastAPI matches routes in the order
they were registered, so /users/me and /users/feed must be registered BEFORE
/users/{user_id}/profile - otherwise "me" is read as a user_id and every
request for your own row becomes a lookup for a user called "me".
"""

import logging  # noqa: F401  (kept so `uvicorn main:app --log-level` is unsurprising)

from dotenv import load_dotenv
from fastapi import FastAPI, Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

import app_version
from app_logging import logger
from routers import (
    feed,
    likes,
    matches,
    notifications,
    photos,
    profiles,
    swipes,
    users,
)

load_dotenv()

app = FastAPI()


#SAYS WHICH DATABASE on every start, because the answer is invisible otherwise
#and getting it wrong is silent: DATABASE_URL set in a shell beats
#backend/.env, so a uvicorn started in the same window as an `alembic upgrade`
#against Neon will happily serve PRODUCTION data on localhost:8000.
#
#Host and database name only - never the password, because this line ends up
#in every log and every screenshot of one.
from database.database import SQLALCHEMY_DATABASE_URL  # noqa: E402

logger.info(
    "database: %s",
    SQLALCHEMY_DATABASE_URL.split("@")[-1] if SQLALCHEMY_DATABASE_URL else "NOT SET",
)

#A REJECTED REQUEST IS A BROKEN CLIENT, AND SILENCE IS THE WORST OUTCOME.
#
#FastAPI answers a malformed body with 422 before any endpoint runs, so there
#is nowhere in the handlers to notice it. Nobody is doing this by hand - it
#means a build is sending something the server does not accept, and the user
#sees a swipe that never registers (the retry queue correctly refuses to
#retry a 422, since the answer would not change). Logged with the path and the
#reason so it shows up in the server log instead of only on one phone.
@app.exception_handler(RequestValidationError)
async def log_rejected_request(request: Request, exc: RequestValidationError):
    logger.warning("422 %s %s: %s", request.method, request.url.path, exc.errors())
    return JSONResponse(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        content={"detail": jsonable_encoder(exc.errors())})


#the endpoints. users/feed/photos first, so their literal paths win over
#/users/{user_id} - see the note at the top of this file.
app.include_router(users.router, tags=["users"])
app.include_router(feed.router, tags=["feed"])
app.include_router(photos.router, tags=["photos"])
app.include_router(swipes.router, tags=["swipes"])
app.include_router(likes.router, tags=["likes"])
app.include_router(matches.router, tags=["matches"])
app.include_router(notifications.router, tags=["notifications"])
#LAST, because /users/{user_id}/profile would otherwise swallow /users/me
app.include_router(profiles.router, tags=["profiles"])

#RENDER'S HEALTH CHECK PATH, set in the service's settings - so this is
#polled every few seconds, forever, by the platform itself. It decides
#whether a deploy goes live and whether the running service is considered
#alive. The access log lines it produces are filtered out in
#app_logging.py; a non-200 from here still gets logged.
#
#Also the keep-alive target for an external pinger (UptimeRobot /
#cron-job.org) if one is needed, hit every ~10 minutes so Render never
#reaches its 15-minute spin-down and users stop paying the ~60s cold start.
#
#IT MUST NOT TOUCH THE DATABASE. No Depends(get_db), no query, nothing. Neon's
#free plan allows ~400 compute hours a month and suspends after 5 minutes of
#inactivity, so a ping that opens a connection would keep the compute awake
#half of every hour - roughly 365 hours a month, almost the entire allowance
#burnt on pings before a single real user. Over the limit Neon suspends the
#project until the next billing period.
#
#So: Render stays warm, Neon sleeps normally and wakes only for real traffic
#(transparently - see pool_pre_ping in database/database.py).
#
#DO NOT ADD A DATABASE CHECK HERE, however tempting. It would make this a
#readiness check rather than a liveness one, which sounds better and costs
#the entire Neon allowance: the platform polls this constantly, and every
#poll would hold the compute awake.
@app.get("/health")
def health():
    return {"status": "ok"}


#THE OLDEST BUILD THIS API WILL STILL TALK TO - see app_version.py for what
#the number is for and when it is raised.
#
#NO AUTHENTICATION, deliberately. A build old enough to be refused may also be
#old enough to get signing in wrong, and an update wall that only appears once
#you have logged in is a wall with a door next to it. It discloses nothing: the
#answer is the same integer for everybody and is already inside every APK.
#
#NO DATABASE EITHER, for the same reason /health does not touch it: this is
#called on every launch, and a constant does not need Neon awake to be read.
@app.get("/app/minimum-build")
def minimum_build():
    return app_version.MINIMUM_BUILD
