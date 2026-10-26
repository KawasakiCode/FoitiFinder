"""When an unanswered match runs out, expressed as one rule.

A MATCH EXPIRES THREE DAYS AFTER IT BECAME SOMEBODY'S TURN, and nothing is
written to make that happen. The state is derived from columns the table
already has, so there is no expired_at, no migration, no sweep job and no
scheduler - which matters, because Render's cron is a paid feature and a
background job that sends pushes is not available to this deployment.

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

THE GRACE WINDOW IS WHY NOTHING NEEDS STORING. An expired match keeps being
returned for two more days, flagged, so whoever was owed an answer sees that
it lapsed instead of watching it vanish. 'Has this person been told' is then
a question about the clock rather than a column - and a notice that only
appears for a while is exactly what a dismissible one would have become.
"""

import datetime

from sqlalchemy import func

from database import models

#THREE DAYS, matching what the match page promises when somebody backs out of
#answering. If this changes, that copy changes with it.
EXPIRES_AFTER = datetime.timedelta(days=3)

#how long an expired match is still shown, saying so, before it goes for good
GRACE = datetime.timedelta(days=2)


def _turn_started_at():
    """When the ball landed in the court of whoever still owes an answer."""
    return func.coalesce(models.Matches.a_confirmed_at,
                         models.Matches.created_at)


def expires_at(match: models.Matches) -> datetime.datetime:
    """The deadline for one already-loaded row, for the app to show."""
    return (match.a_confirmed_at or match.created_at) + EXPIRES_AFTER


def is_expired(match: models.Matches, now: datetime.datetime) -> bool:
    """The same rule as the filters below, for a row already in memory."""
    return (match.b_confirmed_at is None
            and expires_at(match) <= now)


def not_past_grace(now: datetime.datetime):
    """Filter: drop the ones that are over AND have been shown saying so.

    Kept as a filter rather than applied in Python so an exhausted match is
    never loaded, and so the rule stays one expression in one place.
    """
    return (models.Matches.b_confirmed_at.isnot(None)
            | (_turn_started_at() > now - EXPIRES_AFTER - GRACE))
