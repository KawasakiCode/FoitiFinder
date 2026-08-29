#A test file. pytest automatically discovers any file named test_*.py and runs
#every function named test_* inside it.
#
#The whole idea of a test: call your code with a known input, then `assert` that
#the output is what you expect. If the assert is true, the test passes (green).
#If it's false (or the code throws), the test fails (red) and pytest shows you
#exactly which case broke. That's it.

from preferences.preferences import preference_to_genders


def test_no_interest_means_no_filter():
    #None / empty input -> no restriction (caller applies no gender filter)
    assert preference_to_genders(None) is None
    assert preference_to_genders("") is None


def test_everyone_means_no_filter():
    #"Everyone" must never restrict, even if combined with other choices
    assert preference_to_genders("Everyone") is None
    assert preference_to_genders("Men,Everyone") is None


def test_single_interest_maps_to_one_gender():
    #"Men" should match profiles whose stored gender is "Male"
    assert preference_to_genders("Men") == ["Male"]
    assert preference_to_genders("Women") == ["Female"]


def test_both_interests_map_to_both_genders():
    result = preference_to_genders("Men,Women")
    #order isn't important here, so compare as sets
    assert set(result) == {"Male", "Female"}


def test_whitespace_and_unknown_values_are_ignored():
    #stray spaces shouldn't matter, and a junk value shouldn't crash it
    assert preference_to_genders(" Men , Women ") is not None
    assert preference_to_genders("Banana") is None
