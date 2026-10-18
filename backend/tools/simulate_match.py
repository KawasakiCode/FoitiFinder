"""Make a seeded fake like you back and answer, so you can test YOUR side.

WHY THIS IS NOT A POSTMAN REQUEST. Every endpoint takes identity from a
Firebase ID token and nothing else - that is the point of the auth design. A
seeded profile has a made-up firebase_uid, no Firebase account, no password and
therefore no token, so there is no way to act "as" one over HTTP. The only
honest way to play the other side is to write it into the database, which is
what this does - by calling the real endpoint functions, so the rules (who gets
notified, what reveals a handle) are the live ones rather than a second
implementation that can drift.

REFUSES TO RUN AGAINST ANYTHING BUT LOCALHOST.

    cd backend
    .\\venv\\Scripts\\python.exe tools\\simulate_match.py --uid <your firebase uid>

What it does, in the order the app would:

    --stage waiting   (default)
        the fake likes you back, which creates the match, and confirms it.
        You are left as the side that has NOT answered: a 'match' notification
        in your bell, and the match page asks you to decide. This is the half
        of the flow the app cannot reach on its own.

    --stage revealed
        the same, except YOU confirm first and the fake answers second. You
        are left with a 'match_revealed' notification and their handle waiting
        behind it - what the completer sees when the other side says yes hours
        later.

It needs someone you have already liked in the app, since a match the two of
you never both wanted is not a match. Like a profile first, then run this.
"""

from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text  # noqa: E402

from database.database import SessionLocal, SQLALCHEMY_DATABASE_URL  # noqa: E402
from database import models  # noqa: E402
import main  # noqa: E402

#a handle the fake can hand over: the reveal only completes when BOTH sides
#have one (see confirm_match), and seeded rows have none
FAKE_HANDLE = "seeded_profile"


def guard_localhost() -> None:
    url = SQLALCHEMY_DATABASE_URL or ""
    if not any(host in url for host in ("localhost", "127.0.0.1")):
        sys.exit(
            "REFUSING TO RUN.\n"
            "DATABASE_URL does not point at localhost. This writes swipes,\n"
            "matches and notifications as though another person had acted -\n"
            "against production that is a fake match sent to a real user."
        )


def pick_target(db, me: models.User, target: str | None) -> models.User:
    """Someone I have liked who has not liked me back yet."""
    liked_ids = [
        row[0] for row in db.query(models.UserSwipes.target_id).filter(
            models.UserSwipes.user_id == me.id,
            models.UserSwipes.action.in_(["like", "super_like"]),
        ).all()
    ]
    if not liked_ids:
        sys.exit("You have not liked anyone yet - swipe right in the app first.")

    candidates = db.query(models.User).filter(models.User.id.in_(liked_ids)).all()
    if target:
        for user in candidates:
            if str(user.id) == target or user.name.lower() == target.lower():
                return user
        sys.exit(
            f"{target!r} is not someone you have liked. You have liked: "
            + ", ".join(f"{u.name} (id {u.id})" for u in candidates)
        )

    #prefer one with no match yet, so repeated runs do not fight over the same
    #row
    for user in candidates:
        exists = db.execute(text(
            "SELECT 1 FROM matches WHERE (user_a_id=:a AND user_b_id=:b) "
            "OR (user_a_id=:b AND user_b_id=:a)"
        ), {"a": me.id, "b": user.id}).first()
        if not exists:
            return user
    return candidates[0]


def main_() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--uid", required=True, help="YOUR firebase uid")
    parser.add_argument("--target", help="name or id of a profile you liked "
                                        "(default: the first one without a match)")
    parser.add_argument("--stage", choices=["waiting", "revealed"],
                        default="waiting",
                        help="waiting: they answer first, you decide. "
                             "revealed: you answer first, they answer second.")
    args = parser.parse_args()

    guard_localhost()
    db = SessionLocal()

    me = db.query(models.User).filter(models.User.firebase_uid == args.uid).first()
    if not me:
        sys.exit(f"No local user with firebase_uid {args.uid!r} - run seed_local.py --uid first.")
    if not me.instagram_handle:
        sys.exit("Your row has no instagram_handle, so nothing can be exchanged. "
                 "Fill it in on the app's setup page first.")

    them = pick_target(db, me, args.target)
    print(f"you: id={me.id} {me.name}   them: id={them.id} {them.name}")

    #1. the handle they will hand over
    if not them.instagram_handle:
        them.instagram_handle = FAKE_HANDLE
        print(f"  gave them a handle: @{FAKE_HANDLE}")

    #2. their like, which is what completes the match
    swipe = db.query(models.UserSwipes).filter(
        models.UserSwipes.user_id == them.id,
        models.UserSwipes.target_id == me.id,
    ).first()
    if swipe:
        swipe.action = "like"
    else:
        db.add(models.UserSwipes(user_id=them.id, target_id=me.id, action="like"))
    db.commit()
    print("  they liked you back")

    #3. the match row, exactly as record_swipe creates it (the person who
    #completes the match is user_a)
    match = db.execute(text(
        "SELECT id FROM matches WHERE (user_a_id=:a AND user_b_id=:b) "
        "OR (user_a_id=:b AND user_b_id=:a)"
    ), {"a": me.id, "b": them.id}).first()
    if match:
        match_id = match[0]
        print(f"  match {match_id} already existed")
    else:
        row = models.Matches(user_a_id=them.id, user_b_id=me.id)
        db.add(row)
        db.commit()
        match_id = row.id
        print(f"  created match {match_id}")

    #4. the confirmations, through the real endpoint so the notifications and
    #the reveal rules are the live ones
    if args.stage == "revealed":
        print("  you confirm first:", main.confirm_match(match_id, me.firebase_uid, db))
        print("  they confirm:     ", main.confirm_match(match_id, them.firebase_uid, db))
    else:
        print("  they confirm:     ", main.confirm_match(match_id, them.firebase_uid, db))

    notes = db.query(models.Notifications).filter(
        models.Notifications.user_id == me.id
    ).order_by(models.Notifications.id.desc()).limit(3).all()
    print("\nyour bell now holds:")
    for note in notes:
        state = "read" if note.read_at else "UNREAD"
        print(f"  {note.kind:16} match={note.match_id}  {state}")

    print("\nOpen the app and tap the bell. A push was attempted as well - it "
          "reaches you only if your FCM token is in Firestore, which the in-app "
          "list deliberately does not depend on.")
    db.close()


if __name__ == "__main__":
    main_()
