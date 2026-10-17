"""Cleaning up whatever the user typed into an Instagram handle.

NORMALISING, NOT VALIDATING. Meta shut the Instagram Basic Display API down in
December 2024 and what replaced it needs a Business or Creator account, so for
a student on a personal account there is no way to check that a handle exists
or that it belongs to them. What is left is making sure the thing we store is
shaped like a handle, because the handle IS the payoff of a match - there is no
chat in this app - and a broken one is a match that goes nowhere.

People paste all of these, and all of them mean the same account:

    maria.pap
    @maria.pap
    instagram.com/maria.pap
    https://www.instagram.com/maria.pap/
    https://instagram.com/maria.pap?igsh=MXY2
    HTTPS://Instagram.com/Maria.Pap

Deliberately has NO database, FastAPI or Firebase imports, so it can be unit
tested on its own - the same reason preferences/ and ages.py are separate.
"""

from __future__ import annotations

import re

#Instagram's own rule: letters, digits, full stops and underscores, up to 30.
#Handles are case insensitive, and Instagram itself shows them lowercased.
_HANDLE = re.compile(r"^[a-z0-9._]{1,30}$")

MAX_HANDLE_LENGTH = 30


def normalise_instagram_handle(raw: str | None) -> str | None:
    """Return the bare lowercase handle, or None if it cannot be one.

    None means "this is not a handle" and is for the caller to reject. It is
    NOT "the user cleared it": a handle is required and has no Clear button,
    because an account with an empty one is an account that cannot match.
    """
    if raw is None:
        return None

    value = raw.strip()
    if not value:
        return None

    #a pasted profile link: keep the first path segment after the host. Done
    #before anything else, so the query string of a share link cannot be
    #mistaken for part of the name.
    lowered = value.lower()
    if "instagram.com" in lowered:
        after_host = lowered.split("instagram.com", 1)[1]
        value = after_host.lstrip("/")

    #share links carry ?igsh=..., and someone pasting from a browser can bring
    #a #fragment with them
    value = re.split(r"[?#]", value, maxsplit=1)[0]

    #"@maria" is how people write a handle, and a trailing slash is what a URL
    #leaves behind
    value = value.strip().lstrip("@").rstrip("/").strip()
    value = value.lower()

    if not _HANDLE.match(value):
        return None
    #Instagram allows full stops inside a handle but not at either end, and
    #never two in a row. Checked separately so the error is not a regex.
    if value.startswith(".") or value.endswith(".") or ".." in value:
        return None

    return value
