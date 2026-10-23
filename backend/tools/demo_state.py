"""What the server thinks is true about you, right now. Reads, never writes.

FOR WHEN THE APP DOES SOMETHING AND YOU CANNOT SEE WHY. A notification that
does not open, a deck that is shorter than it should be, a person who appears
twice - all three are decided by rows you cannot see from the phone, and
guessing at them from the UI is how an evening disappears.

It prints, in the order the app would care about:

    your profile and the preferences the feed filters on
    every seeded profile, with the reason the feed would keep or drop it
    your swipes
    your matches, with both confirmation timestamps
    your notifications, with `actionable` computed the SAME WAY the endpoint
        computes it - so a row that will not open here will not open there

    cd backend
    .\\venv\\Scripts\\python.exe tools\\demo_state.py --uid <your firebase uid>
"""

from __future__ import annotations

import argparse
import datetime
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text  # noqa: E402

from ages import age_from_birthday, years_ago  # noqa: E402
from database.database import SessionLocal, SQLALCHEMY_DATABASE_URL  # noqa: E402
from database import models  # noqa: E402
from preferences.preferences import preference_to_genders  # noqa: E402

SEED_PREFIX = "seed_"


def feed_verdict(me: models.User, them: models.User) -> str:
    """Why the feed would show or hide this person - the same rules as
    get_swipe_feed, written out one at a time so the answer names itself."""
    if them.id == me.id:
        return "DROPPED: that is you"

    wanted = preference_to_genders(me.preferred_gender)
    if wanted is not None and them.gender is not None and them.gender not in wanted:
        return (f"DROPPED: gender {them.gender!r} is not in your "
                f"{me.preferred_gender!r} ({', '.join(wanted)})")

    if them.birthday is not None:
        if me.min_age_range is not None and them.birthday > years_ago(me.min_age_range):
            return (f"DROPPED: age {age_from_birthday(them.birthday)} is under "
                    f"your minimum of {me.min_age_range}")
        if me.max_age_range is not None and them.birthday <= years_ago(me.max_age_range + 1):
            return (f"DROPPED: age {age_from_birthday(them.birthday)} is over "
                    f"your maximum of {me.max_age_range}")

    return "shown"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--uid", required=True, help="your Firebase uid")
    args = parser.parse_args()

    db = SessionLocal()
    where = (SQLALCHEMY_DATABASE_URL or "").split("@")[-1]
    print(f"database: {where}\n")

    me = db.query(models.User).filter(models.User.firebase_uid == args.uid).first()
    if not me:
        sys.exit(f"No user with firebase_uid {args.uid!r} in THIS database. "
                 "That is also what would make the app sign you out.")

    print("=" * 70)
    print(f"YOU: id={me.id}  {me.name!r}  gender={me.gender!r}  "
          f"age={age_from_birthday(me.birthday)}")
    print(f"     wants {me.preferred_gender!r}, ages "
          f"{me.min_age_range}-{me.max_age_range}, handle=@{me.instagram_handle}")
    print("=" * 70)

    swiped = {
        row.target_id: row.action
        for row in db.query(models.UserSwipes).filter(
            models.UserSwipes.user_id == me.id).all()
    }
    liked_me = {
        row.user_id: row.action
        for row in db.query(models.UserSwipes).filter(
            models.UserSwipes.target_id == me.id,
            models.UserSwipes.action.in_(["like", "super_like"])).all()
    }

    print("\nSEEDED PROFILES, and where each one lands:")
    seeded = db.query(models.User).filter(
        models.User.firebase_uid.like(f"{SEED_PREFIX}%")).order_by(models.User.id).all()
    if not seeded:
        print("  none - nothing has been seeded into this database")
    in_feed = 0
    for them in seeded:
        photos = db.query(models.Photos).filter(models.Photos.user_id == them.id).count()
        verdict = feed_verdict(me, them)
        if them.id in liked_me:
            where_ = "LIKES PAGE (they liked you, so the deck must not offer them)"
        elif them.id in swiped:
            where_ = f"GONE: you already swiped {swiped[them.id]!r}"
        elif verdict != "shown":
            where_ = verdict
        else:
            where_ = "FEED"
            in_feed += 1
        print(f"  id={them.id:<4} {them.name:<10} age={age_from_birthday(them.birthday):<3} "
              f"{photos} photos  @{them.instagram_handle or '-':<18} {where_}")
    print(f"\n  -> the feed can offer {in_feed} profile(s)")

    print("\nYOUR MATCHES:")
    matches = db.query(models.Matches).filter(
        (models.Matches.user_a_id == me.id) | (models.Matches.user_b_id == me.id)
    ).order_by(models.Matches.id).all()
    if not matches:
        print("  none")
    for match in matches:
        i_am_a = match.user_a_id == me.id
        other_id = match.user_b_id if i_am_a else match.user_a_id
        other = db.query(models.User).filter(models.User.id == other_id).first()
        mine = match.a_confirmed_at if i_am_a else match.b_confirmed_at
        theirs = match.b_confirmed_at if i_am_a else match.a_confirmed_at
        state = ("REVEALED (both said yes)" if mine and theirs
                 else "waiting on THEM" if mine
                 else "waiting on YOU" if theirs
                 else "neither has answered")
        print(f"  match {match.id}: with {other.name if other else '???'} "
              f"(id {other_id}) - you are user_{'a' if i_am_a else 'b'}")
        print(f"    yours={mine}  theirs={theirs}  -> {state}")

    by_id = {match.id: match for match in matches}

    print("\nYOUR NOTIFICATIONS (newest first), with why each one opens or does not:")
    notes = db.query(models.Notifications).filter(
        models.Notifications.user_id == me.id
    ).order_by(models.Notifications.created_at.desc()).limit(20).all()
    if not notes:
        print("  none")
    for note in notes:
        match = by_id.get(note.match_id) if note.match_id else None

        #the endpoint's own rule, repeated here rather than imported, because
        #it closes over `me` - keep the two in step
        if match is None:
            actionable, why = False, "match_id is null or the match is gone"
        elif note.kind == "match":
            mine = (match.a_confirmed_at if match.user_a_id == me.id
                    else match.b_confirmed_at)
            actionable = mine is None
            why = ("you have not answered yet" if actionable
                   else f"you already answered at {mine}")
        elif note.kind == "match_revealed":
            actionable, why = True, "a reveal is always reopenable"
        else:
            actionable, why = False, f"{note.kind} is a statement, not a link"

        can_open = actionable and note.match_id is not None and note.other_user_id is not None
        if not can_open and actionable:
            why += " BUT match_id/other_user_id is null, so the app will not open it"

        read = "read" if note.read_at else "UNREAD"
        print(f"  [{note.id}] {note.kind:<16} match={note.match_id} "
              f"other={note.other_user_id} {read}  {note.created_at:%Y-%m-%d %H:%M}")
        print(f"      tapping it {'OPENS the match page' if can_open else 'DOES NOTHING'}"
              f"  ({why})")

    db.close()


if __name__ == "__main__":
    main()
