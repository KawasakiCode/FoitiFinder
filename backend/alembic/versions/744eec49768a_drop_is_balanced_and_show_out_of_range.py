"""drop is_balanced and show_out_of_range

Revision ID: 744eec49768a
Revises: 5b839a377d96
Create Date: 2026-08-29 12:48:08.222552

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '744eec49768a'
down_revision: Union[str, Sequence[str], None] = '5b839a377d96'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    #The "balanced vs recently active" recommendation preference and the
    #"show people outside my age range" toggle are both gone from the app, so
    #the columns behind them go too. The feed now always applies the age range
    #the user picked - see the filter block in main.py.

    #REMOVED BY HAND (again): autogenerate also proposed dropping `messages`,
    #matches.user_a_saw / user_b_saw and settings.is_message_notifications_on.
    #Those exist on the LOCAL dev database only - Neon was built later from a
    #models.py that never had them - so a migration dropping them would work
    #locally and crash the Render deploy. Clean the local database by hand
    #instead, or they will reappear in every autogenerate from here on.

    op.drop_column('users', 'show_out_of_range')
    op.drop_column('users', 'is_balanced')


def downgrade() -> None:
    """Downgrade schema."""
    #columns only - the data in them is gone either way
    op.add_column('users', sa.Column('is_balanced', sa.BOOLEAN(), autoincrement=False, nullable=True))
    op.add_column('users', sa.Column('show_out_of_range', sa.BOOLEAN(), autoincrement=False, nullable=True))
