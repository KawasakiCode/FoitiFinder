"""add photo story column

Revision ID: 4c90a2ec3657
Revises: 
Create Date: 2026-08-25 17:26:26.179750

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '4c90a2ec3657'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # TRIMMED BY HAND. Autogenerate also proposed dropping the `messages`
    # table, matches.user_a_saw / user_b_saw and settings.is_message_
    # notifications_on - real drift left over from the messaging feature that
    # was removed from models.py but never removed from the database. Those are
    # irreversible data loss and do not belong in a migration named "add photo
    # story column"; they get their own deliberate revision once the data is
    # confirmed dead.

    # the story attached to a photo
    op.add_column('photos', sa.Column('story', sa.String(), nullable=True))

    # models.py declares ondelete=CASCADE on both user_swipes FKs but the live
    # constraints were created without it, so deleting a user errored on the
    # swipe rows referencing them. Constraints are named explicitly (rather
    # than the None autogenerate emitted) so downgrade can find them again.
    op.drop_constraint(op.f('user_swipes_user_id_fkey'), 'user_swipes', type_='foreignkey')
    op.drop_constraint(op.f('user_swipes_target_id_fkey'), 'user_swipes', type_='foreignkey')
    op.create_foreign_key(
        'user_swipes_target_id_fkey', 'user_swipes', 'users',
        ['target_id'], ['id'], ondelete='CASCADE',
    )
    op.create_foreign_key(
        'user_swipes_user_id_fkey', 'user_swipes', 'users',
        ['user_id'], ['id'], ondelete='CASCADE',
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint('user_swipes_user_id_fkey', 'user_swipes', type_='foreignkey')
    op.drop_constraint('user_swipes_target_id_fkey', 'user_swipes', type_='foreignkey')
    op.create_foreign_key(
        'user_swipes_target_id_fkey', 'user_swipes', 'users', ['target_id'], ['id'],
    )
    op.create_foreign_key(
        'user_swipes_user_id_fkey', 'user_swipes', 'users', ['user_id'], ['id'],
    )
    op.drop_column('photos', 'story')
