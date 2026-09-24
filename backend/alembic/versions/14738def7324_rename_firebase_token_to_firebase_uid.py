"""rename firebase_token to firebase_uid

Revision ID: 14738def7324
Revises: 85f0497acd8a
Create Date: 2026-09-24 20:30:57.925204

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '14738def7324'
down_revision: Union[str, Sequence[str], None] = '85f0497acd8a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


#HAND-WRITTEN, NOT WHAT AUTOGENERATE PRODUCED.
#
#Autogenerate compares two schemas and cannot see intent, so it proposed
#add_column + drop_column - which would empty the new column and delete every
#uid, disconnecting every account from its Firebase identity permanently.
#A rename keeps the data.
#
#The unique constraint is renamed too, so its name keeps matching the column
#and a later autogenerate does not propose dropping and recreating it.


def upgrade() -> None:
    """Upgrade schema."""
    op.alter_column('users', 'firebase_token', new_column_name='firebase_uid')
    op.execute(
        'ALTER TABLE users RENAME CONSTRAINT '
        'users_firebase_token_key TO users_firebase_uid_key'
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        'ALTER TABLE users RENAME CONSTRAINT '
        'users_firebase_uid_key TO users_firebase_token_key'
    )
    op.alter_column('users', 'firebase_uid', new_column_name='firebase_token')
