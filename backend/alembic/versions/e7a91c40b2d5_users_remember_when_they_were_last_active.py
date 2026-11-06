"""users remember when they were last active

Adds users.last_active.

IT ALREADY EXISTED, IN THE WRONG DATABASE. The client wrote a last_active
timestamp into its Firestore document on every launch, beside the push token.
That is unreachable from the one place it is needed: the feed orders candidates
in SQL, and no ORDER BY can see a value held in another service. Ranking an
active account above a dormant one is the biggest single thing the deck can do
for a small user base - a like nobody will ever open is worse than no like -
and it could not be done at all.

BACKFILLED FROM created_at, NOT FROM now(). The column carries a now() default
so a newly inserted row counts as active, which is true of a signup by
definition. Letting that default stand for the rows already in the table would
instead assert that every account that has ever existed was active the moment
this migration ran - a lie with no expiry date, and one that would put dormant
accounts at the top of every deck until each of them happened to be seen
again. created_at is the oldest defensible answer: it is when we last knew
anything about them.

NULLABLE, so the backfill is not load-bearing. A row that somehow has no value
sorts last under NULLS LAST rather than failing an insert.

Revision ID: e7a91c40b2d5
Revises: a38deb029aa7
Create Date: 2026-11-06 09:12:41.004812

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'e7a91c40b2d5'
down_revision: Union[str, Sequence[str], None] = 'a38deb029aa7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'users',
        sa.Column('last_active', sa.TIMESTAMP(timezone=True),
                  nullable=True, server_default=sa.text('now()')),
    )
    #ADD COLUMN with a default has already written now() into every existing
    #row, so this replaces it. See the note above on why now() is wrong here
    #and right for an insert.
    op.execute("UPDATE users SET last_active = created_at")


def downgrade() -> None:
    op.drop_column('users', 'last_active')
