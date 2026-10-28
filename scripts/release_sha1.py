"""Print the release keystore's certificate fingerprints, and nothing else.

Firebase and the Google Cloud API key restriction both want the SHA-1 (and
SHA-256) of the certificate a build is signed with. Getting them means asking
keytool, which wants the keystore password.

THE PASSWORD IS READ FROM android/key.properties AND HANDED TO keytool ON
STDIN, so it never appears in a command line, in shell history, in a process
list or in this output. Only the fingerprints are printed, and those are not
secret - they are published to Google and baked into every APK.

    python scripts/release_sha1.py

WHICH CERTIFICATE THIS IS. The upload key: the one this machine signs with.
Once the app is on Play, Play re-signs it with its own app signing key, whose
fingerprint is different and lives in Play Console under Setup > App
integrity. BOTH have to be registered with Firebase, or the app works in a
local release build and fails for everybody who installs from the store.
"""

import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANDROID = os.path.join(REPO, "android")


def find_keytool() -> str:
    """keytool, from JAVA_HOME, the PATH, or where Android Studio puts it."""
    candidates = []
    java_home = os.environ.get("JAVA_HOME")
    if java_home:
        candidates.append(os.path.join(java_home, "bin", "keytool.exe"))
        candidates.append(os.path.join(java_home, "bin", "keytool"))
    candidates += [
        r"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe",
        r"C:\Program Files\Android\Android Studio\jre\bin\keytool.exe",
        "/usr/bin/keytool",
    ]
    for candidate in candidates:
        if os.path.exists(candidate):
            return candidate
    #on the PATH, or not installed - let the caller find out which
    return "keytool"


def read_properties(path: str) -> dict:
    values = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if "=" in line and not line.strip().startswith("#"):
                key, _, value = line.partition("=")
                values[key.strip()] = value.strip()
    return values


def fingerprints(keytool: str, path: str, alias: str, password: str) -> bool:
    """Print a keystore entry's fingerprints. True if it found any."""
    result = subprocess.run(
        [keytool, "-list", "-v", "-keystore", path, "-alias", alias],
        input=(password or "") + "\n",
        capture_output=True,
        text=True,
    )
    shown = False
    for line in result.stdout.splitlines():
        stripped = line.strip()
        if stripped.startswith(("SHA1:", "SHA-1:", "SHA256:", "SHA-256:")):
            print("   " + stripped)
            shown = True
    return shown


def debug_key(keytool: str) -> None:
    """The debug keystore, which the Android SDK creates by itself.

    AS IMPORTANT AS THE UPLOAD KEY, AND EASY TO FORGET. The API key is
    restricted by package name AND certificate, so a build signed with a
    fingerprint Google has not been told about is refused - and `flutter run`
    signs with THIS key, not the upload one.

    Register only the upload key and every debug build silently loses Firebase
    Auth, while plain HTTP to your own backend keeps working. That combination
    is badly misleading: the backend answers, the login does not, and nothing
    in the backend log shows a thing, because the app never gets far enough to
    call it.

    The password is Android's own published default. It is not a secret - the
    SDK generates this file locally and it signs nothing anybody ships.
    """
    path = os.path.join(os.path.expanduser("~"), ".android", "debug.keystore")
    print("\ndebug keystore (what `flutter run` signs with)")
    if not os.path.exists(path):
        print("   not found - created the first time a debug APK is built here")
        return
    if not fingerprints(keytool, path, "androiddebugkey", "android"):
        print("   keytool returned nothing for alias androiddebugkey")


def main() -> None:
    properties_path = os.path.join(ANDROID, "key.properties")
    if not os.path.exists(properties_path):
        sys.exit("android/key.properties not found. It is gitignored, so a "
                 "fresh clone does not have it - copy it from the machine "
                 "that holds the keystore.")

    properties = read_properties(properties_path)
    store = properties.get("storeFile")
    alias = properties.get("keyAlias")
    password = properties.get("storePassword") or properties.get("keyPassword")

    if not store or not alias:
        sys.exit("key.properties is missing storeFile or keyAlias")

    #gradle resolves a relative storeFile against android/
    path = store if os.path.isabs(store) else os.path.join(ANDROID, store)
    if not os.path.exists(path):
        sys.exit(f"keystore not found: {os.path.basename(path)}\n"
                 "key.properties points somewhere that does not exist on this "
                 "machine.")

    print(f"keystore: {os.path.basename(path)}   alias: {alias}")
    print("(this is the UPLOAD key; Play's own signing key is in Play Console"
          " > Setup > App integrity)\n")

    keytool = find_keytool()
    if not fingerprints(keytool, path, alias, password):
        #NEVER PRINT keytool's stderr WHOLESALE - it can echo back what was
        #typed at it, which here is the password.
        sys.exit("keytool returned no fingerprint. Check keyAlias and the "
                 "password in key.properties, and that keytool is installed "
                 "(it ships with the JDK inside Android Studio).")

    debug_key(keytool)

    print("\nBOTH belong in Firebase (project settings > the Android app) and")
    print("in the API key's Android restriction. Play adds a third of its own")
    print("once you upload: Play Console > Setup > App integrity.")


if __name__ == "__main__":
    main()
