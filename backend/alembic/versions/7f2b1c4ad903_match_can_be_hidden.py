"""a match can be withdrawn by either side

Two columns on `matches`. Either participant can end a match that has already
been revealed - which decline deliberately refuses to do, because a handle
that has been read cannot be taken back - and the row stops being returned to
both of them.

HIDDEN RATHER THAN DELETED, which is the whole point of doing it this way: the
record of who confirmed, when, and in which order survives for anyone reading
the database, while the app stops serving somebody's Instagram handle back to
a person they have withdrawn from. Deleting would have destroyed the only
evidence that two people ever connected.

hidden_by_user_id is ON DELETE SET NULL rather than CASCADE: if the person who
withdrew later deletes their account, the match must stay hidden. CASCADE
would take the whole match row with them and resurrect nothing - but SET NULL
keeps the hidden_at timestamp doing its job with the name simply gone.

Additive and nullable, so it applies to a live database with no backfill and
no lock worth worrying about.

Revision ID: 7f2b1c4ad903
Revises: 1245f3a506ff
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7f2b1c4ad903'
down_revision: Union[str, Sequence[str], None] = '1245f3a506ff'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        'matches',
        sa.Column('hidden_at', sa.TIMESTAMP(timezone=True), nullable=True),
    )
    op.add_column(
        'matches',
        sa.Column('hidden_by_user_id', sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        'fk_matches_hidden_by_user',
        'matches', 'users',
        ['hidden_by_user_id'], ['id'],
        ondelete='SET NULL',
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint('fk_matches_hidden_by_user', 'matches', type_='foreignkey')
    op.drop_column('matches', 'hidden_by_user_id')
    op.drop_column('matches', 'hidden_at')
