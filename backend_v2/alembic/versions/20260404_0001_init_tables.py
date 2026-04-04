from alembic import op
import sqlalchemy as sa


revision = "20260404_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("display_name", sa.String(), nullable=True),
        sa.Column("last_login_at", sa.String(), nullable=True),
    )
    op.create_table(
        "academic_bindings",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("school_code", sa.String(), nullable=False),
        sa.Column("academic_username", sa.String(), nullable=False),
        sa.Column("connector_key", sa.String(), nullable=False),
        sa.Column("credential_status", sa.String(), nullable=False),
        sa.UniqueConstraint("school_code", "academic_username"),
    )
    op.create_table(
        "encrypted_credentials",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "binding_id",
            sa.Integer(),
            sa.ForeignKey("academic_bindings.id"),
            nullable=False,
            unique=True,
        ),
        sa.Column("encrypted_password", sa.String(), nullable=False),
    )
    op.create_table(
        "schedule_snapshots",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "binding_id",
            sa.Integer(),
            sa.ForeignKey("academic_bindings.id"),
            nullable=False,
        ),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("schedule_hash", sa.String(), nullable=False),
        sa.Column("semester_label", sa.String(), nullable=False),
        sa.Column("payload_json", sa.String(), nullable=False),
        sa.Column("generated_at", sa.String(), nullable=False),
    )
    op.create_table(
        "schedule_sync_states",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "binding_id",
            sa.Integer(),
            sa.ForeignKey("academic_bindings.id"),
            nullable=False,
            unique=True,
        ),
        sa.Column(
            "current_snapshot_id",
            sa.Integer(),
            sa.ForeignKey("schedule_snapshots.id"),
            nullable=True,
        ),
        sa.Column("sync_status", sa.String(), nullable=False),
        sa.Column("last_synced_at", sa.String(), nullable=True),
        sa.Column("cache_expires_at", sa.String(), nullable=True),
        sa.Column("last_sync_error", sa.String(), nullable=True),
        sa.Column("schedule_hash", sa.String(), nullable=True),
        sa.Column("schedule_version", sa.Integer(), nullable=False),
    )
    op.create_table(
        "refresh_tokens",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("token_id", sa.String(), nullable=False, unique=True),
        sa.Column("device_name", sa.String(), nullable=False),
        sa.Column("expires_at", sa.String(), nullable=False),
        sa.Column("revoked_at", sa.String(), nullable=True),
    )
    op.create_table(
        "android_releases",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("version", sa.String(), nullable=False),
        sa.Column("build_number", sa.Integer(), nullable=False),
        sa.Column("force_update", sa.Boolean(), nullable=False),
        sa.Column("notes", sa.String(), nullable=False),
        sa.Column("apk_url", sa.String(), nullable=False),
        sa.Column("sha256", sa.String(), nullable=False),
        sa.Column("published_at", sa.String(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("android_releases")
    op.drop_table("refresh_tokens")
    op.drop_table("schedule_sync_states")
    op.drop_table("schedule_snapshots")
    op.drop_table("encrypted_credentials")
    op.drop_table("academic_bindings")
    op.drop_table("users")
