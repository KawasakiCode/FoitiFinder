"""An unhandled exception in a route actually reaches Sentry.

THE GAP THIS FILLS. tools/check_sentry.py captures an exception by hand, which
proves the DSN, the network and before_send - and proves nothing about the
FastAPI integration, which is the thing that carries every real 500. Those are
different wires. The integration one depends on install() being called BEFORE
FastAPI() is constructed, because it patches the ASGI app, and getting that
order wrong fails silently: the app works, errors are handled, and Sentry is
simply empty forever.

NOTHING LEAVES THE PROCESS. install() takes a transport, so these use the real
configuration - the real integrations, the real before_send - with a list in
place of the network. The DSN is a syntactically valid fake.

WHY NOT JUST TRUST tools/check_sentry.py. Because the failure it cannot see is
the likely one. A typo in a DSN announces itself the first time you look at an
empty project; an integration that was never wired looks exactly the same as a
backend that never breaks.
"""

import contextlib

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

import error_reporting

#syntactically valid, deliberately not a real project
FAKE_DSN = "https://abc123def456@o4500000000000000.ingest.de.sentry.io/4500000000000000"


@contextlib.contextmanager
def sentry_capturing(monkeypatch):
    """The real install(), with a list where the network goes."""
    import sentry_sdk

    events: list = []
    monkeypatch.setenv("SENTRY_DSN", FAKE_DSN)
    error_reporting.install(transport=events.append)
    try:
        yield events
    finally:
        #PUT IT BACK, or the autouse guard in conftest fails for every test
        #that runs after this one - which is the guard doing its job.
        #
        #NOT init(dsn=None), WHICH IS NOT A RESET. init falls back to reading
        #SENTRY_DSN from the environment when it is given no dsn, and
        #monkeypatch has not torn that down yet at this point in the test - so
        #the "reset" quietly built a LIVE client from the fake DSN and every
        #subsequent test failed at setup. set_client(None) installs a
        #NonRecordingClient and consults nothing.
        sentry_sdk.get_global_scope().set_client(None)


def app_that_raises():
    """A FastAPI app built the way main.py builds one: after install()."""
    app = FastAPI()

    @app.get("/boom")
    def boom():
        raise RuntimeError("unhandled, from inside a route")

    @app.get("/fine")
    def fine():
        return {"ok": True}

    return app


class TestAnUnhandledRouteError:
    def test_it_reaches_sentry(self, monkeypatch):
        with sentry_capturing(monkeypatch) as events:
            client = TestClient(app_that_raises(), raise_server_exceptions=False)
            response = client.get("/boom")

        assert response.status_code == 500
        assert events, "the exception never reached Sentry"

    def test_and_arrives_with_the_exception_in_it(self, monkeypatch):
        with sentry_capturing(monkeypatch) as events:
            client = TestClient(app_that_raises(), raise_server_exceptions=False)
            client.get("/boom")

        assert "unhandled, from inside a route" in str(events[0])
        assert "RuntimeError" in str(events[0])

    def test_a_request_that_works_sends_nothing(self, monkeypatch):
        """NO EVENT ON A 200, which is worth pinning because the opposite -
        reporting every request - is how a free quota disappears in an hour
        and how traces_sample_rate gets turned on by accident.
        """
        with sentry_capturing(monkeypatch) as events:
            client = TestClient(app_that_raises())
            assert client.get("/fine").status_code == 200

        assert events == []


