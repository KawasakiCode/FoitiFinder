"""The deck tells the server what it already holds, so a page is never wasted.

THE BUG THIS FILE EXISTS FOR, and it took three attempts to state correctly.

/users/feed leaves out anybody it has a swipe row for. A swipe sitting in
SwipeQueue waiting for a network has no row yet, so the server kept offering
those people and the deck discarded them on arrival. That is merely wasteful
while the discarded set is small.

IT STOPS BEING MERELY WASTEFUL when the discarded set grows past one page.
The deck filters every reply against the cards it holds UNION the queued
swipes; once that union is bigger than a page, an entire page can land inside
it and the deck adds nobody. Two separate things followed from that, and they
have separate fixes:

  WASTE. A page that adds nobody is a round trip for nothing, and the deck
  refetches immediately because it is still under its threshold. Measured
  here: 21 requests for 60 swipes where six would do. THE EXCLUSIONS fix this,
  and the last test in this file is what pins it.

  A WRONG ANSWER. Three unproductive pages in a row tripped
  _kGiveUpAfterEmptyFetches and announced "no more profiles" - latched for the
  session - with people still unseen. Simulated at a pool of 80 with a queue
  that never flushed: 75 swiped, 5 never shown. THE LATCH REMOVAL fixes that,
  in home_page.dart, and nothing in this file covers it - see the note on
  TestTheOfflineQueueCase.

WHY IT IS NOT ABOUT RANKING, which is what I assumed twice. A page is drawn
WITHOUT replacement and returns `limit` DISTINCT rows, so with at most 19
cards in hand a 20-row page always contains somebody new. Weighting changes
which rows repeat, never how many distinct ones come back. The queue is the
only thing that can push the filtered-out set past a page, and the failure
reproduces with every candidate scored identically.

WHAT THE FIX IS. The client sends both halves as `exclude`, so the server
never returns a card the deck would throw away - which makes "this reply added
nobody" mean "the pool is down to what I am holding", and lets the deck trust
an empty reply instead of guessing from three non-empty ones.
"""


def feed(as_user, viewer, **params):
    query = "&".join(f"{k}={v}" for k, v in params.items())
    url = "/users/feed" + (f"?{query}" if query else "")
    response = as_user(viewer).get(url)
    assert response.status_code == 200, response.text
    return [card["id"] for card in response.json()]


class TestExcludingWhatTheClientHolds:
    def test_an_excluded_id_is_not_returned(self, as_user, make_user):
        me = make_user(name="Me")
        a, b = make_user(name="A"), make_user(name="B")

        assert feed(as_user, me, exclude=a.id) == [b.id]

    def test_several_can_be_excluded(self, as_user, make_user):
        me = make_user(name="Me")
        pool = [make_user(name=f"P{i}") for i in range(5)]
        drop = pool[:3]

        left = feed(as_user, me,
                    exclude=",".join(str(user.id) for user in drop))

        assert sorted(left) == sorted(user.id for user in pool[3:])

    def test_excluding_everybody_returns_an_empty_page(
        self, as_user, make_user
    ):
        """THE SIGNAL THE DECK NOW RELIES ON. With the held cards excluded, an
        empty reply is what "there is nobody else" looks like - so the deck can
        stop on it rather than counting how many pages added nothing.
        """
        me = make_user(name="Me")
        pool = [make_user(name=f"P{i}") for i in range(4)]

        assert feed(as_user, me,
                    exclude=",".join(str(u.id) for u in pool)) == []

    def test_a_malformed_list_is_ignored_rather_than_refused(
        self, as_user, make_user
    ):
        """LENIENT ON PURPOSE. Every id here can only remove a candidate from
        the caller's own deck, so nothing is disclosed and nobody else is
        affected - and a 422 would break the swipe deck over a stray comma.
        """
        me = make_user(name="Me")
        them = make_user(name="Them")

        assert feed(as_user, me, exclude=",,abc,") == [them.id]
        assert feed(as_user, me, exclude="") == [them.id]

    def test_excluding_somebody_else_s_id_affects_nobody_else(
        self, as_user, make_user
    ):
        #the exclusions are scoped to the request that sent them, which is
        #worth pinning: they are the only user-supplied input to this query
        me, other = make_user(name="Me"), make_user(name="Other")
        them = make_user(name="Them")

        feed(as_user, me, exclude=them.id)

        assert them.id in feed(as_user, other)


class TestThePageSize:
    def test_it_defaults_to_twenty(self, as_user, make_user):
        """TWENTY, WHICH IS WHAT THE DECK ALWAYS THOUGHT IT GOT. The server
        used to hardcode 10 while home_page declared batchSize = 20 and sent
        nothing, and the README said 20 - three descriptions, none agreeing.
        """
        me = make_user(name="Me")
        for i in range(25):
            make_user(name=f"P{i}")

        assert len(feed(as_user, me)) == 20

    def test_a_client_can_ask_for_fewer(self, as_user, make_user):
        me = make_user(name="Me")
        for i in range(10):
            make_user(name=f"P{i}")

        assert len(feed(as_user, me, limit=3)) == 3

    def test_a_huge_request_is_capped(self, as_user, make_user):
        #the number arrives from a client, so it cannot be the whole table
        me = make_user(name="Me")
        for i in range(45):
            make_user(name=f"P{i}")

        assert len(feed(as_user, me, limit=10000)) == 40

    def test_a_nonsense_size_still_returns_a_page(self, as_user, make_user):
        #clamped rather than refused: this is a buffer size, not a user's
        #intent, and a deck that fails to refill is worse than one that
        #refills by a different amount than it asked for
        me = make_user(name="Me")
        for i in range(5):
            make_user(name=f"P{i}")

        assert len(feed(as_user, me, limit=0)) == 1
        assert len(feed(as_user, me, limit=-7)) == 1


