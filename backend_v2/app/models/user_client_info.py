from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class UserClientInfo(Base):
    __tablename__ = "user_client_infos"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True)
    device_name: Mapped[str | None]
    platform: Mapped[str | None]
    app_version: Mapped[str | None]
    app_build: Mapped[str | None]
    last_seen_at: Mapped[str]
