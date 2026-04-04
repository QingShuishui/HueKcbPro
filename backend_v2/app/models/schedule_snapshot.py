from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class ScheduleSnapshot(Base):
    __tablename__ = "schedule_snapshots"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    binding_id: Mapped[int] = mapped_column(ForeignKey("academic_bindings.id"))
    version: Mapped[int] = mapped_column(default=1)
    schedule_hash: Mapped[str]
    semester_label: Mapped[str]
    payload_json: Mapped[str]
    generated_at: Mapped[str]
