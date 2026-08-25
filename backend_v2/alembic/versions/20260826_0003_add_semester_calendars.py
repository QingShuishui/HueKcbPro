from alembic import op
import sqlalchemy as sa


revision = "20260826_0003"
down_revision = "20260516_0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "semester_calendars",
        sa.Column("term_id", sa.String(), primary_key=True),
        sa.Column("semester_start_date", sa.String(), nullable=False),
        sa.Column("semester_end_date", sa.String(), nullable=False),
        sa.Column("total_weeks", sa.Integer(), nullable=False),
        sa.Column("detected_at", sa.String(), nullable=False),
        sa.Column("last_error", sa.String(), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("semester_calendars")
