"""a match is removed per side, not for both

Replaces matches.hidden_at + hidden_by_user_id with one timestamp per side.

NOTHING IS MIGRATED, because nothing was ever written. The old pair was added
with the read filter but never got an endpoint to set it - the removal button
is what arrives with this revision - so both columns are NULL on every row in
every database. That is also why this is a drop rather than a backfill, and
why now was the moment to change the shape.

WHY ONE PER SIDE is in the model, at the columns. In short: removing a match
mutually would make the removal visible to the other person, and once
reporting somebody removes the match too, a match disappearing tells the
person holding your Instagram handle that you reported them. Per side, nobody
can tell. It also makes the write conflict-free - a shared column needed a
read-then-write to see whether the other side had already removed it.

THE SENTINEL THAT DOES NOT WORK, for anyone who wonders why two columns were
needed rather than a value meaning "both": hidden_by_user_id is a foreign key
to users.id, so Postgres refuses -1 outright, and dropping the constraint to
make room would trade ON DELETE SET NULL for a magic number.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '81c448444634'
down_revision: Union[str, Sequence[str], None] = '3bf7c3e8ab98'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('matches', sa.Column(
        'hidden_by_a_at', sa.TIMESTAMP(timezone=True), nullable=True))
    op.add_column('matches', sa.Column(
        'hidden_by_b_at', sa.TIMESTAMP(timezone=True), nullable=True))

    #NO EXPLICIT drop_constraint FOR THE FOREIGN KEY, and that is not an
    #oversight. Postgres drops a constraint that involves only one column
    #along with the column itself, and naming it here would break the
    #from-zero build: the baseline declares that constraint WITHOUT a name, so
    #a database built from it carries Postgres's own
    #matches_hidden_by_user_id_fkey, while the development database - built by
    #the chain the baseline replaced - has fk_matches_hidden_by_user. Dropping
    #the column needs neither name and is right in both.
    op.drop_column('matches', 'hidden_by_user_id')
    op.drop_column('matches', 'hidden_at')


def downgrade() -> None:
    op.add_column('matches', sa.Column(
        'hidden_at', sa.TIMESTAMP(timezone=True), nullable=True))
    op.add_column('matches', sa.Column(
        'hidden_by_user_id', sa.Integer(), nullable=True))
    #THE NAME POSTGRES WOULD HAVE CHOSEN ITSELF, because the baseline leaves
    #the constraint unnamed and this has to land on the shape the baseline
    #describes - not on the shape the superseded chain happened to produce.
    op.create_foreign_key('matches_hidden_by_user_id_fkey', 'matches', 'users',
                          ['hidden_by_user_id'], ['id'], ondelete='SET NULL')

    #A REMOVAL MADE UNDER THE NEW SHAPE CANNOT BE EXPRESSED IN THE OLD ONE.
    #Anybody who removed only their own copy would have the match handed back
    #to them, so the rows that say so are collapsed onto the old meaning -
    #withdrawn by one, gone for both - which is the reading that does not
    #resurrect something somebody walked away from.
    op.execute("""
        UPDATE matches
           SET hidden_at = COALESCE(hidden_by_a_at, hidden_by_b_at)
         WHERE hidden_by_a_at IS NOT NULL OR hidden_by_b_at IS NOT NULL
    """)

    op.drop_column('matches', 'hidden_by_b_at')
    op.drop_column('matches', 'hidden_by_a_at')
