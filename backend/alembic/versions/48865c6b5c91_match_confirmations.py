"""match confirmations

Revision ID: 48865c6b5c91
Revises: b7c2f9a41e30
Create Date: 2026-10-17

Two nullable timestamps on `matches`: when each side confirmed they want to
go ahead, which is what releases the Instagram handles.

NULLABLE AND NULL FOR EVERY EXISTING ROW, so this is safe to run before the
app that uses it ships: a match created by an older client simply has nobody
confirmed, and the new match page asks. Nothing reads these columns until
POST /matches/{id}/confirm exists.

A decline deletes the match instead of recording a third state - see the note
on the model.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '48865c6b5c91'
down_revision: Union[str, Sequence[str], None] = 'b7c2f9a41e30'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('matches', sa.Column('a_confirmed_at', sa.TIMESTAMP(timezone=True), nullable=True))
    op.add_column('matches', sa.Column('b_confirmed_at', sa.TIMESTAMP(timezone=True), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('matches', 'b_confirmed_at')
    op.drop_column('matches', 'a_confirmed_at')
