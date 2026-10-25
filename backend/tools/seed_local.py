"""Fill the LOCAL database with a testable world: you, plus people to swipe on.

The feed needs candidates that survive its filters - a gender the viewer wants,
a birthday inside their age range, and photos - so a table full of half-empty
rows shows an empty deck. This makes rows that actually appear.

REFUSES TO RUN AGAINST ANYTHING BUT LOCALHOST. Seeding production would put
fake people into real users' decks, and there is no undo for a swipe someone
already made.

    cd backend
    .\\venv\\Scripts\\python.exe tools\\seed_local.py --uid <your firebase uid>

Your uid is in the Firebase console under Authentication, or in Neon:
    SELECT firebase_uid, name FROM users WHERE name = 'YourName';

Options:
    --uid UID          create/refresh your own row so the app can log in locally
    --me-latest        aim the likes at the newest real account instead, for a
                       signup whose uid you cannot know in advance
    --count N          how many fake profiles to make (default 12)
    --gender G         the gender the fakes get (default Women)
    --likes N          fakes that like you first, so swiping right is a MATCH
    --photos FILE      a tools/demo_photos.json manifest, so the fakes have
                       real faces instead of picsum scenery (for a demo video)
    --wipe             delete every fake this script made, and start over
    --production       allow a non-local DATABASE_URL; prints what it is about
                       to do, and --wipe is what undoes it

Every fake gets a plausible instagram_handle, because confirm_match only
reveals when both sides have one - a fake without a handle leaves the match
page stuck on "waiting", correctly and uselessly.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text  # noqa: E402

from database.database import SessionLocal, SQLALCHEMY_DATABASE_URL  # noqa: E402
from database import models  # noqa: E402
from instagram import normalise_instagram_handle  # noqa: E402
from university_domains import university_name_for_email  # noqa: E402

#every row this script creates carries it, so --wipe can find them again and
#nothing else is ever touched
SEED_PREFIX = "seed_"

#Names are picked to MATCH the gender being generated. A card reading "Kostas,
#Women" is noise while testing: you end up wondering whether the bug is in the
#filter or in the seed.
NAMES_BY_GENDER = {
    "Female": [
        "Maria", "Eleni", "Katerina", "Sofia", "Dimitra", "Anna", "Ioanna",
        "Christina", "Vasiliki", "Georgia", "Despina", "Marianna",
    ],
    "Male": [
        "Nikos", "Giorgos", "Kostas", "Panagiotis", "Alexandros", "Stelios",
        "Thanasis", "Petros", "Vangelis", "Michalis", "Dimitris", "Andreas",
    ],
}
#anything else (a custom gender string) falls back to both lists
ALL_NAMES = NAMES_BY_GENDER["Female"] + NAMES_BY_GENDER["Male"]

#TWO VOCABULARIES, and mixing them shows an empty deck with no error:
#  users.gender            'Male' / 'Female' / 'Non-conforming'   (who I am)
#  users.preferred_gender  'Men' / 'Women' / 'Everyone'           (who I want)
#preference_to_genders() maps the second onto the first. --gender takes either
#spelling so neither is a trap.
GENDER_ALIASES = {"women": "Female", "men": "Male", "everyone": "Female"}


def normalise_gender(value: str) -> str:
    return GENDER_ALIASES.get(value.strip().lower(), value)
JOBS = [
    "Barista at a coffee shop", "Bookshop weekends", "Waiter, sometimes",
    "Tutoring maths", "Lab assistant", "Bartender", "Freelance designer",
    None, None,
]
BIOS = [
    "Probably at the library. Probably not studying.",
    "I will beat you at tavli.",
    "Looking for someone to split a pizza with.",
    "Mountains over beaches, fight me.",
    "Chronically early. It is a problem.",
    None,
]
UNIVERSITIES = [
    "University of Patras", "Aristotle University of Thessaloniki",
    "National and Kapodistrian University of Athens", "University of Crete",
]
CITIES = ["Athens", "Thessaloniki", "Patras", "Heraklion", "Ioannina"]
MAJORS = ["Applied Informatics", "Civil Engineering", "Philosophy", "Biology",
          "Economics", "Architecture"]
INTERESTS = ["Hiking", "Jazz", "Sushi", "Gaming", "Cooking", "Reading",
             "Photography", "Running", "Cats", "Dogs", "Travel", "Coffee"]
TRAITS = ["Introvert", "Adventurous", "Calm", "Curious", "Witty", "Optimistic",
          "Night owl", "Early bird", "Leo", "INTJ"]
ALCOHOL = ["Never", "Sometimes", "Yes"]
INTENTIONS = ["Something casual", "Something serious",
              "Still figuring it out"]
KIDS = ["I'm open to kids", "I want kids", "I don't want kids",
        "Still figuring it out"]
LANGUAGES = ["Greek", "English", "German", "French", "Italian"]
STORIES = [
    "This was five minutes before it started raining.",
    "My sister took this and refuses to take a better one.",
    "Best coffee in the city, I will not be taking questions.",
    None, None,
]
#Fragments of Greek surnames, for building handles that look like handles.
#A SEEDED PROFILE WITHOUT ONE CANNOT COMPLETE A MATCH: confirm_match only
#reveals when BOTH sides have a handle, so a fake with none leaves the match
#page honestly stuck on "waiting" - which is the correct behaviour and a
#useless demo.
SURNAME_BITS = ["pap", "papadop", "nikolaou", "geo", "kontos", "vlachos",
                "stam", "dim", "karag", "mitso", "lek", "sarak"]


def guard_target(allow_production: bool) -> None:
    """Localhost, or a deliberate --production with both eyes open."""
    url = SQLALCHEMY_DATABASE_URL or ""

    #SAYS WHICH DATABASE, ALWAYS - the same rule main.py follows on startup.
    #Silence used to mean localhost, which is exactly the case you cannot
    #afford to guess at: a shell without DATABASE_URL falls back to .env, so
    #a command meant for Neon writes to the dev database and reports success.
    #Host and name only, never the password.
    print(f"database: {url.split('@')[-1] if url else 'NOT SET'}")

    #NOT THE TEST DATABASE, EITHER. Its name ends in _test and conftest drops
    #every table in it at the start of each pytest run, so anything seeded
    #here vanishes the next time the suite runs - silently, and after you have
    #spent a while wondering where the profiles went. conftest makes the
    #opposite check for the same reason.
    if url.rsplit("/", 1)[-1].split("?")[0].endswith("_test"):
        sys.exit(
            "REFUSING TO RUN.\n"
            "DATABASE_URL points at the test database. pytest drops every\n"
            "table in it on each run, so seeding it achieves nothing.\n"
            "Point DATABASE_URL at the development database instead."
        )

    if any(host in url for host in ("localhost", "127.0.0.1")):
        return

    if not allow_production:
        sys.exit(
            "REFUSING TO RUN.\n"
            "DATABASE_URL does not point at localhost, and this script writes\n"
            "fake people. Check backend/.env, and never set DATABASE_URL to\n"
            "Neon in a shell you then run this from.\n"
            "\n"
            "If a demo really has to be filmed against the deployed backend,\n"
            "pass --production and read what it prints."
        )

    #SEEDING THE REAL DATABASE IS RECOVERABLE, BUT ONLY IF YOU DO IT. Every row
    #carries SEED_PREFIX so --wipe finds it again; until that runs, these
    #profiles sit in the deck of every real account on the app.
    where = url.split("@")[-1]
    print("=" * 66)
    print("WRITING FAKE PEOPLE TO A DATABASE THAT IS NOT LOCAL")
    print(f"  {where}")
    print("")
    print("Every row created here is prefixed seed_, so this undoes it:")
    print("  python tools\\seed_local.py --production --wipe --count 0")
    print("Run it as soon as filming is done.")
    print("=" * 66)


def reset_me(db, me: models.User) -> None:
    """Undo everything I did TO the seeded profiles, and leave them standing.

    FOR A SECOND TAKE. A swipe is permanent by design - the deck never offers
    the same person twice - so rehearsing a demo burns the deck, and the only
    honest way back is to delete the swipes rather than to pretend the app
    forgets. Seeded people only: a swipe on a real account is a real decision
    and is none of this script's business.

    Notifications go first, matches second, swipes last: a notification points
    at a match (ON DELETE SET NULL), and deleting in the other order would
    leave rows pointing at nothing instead of being removed with it.
    """
    seeded = [r[0] for r in db.execute(
        text("SELECT id FROM users WHERE firebase_uid LIKE :p"),
        {"p": f"{SEED_PREFIX}%"},
    ).all()]
    if not seeded:
        print("no seeded profiles, so nothing of mine to undo")
        return

    notes = db.execute(text(
        "DELETE FROM notifications WHERE user_id = :me AND "
        "(other_user_id = ANY(:ids) OR match_id IN "
        " (SELECT id FROM matches WHERE user_a_id = ANY(:ids) OR user_b_id = ANY(:ids)))"
    ), {"me": me.id, "ids": seeded})
    matches = db.execute(text(
        "DELETE FROM matches WHERE (user_a_id = :me AND user_b_id = ANY(:ids)) "
        "OR (user_b_id = :me AND user_a_id = ANY(:ids))"
    ), {"me": me.id, "ids": seeded})
    #MINE ONLY. Their likes toward me are what puts them on the likes page,
    #and deleting those would quietly empty the screen this is meant to restore.
    swipes = db.execute(text(
        "DELETE FROM user_swipes WHERE user_id = :me AND target_id = ANY(:ids)"
    ), {"me": me.id, "ids": seeded})
    db.commit()
    print(f"undone: {swipes.rowcount} swipes, {matches.rowcount} matches, "
          f"{notes.rowcount} notifications - the deck is full again")


def newest_real_user(db) -> models.User:
    """The most recently created account that this script did not create.

    FOR THE ACCOUNT YOU JUST SIGNED UP WITH. A fresh signup's uid is not known
    until it exists, so a seeding run scheduled in advance has nothing to aim
    its likes at. The newest row that is not seed_-prefixed is that account.

    Prints who it picked, because on a database with several real accounts
    "newest" is a guess and a wrong one sends fake likes to somebody else.
    """
    me = db.query(models.User).filter(
        ~models.User.firebase_uid.like(f"{SEED_PREFIX}%")
    ).order_by(models.User.id.desc()).first()
    if not me:
        sys.exit("No real account in this database yet - sign up first.")
    print(f"aiming at the newest real account: id={me.id} name={me.name!r}")
    if not me.instagram_handle:
        print("  WARNING: it has no instagram_handle, so a match cannot "
              "complete. Fill it in on the app's setup page.")
    return me


def make_handle(name: str, index: int) -> str:
    """Something that reads like a real Instagram handle for `name`.

    Run through the app's own normaliser, so a seeded row can never hold
    something the app would have refused to store - the reveal screen builds
    an instagram.com link straight out of this.
    """
    base = name.lower()
    bit = random.choice(SURNAME_BITS)
    shapes = [
        f"{base}.{bit}",
        f"{base}_{bit}",
        f"{base}.{bit}{random.randint(1, 99)}",
        f"{base}{bit}",
        f"{base}.{bit}.gr",
    ]
    handle = normalise_instagram_handle(shapes[index % len(shapes)])
    #the shapes above are all legal, so this only ever fires on a name with
    #something unexpected in it
    return handle or f"{re.sub(r'[^a-z0-9]', '', base)}{index}"


def load_photo_sets(path: str) -> list[tuple[str, list[str]]]:
    """[(Name, [photo urls])] from a demo_photos.py manifest."""
    if not os.path.exists(path):
        sys.exit(f"{path} not found - run tools/demo_photos.py first.")
    with open(path, encoding="utf-8") as handle:
        manifest = json.load(handle)
    if not isinstance(manifest, dict) or not manifest:
        sys.exit(f"{path} is not a manifest of {{person: [urls]}}.")
    #the folder name is the first name, so 'maria' shows up as 'Maria'
    return [(person.capitalize(), urls) for person, urls in manifest.items()]


def wipe(db) -> None:
    """Remove only what this script created."""
    ids = [r[0] for r in db.execute(
        text("SELECT id FROM users WHERE firebase_uid LIKE :p"),
        {"p": f"{SEED_PREFIX}%"},
    ).all()]
    if not ids:
        print("nothing to wipe")
        return
    #swipes point at users both ways, and photos/settings cascade from users
    db.execute(text("DELETE FROM user_swipes WHERE user_id = ANY(:ids) OR target_id = ANY(:ids)"),
               {"ids": ids})
    db.execute(text("DELETE FROM matches WHERE user_a_id = ANY(:ids) OR user_b_id = ANY(:ids)"),
               {"ids": ids})
    db.execute(text("DELETE FROM users WHERE id = ANY(:ids)"), {"ids": ids})
    db.commit()
    print(f"wiped {len(ids)} seeded profiles")


def ensure_me(db, uid: str, email: str | None = None) -> models.User:
    """Your own row, so the app can load a profile against the local backend.

    PASS --email. The real signup derives `university` from the verified email
    domain (create_user -> university_name_for_email) and the app has no way to
    change it afterwards, so a row invented here with a guessed university
    shows the wrong school on your profile for as long as it exists. Without an
    email this falls back to a placeholder and says so.
    """
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if me:
        print(f"you already exist locally: id={me.id}, name={me.name}")
        #a row made before --email existed, or by an earlier run with none
        if email:
            derived = university_name_for_email(email)
            if derived and me.university != derived:
                print(f"  fixing university: {me.university!r} -> {derived!r}")
                me.university = derived
                db.commit()
        return me

    university = university_name_for_email(email) if email else None
    if university is None:
        university = "University of Patras"
        print("no --email given, so the university is a placeholder "
              f"({university}) - the app cannot change it, pass --email instead")

    me = models.User(
        firebase_uid=uid,
        name="Me",
        #'Male', NOT 'Man': preference_to_genders() maps 'Men' -> 'Male', so a
        #row saying 'Man' is invisible to everyone who is looking for men
        gender="Male",
        birthday=datetime.date(2002, 5, 1),
        height_cm=180,
        city="Patras",
        university=university,
        major="Applied Informatics",
        is_currently_studying=True,
        #without one, every match this row makes stops at "waiting" - the
        #reveal needs a handle on BOTH sides
        instagram_handle="demo.me",
        preferred_gender="Women",
        min_age_range=18,
        max_age_range=30,
        has_finished_set_up=True,
        has_photos=True,
        interest_tags=["Hiking", "Jazz"],
        trait_tags=["Introvert"],
        languages_spoken=["Greek", "English"],
    )
    db.add(me)
    db.flush()
    db.add(models.Settings(
        user_id=me.id, is_dark_mode=True,
        is_like_notifications_on=False, language="el",
    ))
    db.add(models.Photos(
        user_id=me.id,
        photo_url=f"https://picsum.photos/seed/me{me.id}/600/900",
        display_order=0,
    ))
    db.commit()
    print(f"created your local row: id={me.id} (edit it in the app)")
    return me


def make_profile(db, index: int, gender: str,
                 person: tuple[str, list[str]] | None = None) -> models.User:
    """One fake profile. `person` is (name, photo urls) from a demo manifest."""
    age = random.randint(19, 28)
    born = datetime.date.today() - datetime.timedelta(days=age * 365 + random.randint(0, 300))
    photo_count = random.randint(3, 5)
    name = person[0] if person else random.choice(
        NAMES_BY_GENDER.get(gender, ALL_NAMES))

    user = models.User(
        firebase_uid=f"{SEED_PREFIX}{index}_{random.randint(1000, 9999)}",
        name=name,
        instagram_handle=make_handle(name, index),
        gender=gender,
        birthday=born,
        height_cm=random.randint(155, 195),
        city=random.choice(CITIES),
        university=random.choice(UNIVERSITIES),
        major=random.choice(MAJORS),
        is_currently_studying=random.random() < 0.8,
        job=random.choice(JOBS),
        bio=random.choice(BIOS),
        preferred_gender="Everyone",
        min_age_range=18,
        max_age_range=35,
        has_finished_set_up=True,
        has_photos=True,
        alcohol=random.choice(ALCOHOL),
        smoking=random.choice(ALCOHOL),
        dating_intention=random.choice(INTENTIONS),
        kids=random.choice(KIDS),
        interest_tags=random.sample(INTERESTS, random.randint(3, 8)),
        trait_tags=random.sample(TRAITS, random.randint(2, 5)),
        languages_spoken=random.sample(LANGUAGES, random.randint(1, 3)),
    )
    db.add(user)
    db.flush()

    db.add(models.Settings(
        user_id=user.id, is_dark_mode=True,
        is_like_notifications_on=False, language="el",
    ))
    #CURATED PHOTOS WHEN THERE ARE ANY, in the order the manifest lists them,
    #so photo 0 is whichever portrait sorted first. Topped up to three with
    #scenery rather than with another face: the profile page is built around
    #three photos, and a second random face would make one person look like
    #two. See tools/demo_photos.py.
    if person and person[1]:
        photo_urls = list(person[1])
        while len(photo_urls) < 3:
            photo_urls.append(
                f"https://picsum.photos/seed/{user.id}_fill{len(photo_urls)}/600/900")
    else:
        #picsum needs no auth and gives a stable image per seed, so the same
        #profile keeps the same picture between runs of the app. Fine for
        #development, useless on camera - it returns scenery, not faces.
        photo_urls = [
            f"https://picsum.photos/seed/{user.id}_{order}/600/900"
            for order in range(photo_count)
        ]

    for order, photo_url in enumerate(photo_urls):
        db.add(models.Photos(
            user_id=user.id,
            photo_url=photo_url,
            display_order=order,
            #photo 0 never has a story - the profile picture cannot have one
            story=None if order == 0 else random.choice(STORIES),
        ))
    return user


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--uid", help="your Firebase uid, to create your local row")
    parser.add_argument("--email", help="your university email, so the row gets "
                                        "the same university signup would derive")
    parser.add_argument("--count", type=int, default=12)
    parser.add_argument("--gender", default="Female",
                        help="profile gender of the fakes: Male / Female / "
                             "Non-conforming ('Men'/'Women' are accepted too)")
    parser.add_argument("--likes", type=int, default=3,
                        help="how many fakes like you first (swipe right on them = match)")
    parser.add_argument("--handles",
                        help="pin a handle instead of a generated one: "
                             "--handles Katerina=katpap_. FOR A DEMO this "
                             "should be an Instagram account that exists - "
                             "the reveal screen links straight to it.")
    parser.add_argument("--liked-by",
                        help="WHICH fakes like you, by name: --liked-by "
                             "Maria,Katerina. They go on the likes page and "
                             "are kept out of the deck, so this decides where "
                             "each person shows up")
    parser.add_argument("--wipe", action="store_true",
                        help="remove previously seeded profiles first")
    parser.add_argument("--photos",
                        help="a tools/demo_photos.json manifest, so the fakes "
                             "have real faces instead of picsum scenery")
    parser.add_argument("--me-latest", action="store_true",
                        help="aim --likes at the newest non-seeded account "
                             "instead of a uid you have to know in advance")
    parser.add_argument("--reset-me", action="store_true",
                        help="delete MY swipes, matches and notifications "
                             "against the seeded profiles, so the deck is "
                             "full again for another take. Keeps the profiles "
                             "and keeps their likes toward me.")
    parser.add_argument("--production", action="store_true",
                        help="allow a non-local DATABASE_URL (prints what it "
                             "is about to do; --wipe undoes it)")
    args = parser.parse_args()

    guard_target(args.production)
    db = SessionLocal()

    if args.wipe:
        wipe(db)

    if args.me_latest:
        me = newest_real_user(db)
    elif args.uid:
        me = ensure_me(db, args.uid, args.email)
    else:
        me = None

    #BEFORE ANY SEEDING, and on its own: undoing a take is not the same job as
    #building the world, and doing both in one command is how you wipe the
    #profiles you meant to keep.
    if args.reset_me:
        if not me:
            sys.exit("--reset-me needs --uid or --me-latest to know who 'me' is.")
        reset_me(db, me)
        if not args.count:
            db.close()
            return

    #the curated people first, then random ones to fill --count out
    photo_sets = load_photo_sets(args.photos) if args.photos else []
    if len(photo_sets) > args.count:
        print(f"manifest has {len(photo_sets)} people but --count is "
              f"{args.count}; raising count to fit them all")
        args.count = len(photo_sets)

    gender = normalise_gender(args.gender)
    created = [
        make_profile(db, i, gender,
                     photo_sets[i] if i < len(photo_sets) else None)
        for i in range(args.count)
    ]
    #PINNED HANDLES, applied after creation so they override whatever
    #make_handle invented. Run through the app's normaliser for the same
    #reason the generated ones are: this ends up in an instagram.com link.
    if args.handles:
        by_name = {user.name.lower(): user for user in created}
        for pair in args.handles.split(","):
            if "=" not in pair:
                sys.exit(f"--handles wants Name=handle, got {pair!r}")
            who, _, raw = pair.partition("=")
            user = by_name.get(who.strip().lower())
            if not user:
                sys.exit(f"--handles names nobody seeded: {who.strip()!r}")
            handle = normalise_instagram_handle(raw)
            if not handle:
                sys.exit(f"{raw!r} is not a usable Instagram handle.")
            user.instagram_handle = handle
            print(f"  {user.name}'s handle pinned to @{handle}")

    db.commit()
    if photo_sets:
        print(f"created {len(created)} profiles ({gender}): "
              f"{len(photo_sets)} with your photos, "
              f"{len(created) - len(photo_sets)} with picsum")
    else:
        print(f"created {len(created)} profiles ({gender}), 3-5 photos each")

    if me and (args.likes or args.liked_by):
        #with --count 0 nothing was created this run, so borrow from the
        #profiles already seeded - otherwise --likes would silently do nothing
        likers = created or db.query(models.User).filter(
            models.User.firebase_uid.like(f"{SEED_PREFIX}%")
        ).all()

        #BY NAME WHEN IT MATTERS WHICH ONES. --likes takes the first N, which
        #is fine for development and useless when you are arranging a
        #particular screen: whoever likes you is kept OUT of the deck (see
        #get_swipe_feed), so this flag is really choosing who appears on the
        #likes page instead of in the feed.
        if args.liked_by:
            wanted = [name.strip().lower()
                      for name in args.liked_by.split(",") if name.strip()]
            by_name = {user.name.lower(): user for user in likers}
            missing = [name for name in wanted if name not in by_name]
            if missing:
                sys.exit(f"--liked-by names nobody seeded: {', '.join(missing)}\n"
                         f"seeded: {', '.join(sorted(by_name))}")
            chosen = [by_name[name] for name in wanted]
        else:
            chosen = likers[: args.likes]

        for user in chosen:
            db.add(models.UserSwipes(user_id=user.id, target_id=me.id, action="like"))
        db.commit()
        print(f"{len(chosen)} of them already liked you - swipe right to match:")
        for user in chosen:
            print(f"  {user.name} (id {user.id})  @{user.instagram_handle}")

    total = db.query(models.User).count()
    print(f"\nlocal database now holds {total} users")
    db.close()


if __name__ == "__main__":
    main()
