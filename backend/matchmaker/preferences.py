#Pure matching/preference helpers.
#
#Deliberately has NO database, FastAPI or Firebase imports so it can be unit
#tested on its own. Keeping logic like this separate from the web layer is what
#makes it cheap to test and easy to re-read later.

from typing import List, Optional


def interests_to_genders(interests: Optional[str]) -> Optional[List[str]]:
    """Map the viewer's interest selection (who they want to see) to the
    ``gender`` values stored on candidate profiles.

    The app stores ``interests`` as a comma separated string of ``"Men"``,
    ``"Women"`` and/or ``"Everyone"``, while a profile's own ``gender`` is
    ``"Male"`` or ``"Female"``.

    Returns:
        - ``None`` when there is no restriction (no selection, or "Everyone").
          The caller should then apply no gender filter.
        - otherwise a list of acceptable ``gender`` values, e.g. ``["Male"]``.
    """
    if not interests:
        return None

    selected = {part.strip() for part in interests.split(",") if part.strip()}
    if not selected or "Everyone" in selected:
        return None

    mapping = {"Men": "Male", "Women": "Female"}
    genders = [mapping[s] for s in selected if s in mapping]
    return genders or None
