"""religion and politics are one answer

Revision ID: 89617ccf5db8
Revises: 0ac91535e4a0
Create Date: 2026-10-04

HAND-WRITTEN. Autogenerate saw only the nullability change: it compares types
but cannot invent a conversion, so it would have left two text[] columns the
model now reads as text, and every read would have come back as a list.

text[] -> text, KEEPING THE FIRST ANSWER. Someone who ticked
{Christian, Spiritual} becomes 'Christian' - the picker offered several, so the
first is the only defensible choice, and an empty array becomes NULL ("not
answered"), which is what the scalar columns mean everywhere else.

The order of the three statements matters:
  1. drop the default, because '{}' is not a valid text
  2. drop NOT NULL, because an empty array is about to become NULL
  3. then convert, using [1] to take the first element
"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = '89617ccf5db8'
down_revision: Union[str, Sequence[str], None] = '0ac91535e4a0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

COLUMNS = ("religion", "political_view")


def upgrade() -> None:
    """Upgrade schema."""
    for column in COLUMNS:
        op.execute(f"ALTER TABLE users ALTER COLUMN {column} DROP DEFAULT")
        op.execute(f"ALTER TABLE users ALTER COLUMN {column} DROP NOT NULL")
        op.execute(
            f"ALTER TABLE users ALTER COLUMN {column} TYPE varchar "
            f"USING {column}[1]"
        )


def downgrade() -> None:
    """Downgrade schema."""
    for column in COLUMNS:
        #a single answer becomes a one-element array again; NULL becomes empty
        op.execute(
            f"ALTER TABLE users ALTER COLUMN {column} TYPE varchar[] USING "
            f"(CASE WHEN {column} IS NULL THEN '{{}}'::varchar[] "
            f"ELSE ARRAY[{column}] END)"
        )
        op.execute(
            f"ALTER TABLE users ALTER COLUMN {column} SET DEFAULT '{{}}'"
        )
        op.execute(f"ALTER TABLE users ALTER COLUMN {column} SET NOT NULL")
