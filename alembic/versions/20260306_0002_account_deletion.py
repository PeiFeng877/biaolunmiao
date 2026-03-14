"""account deletion

Revision ID: 20260306_0002
Revises: 20260217_0001
Create Date: 2026-03-06

"""

import sqlalchemy as sa

from alembic import op

revision = "20260306_0002"
down_revision = "20260217_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "deleted_at")
