#Pure matching/preference helpers.
#
#Deliberately has NO database, FastAPI or Firebase imports so it can be unit
#tested on its own. Keeping logic like this separate from the web layer is what
#makes it cheap to test and easy to re-read later.

from typing import List, Optional


def preference_to_genders(preferred_gender: Optional[str]) -> Optional[List[str]]:
    """Map the viewer's interest selection (who they want to see) to the
    ``gender`` values stored on candidate profiles.

    The app stores ``preferred_gender`` as a comma separated string of ``"Men"``,
    ``"Women"`` and/or ``"Everyone"``, while a profile's own ``gender`` is
    ``"Male"`` or ``"Female"``.

    Returns:
        - ``None`` when there is no restriction (no selection, or "Everyone").
          The caller should then apply no gender filter.
        - otherwise a list of acceptable ``gender`` values, e.g. ``["Male"]``.
    """
    if not preferred_gender:
        return None

    selected = {part.strip() for part in preferred_gender.split(",") if part.strip()}
    if not selected or "Everyone" in selected:
        return None

    mapping = {"Men": "Male", "Women": "Female"}
    genders = [mapping[s] for s in selected if s in mapping]
    return genders or None


#THE SAME MAPPING, READ THE OTHER WAY. preference_to_genders answers "whose
#profiles may I be shown"; this answers "what must THEY have selected for me
#to be shown to them", which is the half the feed was missing.
_GENDER_TO_PREFERENCE = {"Male": "Men", "Female": "Women"}


def gender_to_preference_token(gender: Optional[str]) -> Optional[str]:
    """The ``preferred_gender`` token somebody must have picked to see `gender`.

    ``"Male"`` -> ``"Men"``. Returns ``None`` when the gender is absent or is
    not one of the two the preference vocabulary can express, which the caller
    must read as "no reverse gender filter can be applied" rather than as
    "nobody matches" - refusing to show a profile because its gender has no
    token would hide it from everybody.
    """
    if not gender:
        return None
    return _GENDER_TO_PREFERENCE.get(gender.strip())
