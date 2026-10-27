"""What every backend test runs against: a real Postgres, and no Firebase.

TWO THINGS MADE THIS LOOK HARD, and neither of them is.

THE DATABASE IS REAL, because it has to be. The models use Postgres arrays and
a migration calls array_replace, so SQLite cannot stand in - and a test that
passes against a different engine than production is worse than no test at
all. So there is a second database, foitifinder_test, built by the real
migrations. Every test runs inside a transaction that is ROLLED BACK
afterwards, so the database is empty again between tests and nothing is ever
actually written. Endpoints still call db.commit() - that commits a savepoint
inside the test's transaction, and the outer rollback takes it with it.

FIREBASE IS NOT NEEDED AT ALL. Identity comes from one FastAPI dependency, and
a dependency can be replaced:

    app.dependency_overrides[verified_email_uid] = lambda: "uid-alice"

That is the whole trick, and the reason it works is that identity was put in a
dependency rather than read inline in each endpoint. Tests act as a user by
swapping that uid, with no token, no network and no key file. Pushes are
replaced by a recorder, so a test can assert that somebody WOULD have been
notified without touching Firestore.

THE GUARD AT THE TOP IS NOT PARANOIA. These fixtures create tables and roll
back transactions; pointed at foitifinder_db they would wreck the seeded world
the app is developed against, and pointed at Neon they would be unrecoverable.
A test database is required to be local and to be named like one.
"""

from __future__ import annotations

import os
import sys

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BACKEND)

import pytest  # noqa: E402
from alembic import command  # noqa: E402
from alembic.config import Config  # noqa: E402
from sqlalchemy import create_engine, text  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402


def _test_database_url() -> str:
    """The test database, derived from the dev one so no password lives here."""
    explicit = os.getenv("TEST_DATABASE_URL")
    if explicit:
        url = explicit
    else:
        #read straight from backend/.env, WITHOUT importing database.py yet:
        #that module builds its engine at import time from DATABASE_URL, and
        #the whole point is to set that variable first.
        from dotenv import dotenv_values

        dev = dotenv_values(os.path.join(BACKEND, ".env")).get("DATABASE_URL")
        if not dev:
            pytest.exit("No DATABASE_URL in backend/.env and no TEST_DATABASE_URL set")
        url = dev.rsplit("/", 1)[0] + "/foitifinder_test"

    if not any(host in url for host in ("localhost", "127.0.0.1")):
        pytest.exit("REFUSING TO RUN: the test database must be on this machine")
    if not url.rsplit("/", 1)[-1].endswith("_test"):
        pytest.exit("REFUSING TO RUN: the database name must end in _test")
    return url


#SET BEFORE ANY APP IMPORT. database.py captures DATABASE_URL when it is first
#imported, and load_dotenv does not override an existing variable - so setting
#it here is what points the whole application, engine and all, at the test
#database for the length of the run.
TEST_DATABASE_URL = _test_database_url()
os.environ["DATABASE_URL"] = TEST_DATABASE_URL

import main  # noqa: E402
import notifications as notification_service  # noqa: E402
from auth import current_uid, verified_claims, verified_email_uid  # noqa: E402
from database import models  # noqa: E402
from database.database import Base, get_db  # noqa: E402

#IMPORTED FROM WHERE THEY LIVE, not through main. A dependency override is
#keyed by the function OBJECT, so it has to be the same one the routers
#depend on - reaching for main.verified_email_uid worked only while
#everything was in one file, and silently stopped overriding anything the
#moment auth.py existed.
IDENTITY_DEPENDENCIES = (verified_email_uid, current_uid)