class TestTheOfflineQueueCase:
    """The deck's real refill loop, with a queue that never flushes.

    SWIPES ARE NEVER DELIVERED HERE, which is the state SwipeQueue exists for:
    the feed answers, POST /swipes does not, and the queue grows without bound.

    WHAT EACH TEST BELOW ACTUALLY PINS, because the two halves of the fix are
    not both testable from here and it would be easy to believe otherwise:

      the two "everybody is reached" tests pin that the SERVER can support a
      complete walk. They pass with or without the exclusions, because the
      loop modelled here no longer gives up after three unproductive pages -
      so without them it simply takes more requests to get there. What they
      would catch is an exclusion bug that dropped candidates for good.

      test_and_it_does_not_take_a_request_per_swipe is the regression test for
      the exclusions themselves, and the only one here that fails without
      them: 21 requests for 60 swipes against 6.

    THE MISSED-CANDIDATES FAILURE WAS THE CLIENT'S LATCH, not this endpoint.
    _fetchesWithNothingNew gave up after three pages that added nobody, and on
    a bad network that arrives in about forty swipes - simulated at 75 of 80
    shown. Removing it is a change in home_page.dart, and home_page cannot be
    pumped in a widget test (it reaches for FirebaseAuth and ApiService in
    initState), so nothing here can cover it. What this file does is make the
    removal safe: with the held cards excluded, an unproductive page means the
    pool is down to what the deck is holding, so an empty reply is a
    sufficient stop signal and no counter has to guess.
    """

    def deck_walk(self, as_user, me, pool_size, page=20, threshold=10):
        """Mirror home_page._fetchMoreCards with nothing ever flushed."""
        deck: list[int] = []
        queued: set[int] = set()
        seen: set[int] = set()
        requests = 0
        done = False

        for _ in range(pool_size * 4):
            if len(deck) < threshold and not done:
                known = set(deck) | queued
                rows = feed(as_user, me, limit=page,
                            exclude=",".join(str(i) for i in known) or "0")
                requests += 1
                fresh = [i for i in rows if i not in known]
                if not fresh:
                    #THE ONLY STOP CONDITION LEFT. With `known` excluded, a
                    #page that adds nobody is a page the server had nobody
                    #for - so an empty reply and a useless reply are now the
                    #same thing, and no counter is needed to tell them apart.
                    if not rows:
                        done = True
                else:
                    deck.extend(fresh)
            if not deck:
                break
            card = deck.pop(0)
            seen.add(card)
            #queued, never flushed: the server will keep not knowing
            queued.add(card)

        return seen, requests

    def test_everybody_is_reached_with_a_queue_that_never_flushes(
        self, as_user, make_user
    ):
        """A COMPLETE WALK IS POSSIBLE, which is the server's half.

        The pool is deliberately bigger than a page and bigger than the point
        at which the queued set overtakes one - the conditions under which the
        deck used to stop early. Nobody may be dropped on the way.
        """
        me = make_user(name="Me")
        pool = {make_user(name=f"P{i}").id for i in range(80)}

        seen, _ = self.deck_walk(as_user, me, pool_size=80)

        missed = pool - seen
        assert not missed, f"{len(missed)} candidates were never shown"

    def test_and_with_the_old_page_size_too(self, as_user, make_user):
        #10 was the old hardcoded page, and the size at which a queued set
        #overtakes a page soonest. The exclusions are what make it survive.
        me = make_user(name="Me")
        pool = {make_user(name=f"P{i}").id for i in range(40)}

        seen, _ = self.deck_walk(as_user, me, pool_size=40, page=10)

        assert pool - seen == set()

    def test_and_it_does_not_take_a_request_per_swipe(
        self, as_user, make_user
    ):
        """THE REGRESSION TEST FOR THE EXCLUSIONS, and the only one here that
        fails without them.

        Every page is now entirely new, so the deck tops up by a full page
        rather than by whatever survived its own filter. Measured against a
        server that ignores `exclude`: 21 requests for these 60 swipes, where
        the pages are 20 and six would do. That is the difference between a
        request per handful of swipes and a request per swipe, on the screen
        people spend all their time on.
        """
        me = make_user(name="Me")
        for i in range(60):
            make_user(name=f"P{i}")

        seen, requests = self.deck_walk(as_user, me, pool_size=60)

        assert len(seen) == 60
        #60 swiped, pages of 20: a handful of requests, nowhere near 60
        assert requests <= 10, f"{requests} requests for 60 swipes"
