"""What an error report is not allowed to carry out of this process.

WHY THIS IS TESTED AND THE REST OF THE SENTRY SETUP IS NOT. Everything else in
error_reporting is configuration - a DSN, a sample rate - and gets exercised
by being wrong in an obvious way. before_send is different: it is the only
code between a crash and a third party, it fails silently when it is wrong,
and what leaks is the Authorization header of every request this backend
serves. It is also a pure function of a dict, which makes it free to check.

THE PRIVACY STATEMENT DESCRIBES THIS FUNCTION. Section 2 of site/privacy.html
lists what an error report contains and section 8 names Sentry as the
processor that receives it. A change here that widens what travels is a change
to a published document, so these tests are what makes somebody notice.
"""

import error_reporting


def scrub(event):
    return error_reporting._scrub(event, None)


class TestTheAuthorizationHeader:
    """THE ONE THAT MATTERS MOST. Every request to this API carries a Firebase
    ID token in this header. It is short lived, but it is a live credential
    and it identifies a person - and send_default_pii=False is a default,
    which is a thing that can be changed by somebody who does not know what is
    in this app's headers.
    """

    def test_it_is_dropped(self):
        event = scrub({"request": {"headers": {
            "Authorization": "Bearer eyJhbGciOi.REAL.TOKEN",
            "Accept": "application/json",
        }}})

        assert "Authorization" not in event["request"]["headers"]
        assert "REAL" not in str(event)

    def test_whatever_case_it_arrives_in(self):
        #header names are case insensitive on the wire and different servers
        #normalise them differently
        for name in ("authorization", "AUTHORIZATION", "Authorization"):
            event = scrub({"request": {"headers": {name: "Bearer x"}}})
            assert event["request"]["headers"] == {}, name

    def test_and_so_are_cookies_and_the_app_check_token(self):
        event = scrub({"request": {"headers": {
            "Cookie": "session=abc",
            "X-Firebase-AppCheck": "token",
            "User-Agent": "Dart/3.5",
        }}})

        assert list(event["request"]["headers"]) == ["User-Agent"]

    def test_a_harmless_header_survives(self):
        #the point is not to send nothing, it is to send what helps: the
        #content type of a request that failed to parse is diagnostic
        event = scrub({"request": {"headers": {"Content-Type": "text/plain"}}})

        assert event["request"]["headers"] == {"Content-Type": "text/plain"}


class TestTheBodyAndTheQueryString:
    def test_the_body_never_travels(self):
        """A PATCH to /users/me IS SOMEBODY'S BIO. A report is free text about
        another person. Neither is diagnostic - the traceback says what broke.
        """
        event = scrub({"request": {
            "data": {"bio": "something personal", "instagram_handle": "xyz"},
            "url": "https://api/users/me",
        }})

        assert "data" not in event["request"]
        assert "something personal" not in str(event)
        assert "xyz" not in str(event)

    def test_the_query_string_is_stripped_from_the_url(self):
        """/users/feed?exclude=... IS A LIST OF EVERYBODY IN SOMEBODY'S DECK.

        This is new as of the paging fix, which is exactly why it is here: the
        exclusions were added for a good reason and they turned a harmless URL
        into a record of who one person was being shown.
        """
        event = scrub({"request": {
            "url": "https://api/users/feed?limit=20&exclude=11,12,13",
            "query_string": "limit=20&exclude=11,12,13",
        }})

        assert event["request"]["url"] == "https://api/users/feed"
        assert "query_string" not in event["request"]
        assert "exclude" not in str(event)

    def test_a_url_with_no_query_is_left_alone(self):
        event = scrub({"request": {"url": "https://api/matches"}})

        assert event["request"]["url"] == "https://api/matches"

    def test_a_match_id_in_the_path_is_kept(self):
        #PATH IDS STAY, deliberately. /matches/41/confirm is the route that
        #broke, and losing the id would make a traceback unreproducible. The
        #id alone identifies nobody - every endpoint that takes one already
        #checks the caller is a participant.
        event = scrub({"request": {"url": "https://api/matches/41/confirm"}})

        assert event["request"]["url"].endswith("/matches/41/confirm")


class TestWhoTheErrorIsAttributedTo:
    def test_every_event_is_anonymous(self):
        event = scrub({"user": {"id": "firebase-uid-of-a-real-person",
                                "email": "someone@uoa.gr",
                                "ip_address": "1.2.3.4"}})

        assert event["user"] == {"id": "anonymous"}

    def test_overwritten_rather_than_deleted(self):
        """SO A set_user ANYWHERE ELSE CANNOT UNDO IT.

        Deleting the key would leave the field free for any later
        sentry_sdk.set_user call in this codebase to fill with a real uid.
        Overwriting means the last word belongs to this function.
        """
        event = scrub({})

        assert event["user"] == {"id": "anonymous"}

    def test_the_uid_is_the_one_identifier_worth_this_care(self):
        #it joins users, swipes, matches, photos, reports and the Firestore
        #document - which is why it is named in the module docstring
        event = scrub({"user": {"id": "uid-abc"}, "request": {"headers": {
            "Authorization": "Bearer token-for-uid-abc"}}})

        assert "uid-abc" not in str(event)


class TestItSurvivesOddEvents:
    """before_send runs on every event including ones this code did not shape.

    AN EXCEPTION IN HERE WOULD DROP THE REPORT, and silently - which is the
    one failure mode worse than reporting too much, because it looks exactly
    like a backend that never breaks.
    """

    def test_an_event_with_no_request(self):
        assert scrub({"level": "error"})["user"] == {"id": "anonymous"}

    def test_an_event_with_an_empty_request(self):
        assert scrub({"request": {}})["request"] == {}

    def test_a_request_with_no_headers(self):
        event = scrub({"request": {"url": "https://api/health"}})
        assert event["request"]["url"] == "https://api/health"

    def test_a_url_that_is_not_a_string(self):
        event = scrub({"request": {"url": None}})
        assert event["request"]["url"] is None


class TestInstallingItWithoutADsn:
    def test_it_does_nothing_and_says_so(self, monkeypatch):
        """THE STATE EVERY TEST RUN AND CI IS IN. Same choice firebase_app
        makes: the absence of a secret is not an error, because every module
        here has to be importable and callable without one.
        """
        monkeypatch.delenv("SENTRY_DSN", raising=False)

        error_reporting.install()  # must not raise

    def test_a_blank_dsn_counts_as_absent(self, monkeypatch):
        #an env var set to the empty string is what a .env with `SENTRY_DSN=`
        #produces, and it must not be read as "yes, send to nowhere"
        monkeypatch.setenv("SENTRY_DSN", "   ")

        error_reporting.install()  # must not raise
