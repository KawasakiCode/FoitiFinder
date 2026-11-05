"""When an unanswered match runs out, expressed as one rule.

A MATCH EXPIRES THREE DAYS AFTER IT BECAME SOMEBODY'S TURN. There is no
expired_at column and no scheduler: the deadline is derived from columns the
table already has, and the row is deleted the next time either participant
asks for their matches. Render's cron is a paid feature, so a sweep job is not
available to this deployment - but a lazy sweep is strictly better here
anyway, because the only person who can be affected by a stale row is somebody
who is looking at the list, and looking at the list is what triggers it.

WHOSE TURN IT IS, is what the clock measures from:

    nobody has confirmed    the completer owes the answer, and only they can
                            see the match at all, so the clock runs from
                            created_at
    one side has confirmed  the other side owes the answer, so the clock runs
                            from a_confirmed_at - NOT from created_at, because
                            a match can sit untouched for a week before
                            somebody commits, and that wait is not theirs
    both have confirmed     over, and never expires: the handles are out, and
                            deleting the row would un-share nothing while
                            destroying the only record that two people
                            connected

COALESCE(a_confirmed_at, created_at) is all three of those at once, and
b_confirmed_at IS NULL is what excludes the finished ones. (b cannot be set
while a is null: get_matches hides the row from user_b until a has answered,
so user_b has nothing to confirm.)

DELETED, NOT FLAGGED, and this reverses the first version of this module. An
expired match used to be served for two more days with an `expired` flag, so
that whoever was owed an answer read that it lapsed instead of watching it
vanish. That bought a notice nobody needs at the price of a fourth section on
the matches page, a dead row that could be tapped, an exception in every
endpoint that acts on a match, and a state that could be removed by nothing
until it was specially allowed to be. An expired match is over. The honest
representation of over is not being there - which is already how a declined
match leaves, and nobody has ever needed telling about one of those either.

NOTHING IS TOLD, no push and no notification row. Same reason: a message whose
entire content is that an opportunity closed, with nothing to do about it.

THE SWIPES ARE LEFT ALONE. Both sides liked each other, and deleting the match
does not undo that - which is what keeps an expired pair from being offered to
each other again, since the deck excludes anybody you have already swiped on.
Expired means over, not forgotten.
"""

import datetime

from sqlalchemy import func, or_

from database import models

#THREE DAYS, matching what the match page promises when somebody backs out of
#answering. If this changes, that copy changes with it.
EXPIRES_AFTER = datetime.timedelta(days=3)


def _turn_started_at():
    """When the ball landed in the court of whoever still owes an answer."""
    return func.coalesce(models.Matches.a_confirmed_at,
                         models.Matches.created_at)


def expires_at(match: models.Matches) -> datetime.datetime:
    """The deadline for one already-loaded row, for the app to show."""
    return (match.a_confirmed_at or match.created_at) + EXPIRES_AFTER


def is_expired(match: models.Matches, now: datetime.datetime) -> bool:
    """The same rule as the filter below, for a row already in memory."""
    return (match.b_confirmed_at is None
            and expires_at(match) <= now)


def _expired_filter(now: datetime.datetime):
    """Filter: the rows that have run out.

    Kept as SQL rather than a Python pass over loaded rows so the sweep is one
    statement, and so the rule stays one expression in one place.
    """
    return (models.Matches.b_confirmed_at.is_(None)
            & (_turn_started_at() <= now - EXPIRES_AFTER))


def sweep(db, user_id: int, now: datetime.datetime) -> int:
    """Delete every expired match this user is in. Returns how many went.

    CALLED BY get_matches, BEFORE IT READS, which is what makes "an expired
    match is never shown" true rather than aspirational - the list cannot
    contain one because the rows are gone by the time it is built.

    SCOPED TO ONE USER rather than sweeping the table, because a global DELETE
    on every read is a scan of every match anybody has ever made, to clean up
    rows that are invisible to everyone. A match both of whose participants
    have stopped opening the app does linger; it is unreachable by either of
    them, by the list and by every endpoint (see _match_for_participant), so
    what it costs is a row.

    NOT COMMITTED HERE, and the caller must - get_db closes the session in a
    finally, and closing an uncommitted transaction rolls it back. Returning
    the count is what lets the caller skip the commit when there was nothing
    to sweep, which is almost every call.
    """
    return db.query(models.Matches).filter(
        _expired_filter(now),
        or_(models.Matches.user_a_id == user_id,
            models.Matches.user_b_id == user_id),
    ).delete(synchronize_session=False)
