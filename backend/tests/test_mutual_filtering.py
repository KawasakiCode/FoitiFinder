"""The deck only offers people who could offer you back.

THE BUG THIS FILE IS ABOUT. /users/feed applied the VIEWER's age range and
gender preference and stopped there, so it handed out cards belonging to
people whose own filters would never have shown the viewer. A right swipe on
one of them could not become a match whatever the other person did - they were
never going to see the card - and the app presented that as "no match yet",
indistinguishable from someone who had simply not swiped.

It is the most expensive kind of bug this app can have: it spends the one
thing a dating app runs on, somebody's willingness to keep swiping, on cards
that cannot pay out.

WHAT THE RULE IS NOW. Four filters, two in each direction:

    mine    their age must be in my range, their gender in my preference
    theirs  my age must be in their range, my gender in their preference

AND NULL ALWAYS PASSES, in all four. An unfinished profile has not said no to
anybody, and hiding people who have not filled a field in yet would empty the
deck of exactly the new accounts that most need to be seen. Every test below
that asserts somebody is HIDDEN therefore has a counterpart asserting that the
same profile with the field unset is SHOWN - the two together are the rule,
and only one of them is the bug.
"""


def feed_ids(as_user, viewer):
    return [card["id"] for card in as_user(viewer).get("/users/feed").json()]


def clear(db, user, **fields):
    """Blank a field make_user cannot be asked to leave blank.

    The fixture builds `birthday` from its `age` argument, so passing
    birthday=None is "multiple values for keyword argument". Rather than bend
    a fixture the whole suite shares for the two tests that need an unfinished
    profile, they are made and then emptied.
    """
    for name, value in fields.items():
        setattr(user, name, value)
    db.flush()
    return user


class TestTheirAgeRangeIsRespected:
    def test_somebody_too_young_for_them_is_not_shown(self, as_user, make_user):
        """I am 20; they only want 30 and up. They would never see me."""
        me = make_user(name="Me", age=20)
        make_user(name="Picky", age=35, min_age_range=30, max_age_range=40)

        assert feed_ids(as_user, me) == []

    def test_somebody_too_old_for_them_is_not_shown(self, as_user, make_user):
        me = make_user(name="Me", age=35, min_age_range=18, max_age_range=99)
        make_user(name="Picky", age=20, min_age_range=18, max_age_range=25)

        assert feed_ids(as_user, me) == []

    def test_but_inside_their_range_is_fine(self, as_user, make_user):
        me = make_user(name="Me", age=22)
        them = make_user(name="Fine", age=24, min_age_range=20, max_age_range=30)

        assert feed_ids(as_user, me) == [them.id]

    def test_an_unset_range_on_their_side_passes(self, as_user, make_user):
        #they have not said who they want, which is not the same as not
        #wanting me
        me = make_user(name="Me", age=19)
        them = make_user(name="Open", age=30,
                         min_age_range=None, max_age_range=None)

        assert feed_ids(as_user, me) == [them.id]

    def test_and_so_does_a_viewer_with_no_birthday(
        self, db, as_user, make_user
    ):
        """NOTHING TO COMPARE IS NOT A REASON TO HIDE EVERYBODY.

        A row exists from registration and the birthday arrives later on the
        setup page, so an account mid-signup has none. Refusing to evaluate
        the other side's range must leave the candidate in rather than out.
        """
        me = clear(db, make_user(name="Me"), birthday=None)
        them = make_user(name="Picky", age=35,
                         min_age_range=30, max_age_range=40)

        assert feed_ids(as_user, me) == [them.id]


