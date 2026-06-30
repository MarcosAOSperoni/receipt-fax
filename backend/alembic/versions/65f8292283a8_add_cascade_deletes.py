"""add_cascade_deletes

Revision ID: 65f8292283a8
Revises: b08a27e5df1e
Create Date: 2026-06-29 16:00:00.000000

"""
from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = '65f8292283a8'
down_revision: Union[str, None] = 'b08a27e5df1e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # devices.owner_id
    op.execute("ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_owner_id_fkey")
    op.execute(
        "ALTER TABLE devices ADD CONSTRAINT devices_owner_id_fkey "
        "FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE"
    )
    # messages.sender_id
    op.execute("ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_sender_id_fkey")
    op.execute(
        "ALTER TABLE messages ADD CONSTRAINT messages_sender_id_fkey "
        "FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE"
    )
    # messages.device_id
    op.execute("ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_device_id_fkey")
    op.execute(
        "ALTER TABLE messages ADD CONSTRAINT messages_device_id_fkey "
        "FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_device_id_fkey")
    op.execute(
        "ALTER TABLE messages ADD CONSTRAINT messages_device_id_fkey "
        "FOREIGN KEY (device_id) REFERENCES devices(id)"
    )
    op.execute("ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_sender_id_fkey")
    op.execute(
        "ALTER TABLE messages ADD CONSTRAINT messages_sender_id_fkey "
        "FOREIGN KEY (sender_id) REFERENCES users(id)"
    )
    op.execute("ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_owner_id_fkey")
    op.execute(
        "ALTER TABLE devices ADD CONSTRAINT devices_owner_id_fkey "
        "FOREIGN KEY (owner_id) REFERENCES users(id)"
    )
