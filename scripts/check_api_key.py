"""Ask Google whether the Android API key accepts this app's certificates.

WHY THIS EXISTS. "Requests from this Android client application are blocked"
is an API key restriction refusing a certificate it has not been told about,
and the only other way to test it is to rebuild, reinstall and try to log in -
which also fails for a dozen unrelated reasons and tells you nothing about
which one. This asks the same question Firebase Auth asks, directly.

It sends a deliberately invalid sign-in. Credentials are not the point:

    403 "...are blocked"      the restriction does NOT list this fingerprint
    400 INVALID_LOGIN_...     the key ACCEPTED the client and merely rejected
                              a made-up email, which is the answer we want

RESTRICTION CHANGES TAKE A FEW MINUTES to propagate, so a BLOCKED result
straight after an edit is not yet evidence of anything.

Nothing secret is printed.
"""

import io
import json
import os
import re
import subprocess
import urllib.error
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
#BOTH, because the failure this script was written for was a key accepting
#the OLD package and not the new one - and a probe that only ever asks about
#the current package reports "blocked" without saying that the key works
#perfectly for a name the app no longer uses. That difference is the answer.
PACKAGES = ("com.foitifinder.app", "com.example.foitifinder")
PACKAGE = PACKAGES[0]


def keytool() -> str:
    for candidate in [
        os.path.join(os.environ.get("JAVA_HOME", ""), "bin", "keytool.exe"),
        r"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe",
        "/usr/bin/keytool",
    ]:
        if candidate and os.path.exists(candidate):
            return candidate
    return "keytool"


def sha1_of(path: str, alias: str, password: str) -> str | None:
    """The SHA-1 with the colons stripped, which is the header format."""
    if not path or not os.path.exists(path):
        return None
    out = subprocess.run(
        [keytool(), "-list", "-v", "-keystore", path, "-alias", alias],
        input=password + "\n", capture_output=True, text=True,
    ).stdout
    match = re.search(r"SHA1:\s*([0-9A-Fa-f:]+)", out)
    return match.group(1).replace(":", "").upper() if match else None


def properties() -> dict:
    path = os.path.join(REPO, "android", "key.properties")
    values = {}
    if os.path.exists(path):
        for line in io.open(path, encoding="utf-8"):
            if "=" in line and not line.strip().startswith("#"):
                key, _, value = line.partition("=")
                values[key.strip()] = value.strip()
    return values


def ask(api_key: str, cert: str, package: str = PACKAGE) -> str:
    url = ("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
           f"?key={api_key}")
    body = json.dumps({"email": "nobody@example.invalid",
                       "password": "x", "returnSecureToken": True}).encode()
    request = urllib.request.Request(url, data=body, headers={
        "Content-Type": "application/json",
        "X-Android-Package": package,
        "X-Android-Cert": cert,
    })
    try:
        urllib.request.urlopen(request, timeout=25)
        return "accepted (unexpected 200)"
    except urllib.error.HTTPError as error:
        payload = error.read().decode("utf-8", "replace")
        if "blocked" in payload:
            return "BLOCKED - this fingerprint is not on this key"
        message = json.loads(payload).get("error", {}).get("message", "")
        return f"accepted (auth replied {message})"
    except Exception as error:
        return f"could not reach Google: {type(error).__name__}"


def main() -> None:
    config = json.load(io.open(
        os.path.join(REPO, "android", "app", "google-services.json"),
        encoding="utf-8"))
    client = next(
        c for c in config["client"]
        if c["client_info"]["android_client_info"]["package_name"] == PACKAGE)

    options = io.open(os.path.join(REPO, "lib", "firebase_options.dart"),
                      encoding="utf-8").read()
    in_use = re.search(r"apiKey:\s*'([^']+)'", options).group(1)

    props = properties()
    certs = {
        "upload": sha1_of(props.get("storeFile", ""), props.get("keyAlias", ""),
                          props.get("storePassword") or props.get("keyPassword", "")),
        "debug ": sha1_of(os.path.expanduser("~/.android/debug.keystore"),
                          "androiddebugkey", "android"),
    }

    print("A key that accepts one package and blocks the other belongs to")
    print("the other app. Which key a build actually uses is in the APK:")
    print("  aapt2 dump resources <apk> | grep -A1 google_api_key\n")
    for index, entry in enumerate(client["api_key"]):
        key = entry["current_key"]
        mark = "  <- the one the app uses" if key == in_use else ""
        print(f"key [{index}] ...{key[-8:]}{mark}")
        for package in PACKAGES:
            results = []
            for label, cert in certs.items():
                if not cert:
                    results.append(f"{label}=unreadable")
                    continue
                verdict = ask(key, cert, package)
                results.append(f"{label.strip()}={verdict}")
            print(f"   {package:26} " + "  ".join(results))
        print()


if __name__ == "__main__":
    main()
