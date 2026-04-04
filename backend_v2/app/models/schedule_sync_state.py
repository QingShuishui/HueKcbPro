from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class ScheduleSyncState(Base):
    __tablename__ = "schedule_sync_states"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    binding_id: Mapped[int] = mapped_column(
        ForeignKey("academic_bindings.id"),
        unique=True,
    )
    current_snapshot_id: Mapped[int | None] = mapped_column(
        ForeignKey("schedule_snapshots.id"),
    )
    sync_status: Mapped[str] = mapped_column(default="never_synced")
    last_synced_at: Mapped[str | None]
    cache_expires_at: Mapped[str | None]
    last_sync_error: Mapped[str | None]
    schedule_hash: Mapped[str | None]
    schedule_version: Mapped[int] = mapped_column(default=0)

    binding = relationship("AcademicBinding", back_populates="sync_state")
