"""the notification toggle is about matches, not likes

settings.is_like_notifications_on -> is_match_notifications_on.

WHAT THE SWITCH NOW MEANS. There used to be a 'like' push, and this column
turned it off - except it gated the 'match' push as well, so anybody who
silenced the useless pings also silenced "somebody matched with you and is
waiting on your answer". The like push is gone (there is no likes page left
for it to open), so the switch governs the match pushes and is named for them.

A RENAME IS A CONTRACTING CHANGE, which is the one shape that is not safe to
deploy in a single step: a build still sending is_like_notifications_on gets a
422 the moment this lands. It is done in one step anyway because there are no
builds in the wild yet - and the minimum-build gate added alongside this is
what makes the NEXT one safe to do properly, in two deploys.

THE VALUE CARRIES OVER AS-IS. Somebody who had asked for silence still gets
silence, and somebody who had not still gets told - which is the honest
reading of the only setting either of them ever saw.
"""

from typing import Sequence, Union

from alembic import op


revision: str = '45da3499fdc1'
down_revision: Union[str, Sequence[str], None] = '81c448444634'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    #ALTER COLUMN ... RENAME, not add-copy-drop: it keeps the values, the NOT
    #NULL and the default in one statement, and needs no backfill.
    op.alter_column('settings', 'is_like_notifications_on',
                    new_column_name='is_match_notifications_on')


def downgrade() -> None:
    op.alter_column('settings', 'is_match_notifications_on',
                    new_column_name='is_like_notifications_on')
