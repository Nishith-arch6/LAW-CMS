"""initial_schema

Revision ID: 0001
Revises:
Create Date: 2026-05-12 00:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("full_name", sa.String(255), nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("hashed_password", sa.String(255), nullable=False),
        sa.Column("bar_number", sa.String(100), nullable=False),
        sa.Column("phone", sa.String(50), nullable=True),
        sa.Column("profile_photo_url", sa.String(500), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email"),
        sa.UniqueConstraint("bar_number"),
    )
    op.create_index(op.f("ix_users_id"), "users", ["id"])
    op.create_index(op.f("ix_users_email"), "users", ["email"])
    op.create_index(op.f("ix_users_bar_number"), "users", ["bar_number"])

    op.create_table(
        "clients",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("email", sa.String(255), nullable=True),
        sa.Column("phone", sa.String(50), nullable=True),
        sa.Column("address", sa.Text(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("advocate_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_clients_id"), "clients", ["id"])

    op.create_table(
        "blacklisted_tokens",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("token_hash", sa.String(255), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("token_hash"),
    )
    op.create_index(op.f("ix_blacklisted_tokens_id"), "blacklisted_tokens", ["id"])
    op.create_index(
        op.f("ix_blacklisted_tokens_token_hash"), "blacklisted_tokens", ["token_hash"]
    )

    op.create_table(
        "cases",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("case_number", sa.String(100), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column(
            "case_type",
            sa.Enum("CIVIL", "CRIMINAL", "FAMILY", "CORPORATE", "OTHER", name="casetype"),
            server_default="CIVIL",
            nullable=False,
        ),
        sa.Column(
            "status",
            sa.Enum("ACTIVE", "CLOSED", "PENDING", "ADJOURNED", name="casestatus"),
            server_default="ACTIVE",
            nullable=False,
        ),
        sa.Column("court_name", sa.String(255), nullable=True),
        sa.Column("court_building", sa.String(255), nullable=True),
        sa.Column("court_floor", sa.String(100), nullable=True),
        sa.Column("judge_name", sa.String(255), nullable=True),
        sa.Column("client_id", sa.Integer(), sa.ForeignKey("clients.id"), nullable=False),
        sa.Column("advocate_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("opposing_party", sa.String(255), nullable=True),
        sa.Column("defending_party", sa.String(255), nullable=True),
        sa.Column("filing_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_deleted", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("case_number"),
    )
    op.create_index(op.f("ix_cases_id"), "cases", ["id"])
    op.create_index(op.f("ix_cases_case_number"), "cases", ["case_number"])

    op.create_table(
        "hearings",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("case_id", sa.Integer(), sa.ForeignKey("cases.id"), nullable=False),
        sa.Column("hearing_date", sa.Date(), nullable=False),
        sa.Column("hearing_time", sa.Time(), nullable=True),
        sa.Column("court_room", sa.String(100), nullable=True),
        sa.Column("purpose", sa.Text(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("reminder_sent", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column(
            "status",
            sa.Enum("SCHEDULED", "COMPLETED", "ADJOURNED", "CANCELLED", name="hearingstatus"),
            server_default="SCHEDULED",
            nullable=False,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_hearings_id"), "hearings", ["id"])

    op.create_table(
        "documents",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("case_id", sa.Integer(), sa.ForeignKey("cases.id"), nullable=False),
        sa.Column("file_name", sa.String(255), nullable=False),
        sa.Column("file_path", sa.String(500), nullable=False),
        sa.Column("file_type", sa.String(100), nullable=True),
        sa.Column("file_size", sa.BigInteger(), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("ocr_text", sa.Text(), nullable=True),
        sa.Column("uploaded_by", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "uploaded_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_documents_id"), "documents", ["id"])

    op.create_table(
        "case_notes",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("case_id", sa.Integer(), sa.ForeignKey("cases.id"), nullable=False),
        sa.Column("author_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_case_notes_id"), "case_notes", ["id"])

    op.create_table(
        "notifications",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("hearing_id", sa.Integer(), sa.ForeignKey("hearings.id"), nullable=True),
        sa.Column(
            "type",
            sa.Enum("hearing_reminder", "case_update", "welcome", name="notificationtype"),
            nullable=False,
        ),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column(
            "sent_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column("read", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_notifications_id"), "notifications", ["id"])


def downgrade() -> None:
    op.drop_table("notifications")
    op.drop_table("case_notes")
    op.drop_table("documents")
    op.drop_table("hearings")
    op.drop_table("cases")
    op.drop_table("blacklisted_tokens")
    op.drop_table("clients")
    op.drop_table("users")

    op.execute("DROP TYPE IF EXISTS casetype")
    op.execute("DROP TYPE IF EXISTS casestatus")
    op.execute("DROP TYPE IF EXISTS hearingstatus")
    op.execute("DROP TYPE IF EXISTS notificationtype")
