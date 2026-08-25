from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class SemesterCalendar(Base):
    __tablename__ = "semester_calendars"

    term_id: Mapped[str] = mapped_column(primary_key=True)
    semester_start_date: Mapped[str]
    semester_end_date: Mapped[str]
    total_weeks: Mapped[int]
    detected_at: Mapped[str]
    last_error: Mapped[str | None] = mapped_column(nullable=True)
