from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class RequestLog(Base):
    __tablename__ = "request_logs"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    academic_username: Mapped[str | None]
    action: Mapped[str]
    status: Mapped[str]
    duration_ms: Mapped[int] = mapped_column(default=0)
    error_message: Mapped[str | None]
    created_at: Mapped[str]
