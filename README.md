## FoitiFinder

**FoitiFinder** is a dating app for Greek university students. Account creation is gated on a **verified university email address** — the backend checks the address against the registrable root domains of all 24 Greek public universities, and it reads that address from the verified Firebase token rather than from the request body, so the rule cannot be bypassed by calling the API directly.

It has **no chat**. A mutual like opens a one-time exchange: both sides confirm, and only then does each receive the other's Instagram handle. That single decision shapes most of the system — there is no inbox to find a connection in later, so every path that hands a handle over, or that could destroy the only record of one, is guarded on the server rather than in the UI.

A Flutter app (`lib/`), a FastAPI + PostgreSQL backend (`backend/`), and Firebase for identity, photo storage and push. 251 tests (152 backend, 99 widget/unit).

### 🎥 Demo

[![Watch the FoitiFinder demo](https://img.youtube.com/vi/nyg57k5ma9A/hqdefault.jpg)](https://youtu.be/nyg57k5ma9A) 

> ▶️ **[Watch the full demo on YouTube](https://youtu.be/nyg57k5ma9A)**

> The video is from an earlier build and does not yet show matching, the notification bell or the Instagram exchange.

---

## What it does

**Discovery**
* Physics-based swipe deck — drag, rotation and velocity, with **Like** (right), **Pass** (left) and **Super Like** (up), live "like/pass" stamps that track drag distance, and background cards that interpolate position and scale as you drag.
* A sliding-window buffer: 20 cards per fetch, refilled at 10 remaining, with a 5-deep history for rewind.
* Photos for the top two cards are pre-cached before they are needed.
* Tapping a card opens the full profile in a shared-element transition: the photo, the six stat pills and the action buttons all fly to their new positions rather than cutting.

**Matching**
* A like you have received never appears in the deck — it lives on the Likes page, where you can see the whole profile before deciding.
* A mutual like creates a match and opens the match page, which asks each side to confirm before anything is exchanged.
* A notification bell in the app bar of every main page, backed by a `notifications` table rather than by push alone.

**Profiles**
* 3–6 photos (enforced server side, not just in the picker), each with an optional "story" caption.
* Bio, interests from a curated catalogue, education, languages, occupation, location by Greek prefecture, pronouns, height, and single-answer fields for religion, politics, smoking, drinking and kids.
* Date preferences: gender, age range and height range, applied as query filters on the feed.

**Shell**
* `IndexedStack` tab shell that preserves per-tab state, with `PopScope` handling in-tab history before the app exits.
* Material 3 light/dark themes, English and Greek (`.arb`), preferences persisted in `SharedPreferences`.
* Firebase App Check (Play Integrity in release, debug provider in debug builds) so the API only answers this app.

---

## How it's built

```
Flutter app                      FastAPI backend                 Managed services
-----------                      ---------------                 ----------------
pages/      screens              auth.py      who is calling --> Firebase Auth
widgets/    shared UI            routers/     20 endpoints        (ID token verify)
providers/  Provider state       database/    SQLAlchemy models
services/   api + swipe queue    notifications.py  push+record -> FCM / Firestore
models/     json <-> dart                                         Firebase Storage
                                 alembic/     19 migrations   --> PostgreSQL
    |                                   ^                          (Neon in prod)
    |   https, Bearer <firebase id token>|
    +------------------------------------+
```

The app talks to the backend over HTTPS and never to the database. Every request carries a Firebase ID token; the backend verifies it and takes the caller's identity from the verified claims. Firebase Storage holds the photos (the app uploads directly and sends the backend only the URL), and FCM delivers pushes, with the device token kept in Firestore.

Deployed on Render (backend) and Neon (Postgres), with `/health` as a database-free keep-alive target — see the note in `backend/main.py` for why it must not open a connection.

---

## Engineering decisions worth reading

These are the ones where the obvious implementation was wrong, and the code says why in place. If you only want to read a few files: `backend/auth.py`, `lib/services/swipe_queue.dart`, `backend/routers/matches.py`, `backend/database/models.py`.

**Identity comes from the token and from nowhere else.** A Firebase UID is an identifier, not a credential — an endpoint that accepts one from a path or body lets anyone act as anyone whose uid they know. Three dependencies in `auth.py` are the only source of "who is calling": `verified_claims` verifies the JWT, `verified_email_uid` additionally requires a verified email (every endpoint except account creation and `GET /users/me`, both of which have to work *before* verification), and `current_uid` for the rest. Putting it in a dependency is also what makes the whole backend testable without Firebase — see Testing.

**A swipe is delivered, not just sent.** The deck animates first and registers after, which is right (a card must never wait on the network) but means a failed request has no card left to put back; by the time a timeout returns, the user has swiped past two more people. So `SwipeQueue` retries, and the retry policy is three rules rather than a count: only retry what retrying can fix (network, timeout, 5xx, 429, 401 — any other 4xx is a refusal that will not change), two quick retries before it stops blocking, then park it on disk and retry on *events* (launch, resume, any successful swipe) rather than on a timer, giving up by age rather than by attempt count. This is only safe because `POST /swipes` reads the existing row and writes only when the action changed, so the same swipe sent ten times is one row — and the notifications it can produce are guarded the same way. Without that, a retry queue is a duplicate-match generator.

**Whoever liked you is not in your deck.** Not to preserve a surprise: a card in the deck can be passed with a flick, and that pass is written with a newer timestamp than their like, which is exactly what stops the likes query from ever surfacing them again. The deck could silently consume a guaranteed match the user was never told was on offer. Two composite indexes on `user_swipes` — `(user_id, target_id)` for "what have I done" and `(target_id, action)` for "who liked me" — carry the exclusion; the table previously had an index on `id` only, which nothing filters on.

**Notifications are a table, because a push is only a nudge.** Most of the bell is derivable from `matches` — one side confirmed is "your turn", both confirmed is "you are connected". A *decline* is not: it deletes the match, so the only record that it happened would be a push that may never arrive and can be swiped away. Stored, the app can be told the truth on next launch whatever FCM did. Likes deliberately stay out of the bell (they have their own page and badge); only things that need an answer, or carry the answer to one.

**A completed match cannot be undone.** Once both sides have confirmed, the handles have been read, and nothing can take back something somebody has already seen — so `POST /matches/{id}/decline` answers 409 on a revealed match instead of deleting the row. This was a real bug: reopening an already-answered notification put a decline button in front of the user and destroyed a finished match. The fix is in three places at once, which is the point — the server refuses it, the server computes an `actionable` flag so the client knows the row is no longer a link, and a widget test pins the flag's effect.

**Declining tells exactly one person.** Declining as the side that *completed* the match tells the other side nothing: they were never informed a match existed, so "someone matched with you and then changed their mind" would be news of a rejection they could not have seen coming. Declining when the other side is already waiting on an answer is different — they get told, and the notification deliberately carries no `match_id`, because the row it would point at has just been deleted.

**What a profile endpoint leaves out.** `GET /users/{id}/profile` builds its response field by field rather than serialising the model: no email, no `firebase_uid`, no preferences, and no `instagram_handle`. A column added to `User` cannot leak through it by default — somebody has to add a line. The handle crosses between two users in `confirm_match` and nowhere else, and only when both of them have asked for it.

**One cache key per photo.** The same image was being requested three ways (decoded at 800px, undecoded, and through a bare `NetworkImage`), so moving from the deck to the profile page was a cache miss that flashed the placeholder over a photo already on screen. `profilePhotoProvider()` is now the only way the app builds an image provider, with one decode width for full-screen and one for thumbnails — `memCacheWidth` is part of the provider's identity, so "the same photo at a different decode width" is a different cache entry.

**Shared-element transitions that survive the overlay.** Hero flights are painted in an `OverlayEntry` above every route, so no page widget can draw on top of one — which is why the name/age pills used to vanish on tap and the stat container slid *under* the photo. The photo, its scrim and its pills are one Hero with a custom `flightShuttleBuilder`, so they fly together, and the body slide is driven by the route animation rather than by a local controller (a pushed route is parked offstage for one frame, during which `ModalRoute.animation` reports itself complete — which is why a status listener never fired).

---

## The data model

Six tables, 19 Alembic migrations.

| table | holds |
| --- | --- |
| `users` | profile, preferences, `firebase_uid`, `instagram_handle`, `university` (derived from the verified email, not client-writable) |
| `photos` | one row per photo with `display_order` (0 is the profile picture) and an optional story caption |
| `user_swipes` | `(user_id, target_id, action, timestamp)` — the deck's exclusion list, the likes page, and the match check, all from one table |
| `matches` | the two participants plus `a_confirmed_at` / `b_confirmed_at`: mutual likes make the row, these two columns decide whether anything is exchanged |
| `notifications` | what the bell shows; `match_id` is `ON DELETE SET NULL` so a notification outlives the match it pointed at |
| `settings` | per-user app settings |

Age is **derived, never stored** — `birthday` is the column, and the feed's age filter is expressed as birthday cutoffs rather than age comparisons, so the comparison stays index-usable and nobody's age goes stale.

---

## API surface

20 endpoints plus `/health`. Every one of the 20 takes identity from the token; none takes a uid as a parameter.

| endpoint | what it does |
| --- | --- |
| `POST /users/` | create an account — re-checks the university domain server side |
| `GET` `PATCH` `DELETE /users/me` | own row; `PATCH` treats `""` as "clear this" and `null` as "leave alone" |
| `GET` `PATCH /users/settings` | app settings |
| `GET /users/feed` | the deck: excludes self, everyone already swiped, and everyone who liked you |
| `GET /users/{id}/profile` · `GET /single/user/{id}` | another user, field by field, without the handle |
| `GET` `POST /photos` · `PUT /photos/sync` · `PUT /photos/story` | photo rows; `sync` replaces the set and enforces 3–6 |
| `POST /swipes` | records a swipe, creates the match when it completes one, idempotent |
| `GET /likes` | who liked you, including anyone whose like is newer than your pass |
| `GET /matches` · `POST /matches/{id}/confirm` · `POST /matches/{id}/decline` | the exchange; `confirm` is idempotent, `decline` is 409 once revealed |
| `GET /notifications` · `POST /notifications/{id}/read` | the bell |
| `GET /health` | keep-alive; touches nothing |

`main.py` includes the routers in a load-bearing order: FastAPI matches routes in registration order, so `/users/me` must be registered before `/users/{user_id}/profile`, or "me" is read as a user id.

---

## Testing

**152 backend tests** (`backend/tests/`) run against a **real PostgreSQL**, not SQLite — the models use Postgres arrays and a migration calls `array_replace`, and a test that passes against a different engine than production is worse than no test. Each test runs on a connection inside an outer transaction with a `join_transaction_mode="create_savepoint"` session, rolled back afterwards: endpoints call `db.commit()` as normal, that commits a savepoint, and the rollback takes it with it. The database is therefore empty between tests and nothing is ever written.

**No Firebase is needed at all**, because identity is a dependency and a dependency can be replaced:

```python
app.dependency_overrides[verified_email_uid] = lambda: "uid-alice"
```

Tests act as a user by swapping that uid — no token, no network, no key file. Pushes go to a recorder, so a test can assert that somebody *would* have been notified. `conftest.py` refuses to run against anything that is not a local database named like a test one.

The suites cover the full permutation matrix of two people deciding about each other — A likes B, B likes back, who confirms first, who declines when, what each side is told and what they are deliberately not told — plus privacy (what each endpoint refuses to return), the photo count rules, and the 422/403/404/409 paths.

**99 Flutter tests** (`test/`) cover the swipe queue's retry and give-up rules, the image cache-key identity, the profile slide transition, the match page's one-way-door guards (dead buttons for the first instant, two-tap share, the dialog naming the handle, cancel sending nothing, back blocked for the side that just swiped) and the notification list's per-kind wording and tappability.

```bash
flutter test                                    # 99
cd backend && python -m pytest                  # 152
```

> Widget tests do not load the app's font: every glyph becomes a full-width box, so a label measures roughly 40% wider than on a device. The two page tests use a 440pt surface for that reason, not because the app needs one — the note is in `test/notifications_page_test.dart`.

---

## Tech stack

* **Frontend:** Flutter (Dart `>= 3.8.1`), Provider for state
* **Backend:** Python, FastAPI, SQLAlchemy, Alembic, Pydantic
* **Database:** PostgreSQL (Neon in production)
* **Identity:** Firebase Auth (email/password) + App Check
* **Media:** Firebase Storage, uploaded directly from the client
* **Push:** Firebase Cloud Messaging, device tokens in Firestore
* **Hosting:** Render
* **Local storage:** `SharedPreferences`

**Notable packages:** `provider`, `firebase_auth` / `firebase_core` / `firebase_app_check` / `firebase_messaging` / `firebase_storage` / `cloud_firestore`, `cached_network_image`, `image_picker` + `image_cropper`, `connectivity_plus`, `flutter_localizations`, `auto_size_text`, `flutter_staggered_grid_view`, `permission_handler`.

---

## Repo layout

```
lib/
  pages/        auth_pages, main_pages, profile_pages, sign_up_set_up
  widgets/      photo_card, profile_photo, main_app_bar, primary_button, ...
  providers/    profile, settings, notifications
  services/     api_services, swipe_queue, image_service, error_reporting
  models/       json <-> dart
  wrappers/     auth / setup / internet gates that decide the first screen
  constants/    university domains, interest catalogue, Greek prefectures
  l10n/         en + el
backend/
  main.py           the app: router include order and the 422 handler
  auth.py           who is calling
  routers/          endpoints grouped by resource
  api_models.py     response shapes
  notifications.py  send a push AND record the row
  database/         models, schemas, engine
  alembic/          migrations
  tests/            152 tests + conftest
  tools/            seed_local.py, simulate_match.py
test/               flutter tests
```

`backend/tools/simulate_match.py` is worth a mention: a seeded profile has a made-up `firebase_uid`, no Firebase account and therefore no token, so there is no way to act "as" one over HTTP — which is the auth design working as intended. It plays the other side by calling the real endpoint functions directly, so the rules under test are the live ones, and it refuses to run against anything but localhost.

---

## Getting started

Two parts run together: the Flutter app (`lib/`) and the FastAPI backend (`backend/`), both against the same Firebase project.

### Prerequisites

* **Flutter SDK** — Dart `>= 3.8.1` (run `flutter doctor` first)
* **Python 3.10+**
* **PostgreSQL 13+**
* **A Firebase project** with Authentication (Email/Password), Firestore, Cloud Messaging and Storage enabled
* Android Studio and/or Xcode for an emulator/simulator

> **Secrets are not in the repo.** `backend/.env`, `backend/serviceAccountKey.json`, `lib/firebase_options.dart`, `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` are all gitignored. After forking you create them yourself.

### 1. Fork & clone

```bash
git clone https://github.com/<your-username>/FoitiFinder.git
cd FoitiFinder
```

### 2. Backend

```bash
cd backend

python -m venv venv
venv\Scripts\Activate.ps1        # Windows (PowerShell)
# source venv/bin/activate       # macOS / Linux

pip install -r requirements.txt
```

**Create the database and the schema:**

```bash
createdb foitifinder             # or: psql -c "CREATE DATABASE foitifinder;"
copy .env.example .env           # then edit DATABASE_URL inside backend/.env

python -c "import database.models; from database.database import Base, engine; Base.metadata.create_all(engine)"
alembic stamp head               # so later migrations apply on top
```

> **Known limitation, and `alembic upgrade head` will not do this for you.** The chain's base revision *alters* a `photos` table that no migration ever creates: the original schema was made with `create_all` and Alembic was adopted afterwards without a baseline revision, so `upgrade head` against an empty database dies on its first statement. Hence the two commands above. Every migration since applies cleanly to an existing database — the gap is only at zero, and a squashed baseline is the fix.

**Add the Firebase Admin key.** [Firebase Console](https://console.firebase.google.com/) → **Project settings → Service accounts → Generate new private key** → save as `backend/serviceAccountKey.json` (exact name).

**Run it**, from the `backend/` folder:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Interactive API at `http://127.0.0.1:8000/docs`. The first log line prints the host and database name it connected to — worth reading, because a `DATABASE_URL` exported in the shell beats `backend/.env` and will quietly serve production data on localhost.

**Tests** need a second, local database named `foitifinder_test`:

```bash
createdb foitifinder_test
pip install -r requirements-dev.txt
python -m pytest
```

**A world to develop against:**

```bash
python tools/seed_local.py --email you@uoa.gr   # profiles to swipe on
python tools/simulate_match.py --uid <your firebase uid>
```

### 3. Firebase (client side)

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This writes `lib/firebase_options.dart` and the platform files. Alternatively drop `google-services.json` into `android/app/` and `GoogleService-Info.plist` into `ios/Runner/` per the [FlutterFire setup](https://firebase.google.com/docs/flutter/setup). Both are gitignored.

Debug builds use App Check's debug provider, which only works for devices whose debug token you have registered in the Firebase console — register it, or the API will reject every call.

### 4. Frontend

```bash
flutter pub get
flutter gen-l10n          # English + Greek
```

**Point the app at your backend.** It defaults to `http://127.0.0.1:8000`; override at compile time:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000          # Android emulator
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:8000       # device on the same network
```

A USB-connected phone can reach the host loopback instead, which avoids the LAN entirely:

```bash
adb reverse tcp:8000 tcp:8000
flutter run
```
