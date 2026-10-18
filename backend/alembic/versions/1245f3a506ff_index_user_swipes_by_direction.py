"""index user_swipes by direction

Two composite indexes for the two directions this table is read in:
(user_id, target_id) is "what have I done", (target_id, action) is "who liked
me". Both are on the feed's path, which is the most requested query in the
app, and until now the table had an index on `id` only - which nothing
filters on.

Index-only, so there is no data change and nothing to undo but the indexes
themselves. On a large table CREATE INDEX takes a write lock; these are
created the ordinary way because the table is small, and Postgres has
CREATE INDEX CONCURRENTLY if that ever stops being true (it cannot run
inside a transaction, so it would need its own migration with
autocommit_block).
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '1245f3a506ff'
down_revision: Union[str, Sequence[str], None] = 'e7e8bb2f6c3f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_index('ix_user_swipes_target_action', 'user_swipes', ['target_id', 'action'], unique=False)
    op.create_index('ix_user_swipes_user_target', 'user_swipes', ['user_id', 'target_id'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_user_swipes_user_target', table_name='user_swipes')
    op.drop_index('ix_user_swipes_target_action', table_name='user_swipes')
