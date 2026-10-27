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


#THE AGE THIS APP IS FOR, and the one number that is not a preference.
MINIMUM_AGE = 18


def is_old_enough(
    birthday: Optional[datetime.date],
    today: Optional[datetime.date] = None,
) -> bool:
    """Whether a birthday is old enough to hold an account.

    NONE PASSES, because a row is created at registration and the birthday is
    asked for later, on the setup page - so an absent one is an unfinished
    profile rather than a young user. SetupWrapper is what makes it arrive.

    WHAT THIS CATCHES, HONESTLY: not much. The app's date picker will not let
    anybody select an under-age date, so an honest user cannot send one and a
    dishonest one sends a date they made up - which this accepts, because
    nothing here verifies a birthday against anything. It refuses a truthful
    claim, which is the only kind it can see.
    
    WHAT IT IS FOR, THEN. It makes the column mean something: "no account was
    created or edited into being under 18" becomes a fact rather than a hope,
    which is what you want to lean on when an underage report arrives and you
    look at the stored date. And it survives the picker regressing - that cap
    is one line in one widget, and there will be other ways in eventually.
    """
    age = age_from_birthday(birthday, today)
    return age is None or age >= MINIMUM_AGE
