"""Send one error to Sentry and say whether it got there.

    cd backend
    $env:SENTRY_DSN='https://...'
    .\\venv\\Scripts\\python.exe tools\\check_sentry.py

WHY A SCRIPT AND NOT A TEST. The test suite is forbidden from reaching any
external service (see the _no_real_firebase fixture in conftest, and the
three-minute suite that taught us why), so nothing in it can prove that a DSN
is correct, that the network allows the egress, or that the project on the
other end is the one you think it is. Those are the three things that go wrong
when wiring up error reporting, and they are all environment rather than code.

IT USES THE REAL MODULE, which is the point. install() and before_send are
exactly what production runs, so a scrub that drops the whole event or an init
that silently refuses a malformed DSN shows up here rather than the first time
something breaks at 3am.

WHAT IT CANNOT TELL YOU. Sentry's client swallows transport failures on
purpose - an error reporter that throws is worse than one that misses - so a
bad DSN often looks like success from in here. flush() returning promptly is a
decent signal and a hung flush is a bad one, but the only real confirmation is
the event appearing in the project. Hence the link printed at the end.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import error_reporting  # noqa: E402


class SentryCheckError(RuntimeError):
    """Deliberately a distinctive type, so it is obvious in the issue list."""


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass

    dsn = os.getenv("SENTRY_DSN", "").strip()
    if not dsn:
        print("SENTRY_DSN is not set, so there is nothing to check.")
        print()
        print("  PowerShell:  $env:SENTRY_DSN='https://...'")
        print()
        print("Use the PYTHON project's DSN, not the Flutter one - they are")
        print("different projects and mixing them puts app crashes and server")
        print("errors in the same pile.")
        return 1

    #THE HOST ONLY, NEVER THE WHOLE DSN. The key is in it, and this prints on
    #every run - including runs somebody pastes into a chat to ask why it did
    #not work.
    host = dsn.split("@")[-1].split("/")[0] if "@" in dsn else "?"
    print(f"sending to: {host}")
    if ".de." in host or ".eu." in host:
        print("region:     EU - the privacy statement can say data stays in "
              "the EEA")
    else:
        print("region:     NOT the EU ingest host. If you meant to be on the")
        print("            EU region this is the moment to notice: it is set")
        print("            when the org is created and cannot be moved later.")
        print("            [[SENTRY_REGION]] in site/privacy.html has to say")
        print("            so, and the transfer paragraph then applies.")

    error_reporting.install()

    import sentry_sdk

    if sentry_sdk.get_client().dsn is None:
        print("\nFAILED: Sentry did not initialise. The DSN is probably "
              "malformed.")
        return 1

    try:
        raise SentryCheckError(
            "check_sentry.py - if you can read this in Sentry, the backend "
            "half works"
        )
    except SentryCheckError as error:
        event_id = sentry_sdk.capture_exception(error)

    #A HUNG FLUSH IS THE REAL FAILURE SIGNAL, since the client will not raise
    #on a transport error. Two seconds is generous for one small event.
    delivered = sentry_sdk.flush(timeout=2.0)

    print(f"\nevent id:   {event_id}")
    print(f"flush:      {'returned' if delivered is None else delivered}")
    print()
    print("Now look in the Sentry project for a SentryCheckError. If it is")
    print("there, check the event's detail too:")
    print("  - the user should read 'anonymous', not a Firebase uid")
    print("  - there should be no Authorization header")
    print("If either is wrong, before_send is not doing its job and")
    print("tests/test_error_scrubbing.py should have caught it.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
