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

### 1. Fill in the placeholders

Every unfilled value renders as a loud yellow `[[TOKEN]]`, because a legal page
that goes live saying `[[ENTITY]]` is worse than one that is late. Four
tokens, in both languages:

| Token | What it is |
| --- | --- |
| `[[ENTITY]]` | Who operates the app — your name, or a company if you form one |
| `[[ADDRESS]]` | A postal address. Mandatory under GDPR Art. 13; a city and postcode is enough, it does not have to be your flat |
| `[[EMAIL]]` | One contact address, for privacy requests, appeals and complaints |
| `[[HOSTING]]`, `[[DATABASE]]` | Two sub-processors, with their legal entity names — e.g. "Render Services, Inc." and "Neon Inc." |
| `[[SENTRY_ENTITY]]` | The Sentry legal entity on your DPA — "Functional Software, Inc." for the US entity, or the Irish entity if you signed with that one |
| `[[SENTRY_REGION]]` | One sentence on where the data goes. If your Sentry project is in the **EU** region, say so and the transfer paragraph below does not apply to it. If it is in the US, say that instead and leave it covered by the SCC/DPF sentence |
| `[[SENTRY_RETENTION]]` | How long your plan keeps events — check it in the project settings rather than trusting a blog post; the free-tier figure is reported inconsistently |

Fill one in across both languages:

```powershell
Get-ChildItem site/*.html, site/el/*.html | ForEach-Object { (Get-Content $_ -Raw) -replace '\[\[EMAIL\]\]','hello@foitifinder.app' | Set-Content $_ -NoNewline }
```

Then check nothing is left:

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
  applies both sides' age range and gender preference, so the page describes
  four filters rather than two.

## Keeping the pages honest

The content is specific to how this app actually behaves, which is the point
and also the maintenance cost. Each of these changes makes a sentence here
wrong, in both languages:

- **shipping the ranking work** — `recommender.html` says the deck is shuffled,
  and says so three times;
- **changing which preferences the feed applies** — `recommender.html` names
  the four that are filters and says plainly that height, smoking, drinking,
  intentions, children and languages are stored and unused;
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
  filenames in `LegalDocument`, and `test/legal_urls_test.dart` pins them.
