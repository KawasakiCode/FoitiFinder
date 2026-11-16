"""That the limits actually refuse, and refuse the right person.

WHY A LIMITER NEEDS TESTS MORE THAN MOST CODE. Its failure mode is silence: a
limiter that counts wrong, or keys every caller to the same bucket, or never
fires at all, looks exactly like a working one from the outside as long as
nobody is attacking you. The day it matters is the day nobody is watching.

THE KEYING IS THE PART WORTH PINNING. Keyed too narrowly and it never fires;
keyed too broadly and one busy user locks out a university. Both are one
character's difference in a format string.
"""

import time

import pytest

import rate_limit


class TestTheCounterItself:
    def test_it_allows_up_to_the_limit_and_then_refuses(self):
        for _ in range(3):
            assert rate_limit._hit("k", 3, 60) is None
        assert rate_limit._hit("k", 3, 60) is not None

    def test_the_wait_it_reports_is_what_is_left_of_the_window(self):
        rate_limit._hit("k", 1, 60)
        wait = rate_limit._hit("k", 1, 60)
        assert wait is not None and 0 < wait <= 60

    def test_a_new_window_starts_clean(self):
        #A SHORT WINDOW RATHER THAN A CLOCK PATCH. _hit reads time.monotonic
        #directly, and a test that patches it is testing the patch.
        assert rate_limit._hit("k", 1, 0.05) is None
        assert rate_limit._hit("k", 1, 0.05) is not None
        time.sleep(0.06)
        assert rate_limit._hit("k", 1, 0.05) is None

    def test_different_keys_do_not_share_a_budget(self):
        assert rate_limit._hit("a", 1, 60) is None
        assert rate_limit._hit("b", 1, 60) is None

    def test_reset_forgets_everything(self):
        rate_limit._hit("k", 1, 60)
        rate_limit.reset()
        assert rate_limit._hit("k", 1, 60) is None


class TestWhichAddressItBelieves:
    """X-Forwarded-For, and the mistake that makes the whole thing pointless."""

    def _request(self, header=None, peer="10.0.0.1"):
        class _Client:
            host = peer

        class _Request:
            headers = {} if header is None else {"x-forwarded-for": header}
            client = _Client()

        return _Request()

    def test_with_no_header_it_uses_the_peer(self):
        assert rate_limit.client_ip(self._request()) == "10.0.0.1"

    def test_it_takes_the_LAST_entry_not_the_first(self):
        #THE WHOLE POINT. Anybody can send X-Forwarded-For, so the entries a
        #client wrote come first and the one Render's proxy appended comes
        #last. Reading the first - which is the usual way round and what most
        #examples show - would let a caller pick their own rate limit key by
        #sending a header, and the limiter would be decorative.
        forwarded = "1.2.3.4, 5.6.7.8, 203.0.113.9"
        assert rate_limit.client_ip(self._request(forwarded)) == "203.0.113.9"

    def test_spaces_do_not_become_part_of_the_key(self):
        assert rate_limit.client_ip(self._request("1.1.1.1,   2.2.2.2")) == "2.2.2.2"


class TestThroughTheEndpoint:
    def test_the_profile_limit_eventually_says_429(self, as_user, make_user):
        me = make_user(name="Me", gender="Male", preferred_gender="Women")
        her = make_user(name="Her", gender="Female")

        client = as_user(me)
        codes = {client.get(f"/users/{her.id}/profile").status_code
                 for _ in range(45)}

        assert 200 in codes, "the limit fired before any request succeeded"
        assert 429 in codes, "40 requests a minute was never enforced"

    def test_the_refusal_says_how_long_to_wait(self, as_user, make_user):
        me = make_user(name="Me", gender="Male", preferred_gender="Women")
        her = make_user(name="Her", gender="Female")

        client = as_user(me)
        refused = None
        for _ in range(45):
            response = client.get(f"/users/{her.id}/profile")
            if response.status_code == 429:
                refused = response
                break

        assert refused is not None
        #A CLIENT TOLD TO WAIT 0 RETRIES IMMEDIATELY, which is the flood again
        assert int(refused.headers["retry-after"]) >= 1

    def test_one_users_flood_does_not_refuse_another(self, as_user, make_user):
        #THE KEYING, END TO END. If the bucket were per endpoint rather than
        #per endpoint and uid, one busy account would lock out everybody - and
        #on a university NAT that is not hypothetical.
        her = make_user(name="Her", gender="Female")
        noisy = make_user(name="Noisy", gender="Male", preferred_gender="Women")
        quiet = make_user(name="Quiet", gender="Male", preferred_gender="Women")

        noisy_client = as_user(noisy)
        for _ in range(45):
            noisy_client.get(f"/users/{her.id}/profile")

        assert as_user(noisy).get(f"/users/{her.id}/profile").status_code == 429
        assert as_user(quiet).get(f"/users/{her.id}/profile").status_code == 200

    def test_the_feed_and_the_profile_have_separate_budgets(
        self, as_user, make_user
    ):
        #BUCKETS ARE NAMED, so exhausting one must not spend another. Sharing
        #them would mean a user who scrolled their deck could not then open a
        #card, which is the one journey this app is built around.
        me = make_user(name="Me", gender="Male", preferred_gender="Women")
        her = make_user(name="Her", gender="Female")

        client = as_user(me)
        for _ in range(45):
            client.get(f"/users/{her.id}/profile")

        assert client.get(f"/users/{her.id}/profile").status_code == 429
        assert client.get("/users/feed").status_code == 200
