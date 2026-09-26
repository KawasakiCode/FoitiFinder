"""The university is derived from the verified email, so this must not drift.

Two roots per institution (staff vs student mail) and department subdomains
make this fiddlier than it looks - and getting it wrong means a real student
shows up with no university, or the wrong one.
"""

import pytest

from university_domains import (
    UNIVERSITY_DOMAINS,
    UNIVERSITY_NAMES,
    is_university_email,
    university_name_for_email,
)


@pytest.mark.parametrize(
    "email, expected",
    [
        ("maria@uoa.gr", "National and Kapodistrian University of Athens"),
        #department subdomains are covered without being listed
        ("maria@di.uoa.gr", "National and Kapodistrian University of Athens"),
        ("nikos@mail.ntua.gr", "National Technical University of Athens"),
        #LONGEST MATCH: uom.edu.gr must not be shadowed by uom.gr
        ("eleni@uom.edu.gr", "University of Macedonia"),
        ("staff@uom.gr", "University of Macedonia"),
        #a separate root for the same university
        ("giannis@upnet.gr", "University of Patras"),
        ("giannis@upatras.gr", "University of Patras"),
        #case and stray dots must not matter
        ("MARIA@UOA.GR", "National and Kapodistrian University of Athens"),
        ("maria@uoa.gr.", "National and Kapodistrian University of Athens"),
    ],
)
def test_known_domains(email, expected):
    assert university_name_for_email(email) == expected


@pytest.mark.parametrize(
    "email",
    [None, "", "not-an-email", "someone@gmail.com", "someone@uoa.gr.evil.com"],
)
def test_unknown_or_malformed(email):
    assert university_name_for_email(email) is None


def test_a_lookalike_domain_does_not_match():
    """The check is a suffix match on '.root', not 'contains'."""
    assert university_name_for_email("me@uoa.gr.evil.com") is None
    assert university_name_for_email("me@notuoa.gr") is None
    assert is_university_email("me@uoa.gr.evil.com") is False


def test_empty_local_part_is_judged_on_the_domain_alone():
    """'@uoa.gr' resolves, and is_university_email accepts it too.

    Neither function validates the local part - they answer "which institution
    owns this domain". That is fine here because the address never comes from
    a user: it comes from the claims of a token Google signed, and Google does
    not issue accounts without a local part. Documented rather than "fixed" so
    the two functions keep agreeing with each other.
    """
    assert university_name_for_email("@uoa.gr") is not None
    assert is_university_email("@uoa.gr") is True


def test_every_allowed_domain_has_a_name():
    """A domain that passes signup but has no name would store NULL."""
    missing = sorted(UNIVERSITY_DOMAINS - set(UNIVERSITY_NAMES))
    assert not missing, f"no university name for: {missing}"


def test_name_lookup_agrees_with_the_signup_gate():
    """Anything that can sign up must resolve to a university, and vice versa."""
    for domain in UNIVERSITY_DOMAINS:
        email = f"student@{domain}"
        assert is_university_email(email)
        assert university_name_for_email(email) is not None
