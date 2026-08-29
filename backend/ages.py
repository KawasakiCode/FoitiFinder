"""Turning a stored birthday into the age everything else talks about.

`users.birthday` is the truth: a date that never goes stale. Age is derived
wherever it is needed, so nobody ever has a wrong age because a row was written
a year ago and never touched again - which is exactly what an `age` integer
column guarantees will happen.

The feed filters on age too, but it must do that in SQL rather than in Python,
so `years_ago` gives it the cutoff DATE to compare a birthday against instead.
Comparing dates keeps the filter sargable - an index on `birthday` still works,
where wrapping the column in date arithmetic would kill it.
"""

import datetime
from typing import Optional


def years_ago(years: int, today: Optional[datetime.date] = None) -> datetime.date:
    """The date exactly `years` before today.

    Someone born on this date turns exactly `years` old today.
    """
    today = today or datetime.date.today()
    try:
        return today.replace(year=today.year - years)
    except ValueError:
        #29 February in a year whose target is not a leap year. Fall back to
        #the 28th: a leap-day birthday counts as having happened by the 28th.
        return today.replace(year=today.year - years, day=28)


def age_from_birthday(
    birthday: Optional[datetime.date],
    today: Optional[datetime.date] = None,
) -> Optional[int]:
    """Whole years since `birthday`, or None if it was never set."""
    if birthday is None:
        return None
    today = today or datetime.date.today()
    #subtract one more year when this year's birthday has not happened yet
    had_birthday_this_year = (today.month, today.day) >= (birthday.month, birthday.day)
    return today.year - birthday.year - (0 if had_birthday_this_year else 1)
