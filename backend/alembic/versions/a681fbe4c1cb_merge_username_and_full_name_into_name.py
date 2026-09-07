"""merge username and full_name into name

Revision ID: a681fbe4c1cb
Revises: d0c7552e1ebe
Create Date: 2026-09-07 16:54:53.932742

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a681fbe4c1cb'
down_revision: Union[str, Sequence[str], None] = 'd0c7552e1ebe'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    #WRITTEN BY HAND. Autogenerate would emit drop_column('full_name') +
    #add_column('name'), which throws away every user's name. alter_column
    #renames in place and keeps the data.
    #
    #ORDER MATTERS. full_name is NOT NULL, so it must already hold a value for
    #every row - it does, it has always been required - and renaming it is a
    #catalog-only change. username is dropped separately and its data IS lost,
    #which is the intent: there is nowhere for a handle to go now.
    op.alter_column('users', 'full_name', new_column_name='name')

    #the index followed full_name's name automatically; username's goes with
    #the column
    op.drop_column('users', 'username')

    #`name` is what the app displays everywhere now, and the feed and likes
    #queries select it, so it keeps the index username used to carry
    op.create_index(op.f('ix_users_name'), 'users', ['name'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    #Restores the SHAPE, not the data: usernames are gone for good. NOT NULL
    #with a server_default so existing rows have something to put in it.
    op.drop_index(op.f('ix_users_name'), table_name='users')
    op.add_column(
        'users',
        sa.Column('username', sa.String(), nullable=False, server_default=''),
    )
    op.create_index(op.f('ix_users_username'), 'users', ['username'], unique=False)
    op.alter_column('users', 'name', new_column_name='full_name')
