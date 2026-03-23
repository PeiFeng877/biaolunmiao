"""add team member display name

Revision ID: 20260323_0006
Revises: 20260322_0005
Create Date: 2026-03-23

"""

import sqlalchemy as sa

from alembic import op

revision = "20260323_0006"
down_revision = "20260322_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("team_members", sa.Column("display_name", sa.String(length=50), nullable=True))


def downgrade() -> None:
    op.drop_column("team_members", "display_name")
