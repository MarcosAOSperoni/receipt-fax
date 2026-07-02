"""add_rich_body_to_messages

Revision ID: a1b2c3d4e5f6
Revises: 65f8292283a8
Create Date: 2026-07-02 12:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = '65f8292283a8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('messages', sa.Column('rich_body', JSONB(), nullable=True))


def downgrade() -> None:
    op.drop_column('messages', 'rich_body')