@pytest.fixture(scope="session")
def engine():
    """One engine for the run, with the schema built by the real migrations."""
    eng = create_engine(TEST_DATABASE_URL)

    #BUILT BY THE REAL MIGRATIONS, not from the models.
    #
    #This used to be create_all, because the chain could not run from an empty
    #database: its base revision ALTERED a photos table no migration ever
    #created, since the original schema was made with create_all and alembic
    #was adopted afterwards with no baseline. Squashing the chain fixed that,
    #and this is the payoff - every test run now also proves that `upgrade
    #head` produces the schema the tests then rely on, which matters because
    #migrations are the only thing that ever touches production.
    #
    #DROPPED FIRST, NOT LAST. Dropping at the end left the database with no
    #tables at all between runs, which looks broken in pgAdmin and makes the
    #schema impossible to inspect. Dropping at the START gives the same
    #guarantee - no run ever tests against last week's columns - and leaves
    #the schema sitting there afterwards to look at.
    #
    #alembic_version goes too: left behind, it still names the old head and
    #`upgrade head` would decide there was nothing to do and hand the tests an
    #empty database.
    Base.metadata.drop_all(bind=eng)
    with eng.begin() as connection:
        connection.execute(text("DROP TABLE IF EXISTS alembic_version"))

    alembic_config = Config(os.path.join(BACKEND, "alembic.ini"))
    alembic_config.set_main_option("script_location",
                                   os.path.join(BACKEND, "alembic"))
    alembic_config.set_main_option("sqlalchemy.url", TEST_DATABASE_URL)
    command.upgrade(alembic_config, "head")

    yield eng
    eng.dispose()


@pytest.fixture
def db(engine) -> Session:
    """A session whose every write is rolled back when the test ends.

    join_transaction_mode="create_savepoint" is what makes this survive the
    endpoints: they commit, and a commit inside this session only releases a
    savepoint, leaving the outer transaction - and the rollback below - in
    charge.
    """
    connection = engine.connect()
    transaction = connection.begin()
    session = Session(bind=connection, join_transaction_mode="create_savepoint")

    yield session

    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def pushes(monkeypatch) -> list[tuple[str, str]]:
    """Every notification the code tried to push, instead of pushing it.

    A list of (firebase_uid, kind). Tests assert on who WOULD have been told,
    which is the part that carries the design decisions - "whoever was waiting
    gets told, nobody else" is a rule about this list.
    """
    sent: list[tuple[str, str]] = []

    #match_id IS ACCEPTED AND NOT RECORDED. The rules this list exists for are
    #about WHO is told and of what - "whoever was waiting gets told, nobody
    #else" - and folding a third field into the tuples would rewrite every
    #assertion in the suite to say nothing new. That the id reaches the data
    #payload is checked in test_push_gating, against the real sender.
    def record(target_uid, notification_type, _db_firestore, match_id=None):
        sent.append((target_uid, notification_type))

    #PATCHED WHERE IT IS CALLED FROM. notifications.notify looks the name up
    #in its own module, so that is the namespace to replace - patching a
    #module that merely imported it would leave the real one in use.
    monkeypatch.setattr(notification_service, "send_smart_notification", record)
    return sent


@pytest.fixture
def client(db, pushes):
    """A TestClient wired to the test session, signed in as nobody in
    particular - use `as_user` to choose.
    """
    from fastapi.testclient import TestClient

    main.app.dependency_overrides[get_db] = lambda: db
    #BOTH identity dependencies, because there are two: verified_email_uid
    #additionally refuses an unverified email, and current_uid does not - the
    #endpoints reachable before verification use the second. Overriding one
    #leaves the other evaluating HTTPBearer, which answers "Not authenticated"
    #for a request that has no token, which a test never has.
    #
    #The default uid belongs to nobody, so forgetting as_user() fails loudly
    #rather than silently acting as some other test's user.
    for dependency in IDENTITY_DEPENDENCIES:
        main.app.dependency_overrides[dependency] = lambda: "uid-unset"

    with TestClient(main.app) as test_client:
        yield test_client

    main.app.dependency_overrides.clear()


