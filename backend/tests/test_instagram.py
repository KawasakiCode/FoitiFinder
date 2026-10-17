import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest  # noqa: E402

from instagram import normalise_instagram_handle  # noqa: E402


@pytest.mark.parametrize("raw", [
    "maria.pap",
    "@maria.pap",
    " maria.pap ",
    "MARIA.PAP",
    "instagram.com/maria.pap",
    "www.instagram.com/maria.pap",
    "https://www.instagram.com/maria.pap/",
    "https://instagram.com/maria.pap?igsh=MXY2bGJ0",
    "HTTPS://Instagram.com/Maria.Pap",
    "instagram.com/maria.pap#",
])
def test_every_way_of_writing_the_same_handle(raw):
    assert normalise_instagram_handle(raw) == "maria.pap"


def test_underscores_and_digits_survive():
    assert normalise_instagram_handle("_nikos_99") == "_nikos_99"


@pytest.mark.parametrize("raw", [
    None,
    "",
    "   ",
    #no chat in the app, so a handle is required - these are all rejections,
    #not "cleared"
    "@",
    "instagram.com/",
])
def test_nothing_is_not_a_handle(raw):
    assert normalise_instagram_handle(raw) is None


@pytest.mark.parametrize("raw", [
    "maria pap",        # spaces are not allowed in a handle
    "maria-pap",        # nor hyphens
    "maria@pap",        # an @ anywhere but the front
    "maria/pap",        # a deeper path is not a profile
    ".maria",           # Instagram forbids a leading full stop
    "maria.",           # and a trailing one
    "maria..pap",       # and two in a row
    "a" * 31,           # 30 is the limit
])
def test_shapes_that_cannot_be_a_handle(raw):
    assert normalise_instagram_handle(raw) is None


def test_the_limit_itself_is_allowed():
    assert normalise_instagram_handle("a" * 30) == "a" * 30


def test_an_email_is_not_a_handle():
    #someone will type their email into a field that asks for a username
    assert normalise_instagram_handle("maria@uom.edu.gr") is None
