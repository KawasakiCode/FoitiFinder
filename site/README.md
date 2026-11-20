# The policy site

Six pages, in English and Greek. No build step, no JavaScript, no
dependencies — the same files serve from `python -m http.server` today and
from GitHub Pages later with nothing changed.

```
site/
  index.html           hub
  privacy.html         Privacy Statement
  terms.html           User Terms
  guidelines.html      User Guidelines
  cancellation.html    Cancellation Policy
  recommender.html     recommender disclosure
  delete-account.html  account deletion (Play Console's data deletion URL)
  style.css            shared by both languages
  el/                  the same six filenames, in Greek
```

Each page links to its twin in the other language, in the header and the
footer.

## Serving it locally

```
python -m http.server 8000 --directory site
```

Then `http://localhost:8000/privacy.html`, or `/el/privacy.html`.

The app builds these URLs itself from one constant. Set `kLegalBaseUrl` in
[lib/constants/legal.dart](../lib/constants/legal.dart) to
`http://10.0.2.2:8000` for the Android emulator, or to this machine's LAN
address for a real device on the same wifi, and the Policies dialog opens the
right page in whichever language the app is in. While it is empty the dialog
says "not published yet" instead of opening a blank tab, which is the state
the app ships in.

The Play Console will not accept a localhost URL. Before submission this needs
a public one — GitHub Pages, Cloudflare Pages or Netlify pointed at this
folder — and `kLegalBaseUrl` set to it.

## Before any of this goes live

### 1. The placeholders are filled

All of them, in both languages, and the Pages workflow prints what is left in
every run's summary. The table stays because each value is a decision rather
than a fact, and because changing one is an edit to fourteen files.

| Token | What it says now |
| --- | --- |
| `[[ENTITY]]` | Pantelis Remvos — a natural person, not a company |
| `[[ADDRESS]]` | Thessaloniki, 56430. Mandatory under GDPR Art. 13; a city and postcode is enough and it does not have to be your flat |
| `[[EMAIL]]` | foitifinder@gmail.com. On a public page, therefore scraped — do not wire it into anything that matters |
| `[[HOSTING]]`, `[[DATABASE]]` | Render Services, Inc. and Neon Inc. |
| `[[SENTRY_ENTITY]]` | Functional Software, Inc. dba Sentry |
| `[[SENTRY_REGION]]` | The EU region, which is why §9's transfer paragraph is explicitly disapplied to it |
| `[[SENTRY_RETENTION]]` | Thirty days. Spelled out rather than "30" because it opens its sentence |

**Replacing one is two edits, not one.** Every token shipped wrapped in
`<span class="todo">`, which renders it in loud yellow so an unfilled page is
impossible to miss. Substituting the token alone leaves the wrapper behind, and
the real name and address then render highlighted as though still outstanding
— so the span comes off as the value goes in. `style.css` is the one file to
leave alone: its comment contains a literal `[[ENTITY]]` to explain what the
class is for, and a blanket replace rewrites the explanation into nonsense.

**If the entity ever changes, three Greek articles change with it.** The
translation was written expecting «η εταιρεία», so a person's name arrives
behind feminine articles. `el/privacy.html` and `el/terms.html` now read
«είναι ο» and `el/index.html` «από τον»; a company name needs them put back.
Nothing that counts tokens catches this.

The count, any time:

```powershell
Select-String -Path site/*.html, site/el/*.html -Pattern '\[\['
```

### 2. Have somebody qualified read them

These are a careful, specific draft written from the actual code, not
boilerplate. They are not legal advice and nobody with a licence has seen
them. The sections most worth a lawyer's eye:

- `privacy.html` §3 and §7 — the Art. 9(2)(a) explicit-consent basis for
  orientation, religion and politics, and whether a profile field can carry
  explicit consent at all or needs its own tick box at the point of entry;
- `privacy.html` §6 and `delete-account.html` — retaining reports against an
  Art. 17 erasure request;
- `terms.html` §2 — the bullet asking users to declare they have no relevant
  conviction. It replaced a clause lifted from US dating-app terms that turned
  on a sex-offender registry Greece does not have. Asking about convictions at
  all touches GDPR Art. 10, which wants a basis in law rather than consent; the
  declaration is never stored and there is no field for it anywhere, which is
  probably what keeps it clear, but it is worth confirming — and if it ever
  becomes a stored answer it is a different question;
