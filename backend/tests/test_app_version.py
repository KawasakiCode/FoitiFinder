"""The minimum supported build, and why it is reachable by anybody.

RAISING THIS NUMBER LOCKS PEOPLE OUT, so the endpoint serving it has to be
reachable by exactly the clients it is about to refuse - which is why it takes
no token and touches no database. A build old enough to be turned away may
also be old enough to get signing in wrong, and an update wall that only
appears after a successful login is a wall with a door beside it.
"""

import app_version


class TestTheEndpoint:
    def test_it_needs_no_token(self, client):
        #NO as_user HERE, deliberately: this is the whole point of the test.
        #Every other endpoint in the app answers 401 to this.
        response = client.get("/app/minimum-build")
        assert response.status_code == 200

    def test_it_answers_the_minimum_for_android(self, client):
        body = client.get("/app/minimum-build").json()
        assert body["android"] == app_version.MINIMUM_BUILD["android"]

    def test_it_is_an_integer(self, client):
        #THE CLIENT COMPARES IT TO versionCode, which is an int. A string here
        #would be compared as a string on some future client and decide that
        #build 9 is newer than build 10.
        body = client.get("/app/minimum-build").json()
        assert isinstance(body["android"], int)

    def test_it_names_the_platform_rather_than_answering_bare(self, client):
        #the two stores review and release on their own schedules, so a single
        #shared number is wrong the first week iOS exists
        body = client.get("/app/minimum-build").json()
        assert isinstance(body, dict)


class TestTheNumberItself:
    def test_it_blocks_nobody_yet(self):
        #1 IS THE FIRST BUILD THERE HAS EVER BEEN. The check had to ship before
        #it was needed - a build that never asks can never be told to stop -
        #so this starts as low as it can go, and anything above 1 should be a
        #deliberate commit with a reason in its message.
        assert app_version.MINIMUM_BUILD["android"] == 1
