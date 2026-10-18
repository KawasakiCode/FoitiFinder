"""notifications

The bell's inbox. Additive and empty on creation, so it is safe to run before
the app that reads it ships.

The two SET NULL foreign keys are the point of the table: a declined match is
deleted, and a deleted account goes with it, but the notification about either
has to survive - "this one did not go through" is information the user needs
precisely when the row it referred to is gone.

The index on user_id is what the list query runs on; every read is "mine,
newest first".
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e7e8bb2f6c3f'
down_revision: Union[str, Sequence[str], None] = '48865c6b5c91'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table('notifications',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('kind', sa.String(), nullable=False),
    sa.Column('match_id', sa.Integer(), nullable=True),
    sa.Column('other_user_id', sa.Integer(), nullable=True),
    sa.Column('created_at', sa.TIMESTAMP(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('read_at', sa.TIMESTAMP(timezone=True), nullable=True),
    sa.ForeignKeyConstraint(['match_id'], ['matches.id'], ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['other_user_id'], ['users.id'], ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_notifications_user_id'), 'notifications', ['user_id'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f('ix_notifications_user_id'), table_name='notifications')
    op.drop_table('notifications')