@pytest.fixture
def as_user(client):
    """Call the API as this user: `as_user(alice)`.

    Swapping it mid-test is how both halves of a match get tested, which is
    the thing that cannot be done over HTTP in real life - a seeded profile
    has no Firebase account and therefore no token.
    """

    def _as(user: models.User):
        for dependency in IDENTITY_DEPENDENCIES:
            main.app.dependency_overrides[dependency] = lambda: user.firebase_uid
        #the raw claims too, for the endpoints that read the email out of the
        #token rather than the database (signup is the only one, but a test
        #that switches users must not leave the previous one's claims behind)
        main.app.dependency_overrides[verified_claims] = lambda: {
            "uid": user.firebase_uid,
            "email": f"{user.firebase_uid}@uom.edu.gr",
            "email_verified": True,
        }
        return client

    return _as


@pytest.fixture
def as_signup(client):
    """Call the API as somebody who has a token but no row yet.

    SIGNUP IS THE ONE ENDPOINT THAT READS THE TOKEN ITSELF, because the email
    is in the claims and never in the body - that is what makes the university
    check unforgeable. So a test of it has to supply claims rather than a user.
    """

    def _as(uid: str, email: str | None, email_verified: bool = True):
        claims = {"uid": uid, "email": email, "email_verified": email_verified}
        main.app.dependency_overrides[verified_claims] = lambda: claims
        for dependency in IDENTITY_DEPENDENCIES:
            main.app.dependency_overrides[dependency] = lambda: uid
        return client

    return _as


@pytest.fixture
def make_user(db):
    """A user that the feed and the match flow will actually accept.

    Half-filled rows are why a test suite grows fixtures: a profile with no
    birthday, no gender or no photo silently fails the feed's filters, and the
    resulting empty list looks like a bug in the code under test.
    """
    import datetime

    made = {"n": 0}

    def _make(
        name: str = "Someone",
        gender: str = "Female",
        preferred_gender: str = "Everyone",
        age: int = 21,
        handle: str | None = "a_handle",
        photos: int = 1,
        **extra,
    ) -> models.User:
        made["n"] += 1
        index = made["n"]
        #defaults a caller can override: `make_user(min_age_range=20)` has to
        #win, and passing the same keyword twice is a TypeError
        extra.setdefault("min_age_range", 18)
        extra.setdefault("max_age_range", 99)
        user = models.User(
            firebase_uid=f"uid-test-{index}",
            name=name,
            gender=gender,
            birthday=datetime.date.today() - datetime.timedelta(days=age * 365 + 10),
            preferred_gender=preferred_gender,
            has_finished_set_up=True,
            has_photos=photos > 0,
            instagram_handle=handle,
            university="University of Macedonia",
            **extra,
        )
        db.add(user)
        db.flush()
        for order in range(photos):
            db.add(models.Photos(
                user_id=user.id,
                photo_url=f"https://example.com/{user.id}_{order}.jpg",
                display_order=order,
            ))
        db.flush()
        return user

    return _make


@pytest.fixture
def swipe(db):
    """`swipe(a, b, "like")` - what someone did, without going through HTTP."""

    def _swipe(actor: models.User, target: models.User, action: str = "like",
               at=None):
        #`at` matters for the likes page, whose whole question is which of two
        #swipes came first. EVERY ROW IN ONE TRANSACTION OTHERWISE SHARES A
        #TIMESTAMP: Postgres now() is transaction-stable, so without this two
        #swipes made in the same test are simultaneous and "newer than" is
        #never true.
        row = models.UserSwipes(
            user_id=actor.id, target_id=target.id, action=action,
        )
        if at is not None:
            row.timestamp = at
        db.add(row)
        db.flush()

    return _swipe


@pytest.fixture(autouse=True)
def _assert_test_database(db):
    """Belt and braces: every test asserts, once, that it is not on the real
    database. Cheap, and the one mistake here is unrecoverable.
    """
    name = db.execute(text("select current_database()")).scalar()
    assert name.endswith("_test"), f"running against {name}!"
