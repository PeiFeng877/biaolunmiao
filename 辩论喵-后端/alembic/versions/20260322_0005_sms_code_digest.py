"""store phone auth code digest locally

Revision ID: 20260322_0005
Revises: 20260322_0004
Create Date: 2026-03-22

"""

import sqlalchemy as sa

from alembic import op

revision = "20260322_0005"
down_revision = "20260322_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("sms_verification_codes", sa.Column("code_digest", sa.String(length=64), nullable=True))


def downgrade() -> None:
    op.drop_column("sms_verification_codes", "code_digest")
