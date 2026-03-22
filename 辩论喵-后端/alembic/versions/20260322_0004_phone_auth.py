"""phone auth identities

Revision ID: 20260322_0004
Revises: 20260319_0003
Create Date: 2026-03-22

"""

from datetime import datetime
from uuid import uuid4

import sqlalchemy as sa

from alembic import op

revision = "20260322_0004"
down_revision = "20260319_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_auth_identities",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("provider", sa.String(length=20), nullable=False),
        sa.Column("provider_subject", sa.String(length=255), nullable=False),
        sa.Column("provider_display", sa.String(length=255), nullable=True),
        sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("provider", "provider_subject", name="uq_user_auth_identity_provider_subject"),
    )

    op.create_table(
        "sms_verification_codes",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("phone_e164", sa.String(length=20), nullable=False),
        sa.Column("request_id", sa.String(length=128), nullable=False),
        sa.Column("provider", sa.String(length=20), nullable=False),
        sa.Column("biz_type", sa.String(length=32), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_attempt_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("attempt_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("request_id"),
    )
    op.create_index("ix_sms_verification_codes_phone_e164", "sms_verification_codes", ["phone_e164"])

    connection = op.get_bind()
    rows = connection.execute(
        sa.text(
            """
            SELECT id, apple_sub, created_at, updated_at
            FROM users
            WHERE apple_sub IS NOT NULL AND apple_sub != ''
            """
        )
    ).mappings()
    now = datetime.utcnow()
    payload = [
        {
            "id": str(uuid4()),
            "user_id": row["id"],
            "provider": "apple",
            "provider_subject": row["apple_sub"],
            "provider_display": row["apple_sub"],
            "verified_at": row["created_at"] or now,
            "created_at": row["created_at"] or now,
            "updated_at": row["updated_at"] or now,
        }
        for row in rows
    ]
    if payload:
        op.bulk_insert(
            sa.table(
                "user_auth_identities",
                sa.column("id", sa.String),
                sa.column("user_id", sa.String),
                sa.column("provider", sa.String),
                sa.column("provider_subject", sa.String),
                sa.column("provider_display", sa.String),
                sa.column("verified_at", sa.DateTime(timezone=True)),
                sa.column("created_at", sa.DateTime(timezone=True)),
                sa.column("updated_at", sa.DateTime(timezone=True)),
            ),
            payload,
        )


def downgrade() -> None:
    op.drop_index("ix_sms_verification_codes_phone_e164", table_name="sms_verification_codes")
    op.drop_table("sms_verification_codes")
    op.drop_table("user_auth_identities")