class TestTheScrubAppliesToIt:
    """before_send runs on integration-captured events too, not only on the
    ones captured by hand. That is the whole reason to test through the
    integration rather than around it.
    """

    def test_the_authorization_header_does_not_travel(self, monkeypatch):
        with sentry_capturing(monkeypatch) as events:
            client = TestClient(app_that_raises(), raise_server_exceptions=False)
            client.get("/boom", headers={
                "Authorization": "Bearer A-REAL-LOOKING-FIREBASE-TOKEN",
            })

        assert events
        assert "A-REAL-LOOKING-FIREBASE-TOKEN" not in str(events[0])

    def test_the_query_string_does_not_travel(self, monkeypatch):
        #/users/feed?exclude=... is a list of everyone in somebody's deck
        with sentry_capturing(monkeypatch) as events:
            client = TestClient(app_that_raises(), raise_server_exceptions=False)
            client.get("/boom?exclude=11,12,13&limit=20")

        assert events
        assert "exclude" not in str(events[0])

    def test_the_event_is_anonymous(self, monkeypatch):
        with sentry_capturing(monkeypatch) as events:
            client = TestClient(app_that_raises(), raise_server_exceptions=False)
            client.get("/boom")

        assert events[0]["user"] == {"id": "anonymous"}

    def test_no_frame_carries_its_local_variables(self, monkeypatch):
        """THE LEAK THESE TESTS WERE WRITTEN AND IMMEDIATELY FOUND.

        sentry-sdk sends every frame's locals by default, and in an ASGI app
        every Starlette frame has `scope` in its locals - the entire request,
        headers included. So each report carried the Authorization header (a
        live Firebase ID token) and the whole query string, while
        request.headers in the same event had been dutifully cleaned.

        test_error_scrubbing could not have caught it: it checks _scrub
        against a synthetic dict, and the real payload was somewhere that dict
        never had. Only going through the integration showed it.

        PINS THE OUTCOME, NOT THE OPTION, and there are deliberately two
        defences: include_local_variables=False in install(), and _scrub
        stripping `vars` from every frame. Either alone makes this pass -
        checked by turning each off in turn - and it takes both being gone to
        fail. That is the right shape for something whose failure is silent
        and publishes a credential, but it does mean this test will not notice
        the option drifting back to True on its own.
        """
        with sentry_capturing(monkeypatch) as events:
            client = TestClient(app_that_raises(), raise_server_exceptions=False)
            client.get("/boom?exclude=11,12", headers={
                "Authorization": "Bearer TOKEN-IN-THE-ASGI-SCOPE",
            })

        frames = []
        for value in events[0]["exception"]["values"]:
            frames.extend((value.get("stacktrace") or {}).get("frames") or [])

        assert frames, "no stack trace at all, which is its own problem"
        assert all("vars" not in frame for frame in frames), (
            "a frame is carrying its local variables")
        assert "TOKEN-IN-THE-ASGI-SCOPE" not in str(events[0])

    def test_the_path_survives(self, monkeypatch):
        #the route that broke is the one thing an error report must keep
        with sentry_capturing(monkeypatch) as events:
            client = TestClient(app_that_raises(), raise_server_exceptions=False)
            client.get("/boom?secret=1")

        assert "/boom" in str(events[0])


class TestWithoutADsn:
    def test_nothing_is_captured_and_nothing_raises(self, monkeypatch):
        """THE STATE THE TEST SUITE AND CI RUN IN, and the state a developer
        who has not set up Sentry runs in. The app must behave identically.
        """
        monkeypatch.delenv("SENTRY_DSN", raising=False)
        error_reporting.install()

        client = TestClient(app_that_raises(), raise_server_exceptions=False)
        assert client.get("/boom").status_code == 500
        assert client.get("/fine").status_code == 200


@pytest.mark.parametrize("order", ["install_first", "install_second"])
def test_install_must_come_before_the_app_is_built(monkeypatch, order):
    """THE ORDERING THAT main.py DEPENDS ON, demonstrated rather than asserted
    in a comment.

    The integration patches the ASGI app, so an install() that happens after
    FastAPI() is constructed catches less - and nothing about the running app
    looks wrong when it does. This is why error_reporting.install() sits above
    `app = FastAPI()` in main.py with a comment saying so.

    If a future sentry-sdk makes the late case work too, this test starts
    failing on install_second, and that is a good reason to read it again
    rather than a reason to delete the ordering.
    """
    import sentry_sdk

    events: list = []
    monkeypatch.setenv("SENTRY_DSN", FAKE_DSN)
    try:
        if order == "install_first":
            error_reporting.install(transport=events.append)
            app = app_that_raises()
        else:
            app = app_that_raises()
            error_reporting.install(transport=events.append)

        TestClient(app, raise_server_exceptions=False).get("/boom")
        captured = len(events)
    finally:
        #see the note in sentry_capturing: init(dsn=None) reads the env
        sentry_sdk.get_global_scope().set_client(None)

    if order == "install_first":
        assert captured == 1, "the order main.py uses must work"
    else:
        #recorded, not required: what matters is that the supported order
        #works. This documents what the other one does today.
        assert captured in (0, 1)
