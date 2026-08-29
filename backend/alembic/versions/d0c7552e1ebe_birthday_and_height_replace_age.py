"""birthday and height replace age

Revision ID: d0c7552e1ebe
Revises: 6a3c39381ff2
Create Date: 2026-08-29 14:01:32.271808

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd0c7552e1ebe'
down_revision: Union[str, Sequence[str], None] = '6a3c39381ff2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    #NOT A RENAME, and it cannot be one. `age` is an integer and `birthday` is
    #a date: you cannot recover a date of birth from "26". So this is a genuine
    #drop and add, and EVERY EXISTING AGE IS LOST - affected users have a null
    #birthday until they set one.
    #
    #Acceptable only because there are no real users yet. With live data the
    #move would be: add birthday, have the app collect it, backfill, and drop
    #age in a later migration once nothing reads it.
    op.add_column('users', sa.Column('birthday', sa.Date(), nullable=True))
    op.add_column('users', sa.Column('height_cm', sa.Integer(), nullable=True))
    op.drop_column('users', 'age')


def downgrade() -> None:
    """Downgrade schema."""
    #restores the column, not the data - the ages are gone either way
    op.add_column('users', sa.Column('age', sa.INTEGER(), autoincrement=False, nullable=True))
    op.drop_column('users', 'height_cm')
    op.drop_column('users', 'birthday')