class TestTheirGenderPreferenceIsRespected:
    def test_a_woman_looking_for_women_does_not_see_a_man(
        self, as_user, make_user
    ):
        me = make_user(name="Me", gender="Male", preferred_gender="Women")
        make_user(name="Her", gender="Female", preferred_gender="Women")

        assert feed_ids(as_user, me) == []

    def test_and_the_other_way_round(self, as_user, make_user):
        me = make_user(name="Me", gender="Female", preferred_gender="Men")
        make_user(name="Him", gender="Male", preferred_gender="Men")

        assert feed_ids(as_user, me) == []

    def test_everyone_accepts_anybody(self, as_user, make_user):
        me = make_user(name="Me", gender="Male", preferred_gender="Women")
        them = make_user(name="Her", gender="Female",
                         preferred_gender="Everyone")

        assert feed_ids(as_user, me) == [them.id]

    def test_a_multiple_selection_accepts_either(self, as_user, make_user):
        me = make_user(name="Me", gender="Male", preferred_gender="Everyone")
        them = make_user(name="Her", gender="Female",
                         preferred_gender="Men,Women")

        assert feed_ids(as_user, me) == [them.id]

    def test_spaces_in_their_selection_do_not_break_it(
        self, as_user, make_user
    ):
        #the string is assembled by the client, and 'Men, Women' is as likely
        #as 'Men,Women'
        me = make_user(name="Me", gender="Male", preferred_gender="Everyone")
        them = make_user(name="Her", gender="Female",
                         preferred_gender="Women, Men")

        assert feed_ids(as_user, me) == [them.id]

    def test_women_is_not_read_as_containing_men(self, as_user, make_user):
        """THE TRAP THIS FILTER WAS ONE CHARACTER FROM FALLING INTO.

        The obvious way to look inside a comma separated string in SQL is
        LIKE '%Men%' - and 'Women' contains the letters of 'men'. That happens
        to work only because Postgres LIKE is case sensitive AND the client
        happens to capitalise every token. Two coincidences holding up a
        filter that decides whether a man is shown to a woman seeking women.

        Tokens are split and compared whole, so neither coincidence matters.
        """
        me = make_user(name="Me", gender="Male", preferred_gender="Everyone")
        make_user(name="Her", gender="Female", preferred_gender="Women")

        assert feed_ids(as_user, me) == []

    def test_an_unset_preference_on_their_side_passes(
        self, as_user, make_user
    ):
        me = make_user(name="Me", gender="Male", preferred_gender="Everyone")
        them = make_user(name="Her", gender="Female", preferred_gender=None)

        assert feed_ids(as_user, me) == [them.id]

    def test_and_so_does_a_viewer_with_no_gender(self, as_user, make_user):
        #mid-signup again: their preference cannot be evaluated against a
        #gender that is not there, so it goes unchecked rather than excluding
        me = make_user(name="Me", gender=None, preferred_gender="Everyone")
        them = make_user(name="Her", gender="Female",
                         preferred_gender="Women")

        assert feed_ids(as_user, me) == [them.id]


class TestBothDirectionsAtOnce:
    def test_a_mutual_fit_is_shown(self, as_user, make_user):
        me = make_user(name="Me", gender="Male", age=22,
                       preferred_gender="Women",
                       min_age_range=20, max_age_range=26)
        them = make_user(name="Her", gender="Female", age=23,
                         preferred_gender="Men",
                         min_age_range=21, max_age_range=25)

        assert feed_ids(as_user, me) == [them.id]

    def test_a_one_sided_fit_is_not(self, as_user, make_user):
        """THE WHOLE POINT, IN ONE TEST. She fits everything I asked for; I
        fit nothing she asked for. Before this change she was in my deck, and
        a like sent to her was guaranteed to go nowhere.
        """
        me = make_user(name="Me", gender="Male", age=22,
                       preferred_gender="Women",
                       min_age_range=18, max_age_range=99)
        make_user(name="Her", gender="Female", age=23,
                  preferred_gender="Women",
                  min_age_range=30, max_age_range=40)

        assert feed_ids(as_user, me) == []

    def test_the_viewer_s_own_filters_still_apply(self, as_user, make_user):
        #the reverse direction is ADDED, not swapped in: somebody who would
        #happily see me, whom I did not ask for, is still out
        me = make_user(name="Me", gender="Male", age=22,
                       preferred_gender="Women")
        make_user(name="Him", gender="Male", age=22,
                  preferred_gender="Everyone")

        assert feed_ids(as_user, me) == []

    def test_a_blank_profile_on_both_sides_still_appears(
        self, db, as_user, make_user
    ):
        """FOUR UNEVALUATABLE FILTERS MUST NOT MULTIPLY INTO AN EMPTY DECK.

        This is the case that would make the app unusable on day one: two
        accounts that have just registered and filled nothing in. Every filter
        has to pass, in both directions, or the first two users of the service
        cannot see each other.
        """
        me = clear(db, make_user(name="Me", gender=None,
                                 preferred_gender=None,
                                 min_age_range=None, max_age_range=None),
                   birthday=None)
        them = clear(db, make_user(name="Them", gender=None,
                                   preferred_gender=None,
                                   min_age_range=None, max_age_range=None),
                     birthday=None)

        assert feed_ids(as_user, me) == [them.id]
