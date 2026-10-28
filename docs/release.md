# Shipping a release build

Written for: whoever is cutting the build, which for now is one person who
also wrote the app. It assumes you know the repo and nothing about the Play
console.

The package name changed from `com.example.foitifinder` to
**`com.foitifinder.app`**, and several things outside this repo are keyed to
that string. Until the Firebase steps below are done, **the app will not
build** — the `com.google.gms.google-services` Gradle plugin fails with *"No
matching client found for package name"*, which is it telling you the config
file still describes the old app.

---

## 1. Firebase: a new Android app

The package name is part of a Firebase app's identity, so this is a new app
inside the same project, not an edit of the old one.

1. Firebase console → project settings → **Add app** → Android.
2. Package name: `com.foitifinder.app`. Nickname whatever you like.
3. Register the signing fingerprints. Get them with:

   ```
   python scripts\release_sha1.py
   ```

   That reads the password out of `android/key.properties` and prints only the
   fingerprints, which are not secret. Add **both** SHA-1 and SHA-256.
4. Download the new `google-services.json` into `android/app/`, replacing the
   old one.
5. Regenerate the Dart config so the two cannot disagree:

   ```
   flutterfire configure
   ```

   Pick the same project and the new Android app. This rewrites
   `lib/firebase_options.dart`, which is gitignored.

**Leave the old app registered.** Deleting it would break any build already
installed, including the one on your own phone, and it costs nothing to keep.

## 2. The API key restriction

The Android API key is restricted by package name **and** certificate, so the
old restriction no longer matches anything this app builds.

Google Cloud console → *APIs & Services* → *Credentials* → the Android key →
**Android apps** → add `com.foitifinder.app` with the SHA-1 from step 1.

Add the Play App Signing certificate too, once it exists — see step 5.

## 3. App Check

Firebase console → App Check → the new Android app → register **Play
Integrity**.

`main.dart` picks the provider from `kDebugMode`, so a release build uses Play
Integrity whether or not it is registered. An unregistered one fails every
App Check assertion, and because `kDebugMode` is a compile-time constant there
is no flag to flip afterwards — the binary only has the one branch in it.

## 4. The CI secret

`.github/workflows/flutter.yml` writes `lib/firebase_options.dart` from the
`FIREBASE_OPTIONS_DART` repository secret. Step 1 regenerated that file, so
the secret is now stale and CI will build against the old Firebase app.

Repository → Settings → Secrets → update `FIREBASE_OPTIONS_DART` with the new
file's full contents.

## 5. Signing, and the one irreversible part

`android/key.properties` points at `upload-keystore.jks` with alias `upload`.
**Nothing about signing changed** — a keystore is not tied to a package name,
so the existing key still works and should keep being used.

Two things worth being clear about, because neither can be undone:

- **Back the keystore up somewhere that is not this laptop.** With Play App
  Signing you can ask Google to reset a lost *upload* key, but it is a support
  request with a wait, and without App Signing a lost key means you can never
  update the app again. The file is gitignored for good reasons and that also
  means it is not backed up by the thing that backs up everything else.
- **`applicationId` is permanent.** Play keys the listing to
  `com.foitifinder.app` for life. Shipping under a different one later is a new
  listing with no installs, no reviews, and no update path for anyone already
  on the old build.

After the first upload, Play generates its own **app signing certificate**,
which is different from the upload certificate. Its SHA-1 is in Play Console →
*Setup* → *App integrity*. Add that fingerprint to Firebase (step 1) and to the
API key restriction (step 2) as well, or everything will work in your local
release build and fail for everybody who installs from the store.

## 6. Before you upload

Things that are true of this repo right now and are not code:

- **The launcher icon is still Flutter's logo.** `assets/brand/README.md` says
  what two files to put there; then `flutter pub run flutter_launcher_icons`.
- **The five legal URLs in `lib/constants/legal.dart` are empty.** The in-app
  dialog handles that honestly — it says "not published yet" rather than
  opening a blank tab — but Play requires a reachable privacy policy URL on the
  listing itself, and checks it against the one in the app.
- **`isMinifyEnabled` is false.** Deliberate for a first release: R8 can break
  reflection in ways that only appear in a release build, and you want one
  known-good build before adding that variable. Worth turning on afterwards.
- **Errors go nowhere.** `error_reporting.dart` is a `debugPrint` and a TODO
  where Sentry goes, and `debugPrint` is stripped from release builds — so a
  caught error in the wild is silent.

## 7. Building it

```
flutter build appbundle --release
```

An **app bundle**, not an APK: Play requires `.aab` for new apps, and it is
what lets Play sign and split per device.

The output is `build/app/outputs/bundle/release/app-release.aab`.

Sanity-check what you are about to upload:

```
python scripts\release_sha1.py
```

and check the fingerprints it prints are the ones Firebase has registered.

## 8. Each subsequent release

Bump `version:` in `pubspec.yaml`. The part after `+` is the **versionCode**,
and Play refuses an upload whose versionCode it has seen before.

```
version: 1.0.1+2
```

If a build ever has to be pulled, that number is also what
`backend/app_version.py` compares against — raising `MINIMUM_BUILD` there stops
older builds talking to the API at all. See the notes in that file for what it
does and does not do.