- `terms.html` §11 — the liability wording against Greek consumer law;
- `cancellation.html` — rewrite properly if anything is ever sold.

The Greek is a translation of the English, not a separate document. If the two
ever disagree the English was written first, and `terms.html` §15 says so to
the reader rather than hiding it.

### 3. Promises the app used to break

Both of these are now fixed, and are recorded because they are the two ways
these pages can quietly stop being true.

- `deleteAccountLongText` promised a 10-day window in which signing in would
  recover a deleted account. Nothing of the kind existed, and once
  `delete-account.html` was published it contradicted it. The string now
  describes the immediate, permanent deletion the code actually performs.
- `recommender.html` described the feed as one-directional, which it was: your
  filters decided who you saw and nothing decided who saw you. The feed now
  applies both sides' age range, gender preference, height range and spoken
  languages.
- `recommender.html` then said three times that the deck was shuffled and that
  there was "no scoring, no ranking", and listed the ranking signals under
  "what we plan to change" — after the ranking had already shipped. It now
  describes the four scoring signals, their weights, and the weighted random
  draw. This is the one that mattered most: a DSA Article 27 disclosure that
  describes a system the service no longer runs is worse than none.
- `privacy.html` said the time you were last active was stored in Firestore.
  It moved to Postgres when the feed started ordering on it, and the statement
  now says so and discloses what it is used for.
- `guidelines.html` told people that a report "works whether or not the match
  is still in your list". That was true of the endpoint and false of the app:
  reporting started from a profile, the only profiles reachable for somebody
  you had matched with were on the matches page, and removing a match took it
  off that page. So removing somebody destroyed the ability to report them, at
  the point where the handle is already out and misuse becomes possible. Fixed
  by building the screen the sentence had been describing rather than by
  softening the sentence - the row was never deleted and `create_report` never
  consulted the hidden columns, so nothing had to be retained to do it.

## Keeping the pages honest

The content is specific to how this app actually behaves, which is the point
and also the maintenance cost. Each of these changes makes a sentence here
wrong, in both languages:

- **changing a scoring weight** — `recommender.html` publishes all four as
  numbers (super like 3, activity up to 2, 1 per shared interest, same
  university 1) and states that the interest term can outweigh the rest
  combined. The constants are `W_*` at the top of `backend/routers/feed.py`;
- **adding or removing a scoring signal** — the same page says "the sum of
  four things and nothing else", and separately promises that personality
  tags, MBTI, pronouns, city and the Article 9 fields are not read. The
  comment above `_score` in `feed.py` records why each of those is excluded;
- **sorting the deck instead of drawing it** — the page explains at length
  that a higher score only raises the probability. Replacing the sampling key
  with a plain `order_by(score)` would make that false;
- **changing which preferences the feed applies** — `recommender.html` names
  the four hard filters and says plainly that smoking, drinking, intentions,
  children and show-outside-residence are stored and unused;
- **changing the page size** — the page says twenty cards at a time
  (`DEFAULT_PAGE` in `feed.py`);
- **adding any paid feature** — `terms.html` §9 and all of
  `cancellation.html`;
- **adding analytics or ads** — `privacy.html` has a callout promising none of
  either, and the Play data safety form has to agree with it. Crash reporting
  is now in (Sentry, both halves of the stack), and what keeps that honest is
  `backend/tests/test_error_scrubbing.py` plus the `beforeSend` in
  `lib/services/error_reporting.dart`: §2 of the privacy statement describes
  exactly what those two refuse to send, so widening either is a change to a
  published document. Turning on `tracesSampleRate` would make the "no
  analytics" promise false;
- **adding a report category** — `guidelines.html` names each one;
- **renaming a page in this folder** — the app builds its URLs from the
  filenames in `LegalDocument`, and `test/legal_urls_test.dart` pins them;
- **moving or renaming the removed-matches screen** — `guidelines.html` §5 and
  §6 and `terms.html` §7 all name the path to it (Account settings → Matches
  you removed) in both languages, because a safety instruction that does not
  say where to tap is not an instruction. It is
  `lib/pages/profile_pages/account_settings/removed_matches_page.dart`, reached
  from `account_settings_page.dart`, and
  `backend/tests/test_removed_matches.py` holds the rules it depends on.
