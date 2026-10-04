"""rename the long-term dating intention

Revision ID: b7c2f9a41e30
Revises: 89617ccf5db8
Create Date: 2026-10-04

A DATA migration, not a schema one - nothing about the columns changes.

The catalogue answer 'A long-term relationship' is now 'Something serious',
and the stored value IS the canonical string (see l10n/catalogue_labels.dart):
rows keeping the old text would display as raw English for every user,
because the label map no longer has an entry for it, and they would never
match a preference that now stores the new string.

Both columns hold it: dating_intention is one answer, and
preferred_dating_intention is an array of acceptable answers.
"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'b7c2f9a41e30'
down_revision: Union[str, Sequence[str], None] = '89617ccf5db8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

OLD = "A long-term relationship"
NEW = "Something serious"


def _rename(old: str, new: str) -> None:
    op.execute(
        f"UPDATE users SET dating_intention = '{new}' "
        f"WHERE dating_intention = '{old}'"
    )
    #array_replace swaps the element in place and leaves the rest alone
    op.execute(
        f"UPDATE users SET preferred_dating_intention = "
        f"array_replace(preferred_dating_intention, '{old}', '{new}') "
        f"WHERE '{old}' = ANY(preferred_dating_intention)"
    )


def upgrade() -> None:
    """Upgrade schema."""
    _rename(OLD, NEW)


def downgrade() -> None:
    """Downgrade schema."""
    _rename(NEW, OLD)
