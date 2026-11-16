"""How often one caller may do a thing.

WHY THIS EXISTS. There was no limit of any kind anywhere, which left three
different problems sharing one cause. A profile endpoint with a visibility
rule is still walkable one id at a time if the walk is free. Reports and
swipes are abusable by volume rather than by content, so no amount of
validation on a single one of them helps. And this runs on Render against
Neon, which bills COMPUTE HOURS - so a flood is not only an availability
problem, it is a bill. /health already refuses to touch the database for
exactly that reason.

KEYED ON THE UID, NOT THE IP, wherever there is one. An IP is shared by a
whole university's NAT and changes when somebody walks between buildings, so
it is simultaneously too broad and too narrow. The uid comes from the verified
token, cannot be forged, and is the thing the limit is actually about. The IP
form below exists only for the routes with no verified caller yet.

IN PROCESS, AND THAT IS A REAL LIMITATION. There is no Redis here, so the
counters live in this worker's memory. Two consequences, both deliberate and
neither hidden:

  GUNICORN RUNS SEVERAL WORKERS, and a caller landing on a different one each
  time gets the limit once per worker. The effective ceiling is N x what is
  written below, where N is the worker count. The numbers are chosen with that
  in mind - they are an upper bound on abuse, not a precise quota - and the
  honest fix is a shared store, which is worth adding the day there is one.

  A DEPLOY RESETS EVERY COUNTER. Fine for this purpose: the window is a minute
  and a deploy is not something an attacker can cause.

FIXED WINDOWS, NOT A SLIDING LOG. A sliding window keeps a timestamp per
request, which is the thing being flooded; a counter and an expiry is two
integers per caller per bucket. The cost is that a caller can spend a whole
window at the end of one and a whole window at the start of the next - twice
the rate across that boundary - which does not matter for limits whose job is
to stop a script, not to meter a quota.
"""

import threading
import time

from fastapi import Depends, HTTPException, Request, status

from auth import current_uid, verified_email_uid

#bucket key -> (count, when this window ends). Guarded by the lock below
#because gunicorn's workers are threaded and two requests can land on the same
#key at once - without it the read-modify-write loses increments, which fails
#OPEN and is the one way a limiter is worse than useless.
_counters: dict[str, tuple[int, float]] = {}
_lock = threading.Lock()

#how often to walk the whole dict throwing away expired entries. Without this
#the memory grows with the number of distinct callers forever, which is a slow
#leak that only appears in production and only after a good week.
_SWEEP_EVERY_SECONDS = 300.0
_last_sweep = 0.0


def _sweep(now: float) -> None:
    """Drop expired counters. Caller holds the lock."""
    global _last_sweep
    if now - _last_sweep < _SWEEP_EVERY_SECONDS:
        return
    _last_sweep = now
    for key in [k for k, (_, ends) in _counters.items() if ends <= now]:
        del _counters[key]


def _hit(key: str, limit: int, window: float) -> float | None:
    """Count one request. Returns seconds to wait if it should be refused."""
    now = time.monotonic()
    with _lock:
        _sweep(now)
        count, ends = _counters.get(key, (0, 0.0))
        if ends <= now:
            #window expired (or never existed): start a fresh one
            count, ends = 0, now + window
        if count >= limit:
            return ends - now
        _counters[key] = (count + 1, ends)
    return None


def _refuse(retry_after: float) -> None:
    raise HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail="Too many requests",
        #SECONDS, ROUNDED UP, because a client told to wait 0 retries at once
        #and a standards-compliant one reads this header rather than guessing.
        headers={"Retry-After": str(max(1, int(retry_after + 0.999)))},
    )


def per_user(bucket: str, limit: int, window_seconds: float = 60.0):
    """A dependency that limits by uid and returns it.

    USED IN PLACE OF verified_email_uid, not alongside it: it depends on that
    and hands back the same string, so a route adopts a limit by changing what
    it depends on and nothing else. A limiter somebody has to remember to add
    as a second parameter is one that gets left off the next endpoint.
    """

    def dependency(uid: str = Depends(verified_email_uid)) -> str:
        retry_after = _hit(f"{bucket}:{uid}", limit, window_seconds)
        if retry_after is not None:
            _refuse(retry_after)
        return uid

    return dependency


def per_user_unverified(bucket: str, limit: int, window_seconds: float = 60.0):
    """The same, for the routes that run before the email is verified.

    POST /users/ and DELETE /users/me use current_uid rather than
    verified_email_uid - see the note in auth.py about why - so they cannot
    depend on the function above without changing who may call them.
    """

    def dependency(uid: str = Depends(current_uid)) -> str:
        retry_after = _hit(f"{bucket}:{uid}", limit, window_seconds)
        if retry_after is not None:
            _refuse(retry_after)
        return uid

    return dependency


def client_ip(request: Request) -> str:
    """The caller's address, as well as it can be known behind Render.

    X-Forwarded-For IS NOT TRUSTWORTHY IN GENERAL - any client can send one -
    but Render terminates TLS and appends the real peer to it, so the LAST
    entry is the one its proxy wrote and the earlier ones are whatever the
    client claimed. Taking the last is what makes this worth reading at all;
    taking the first, which is the usual mistake, would let a caller choose
    their own rate limit key by sending a header.
    """
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[-1].strip()
    return request.client.host if request.client else "unknown"


def per_ip(bucket: str, limit: int, window_seconds: float = 60.0):
    """A dependency that limits by address, for routes with no caller yet."""

    def dependency(request: Request) -> None:
        retry_after = _hit(f"{bucket}:ip:{client_ip(request)}",
                           limit, window_seconds)
        if retry_after is not None:
            _refuse(retry_after)

    return dependency


def reset() -> None:
    """Forget every counter. For tests, which must not inherit each other's."""
    global _last_sweep
    with _lock:
        _counters.clear()
        _last_sweep = 0.0
