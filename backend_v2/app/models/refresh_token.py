from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    token_id: Mapped[str] = mapped_column(unique=True)
    device_name: Mapped[str]
    expires_at: Mapped[str]
    revoked_at: Mapped[str | None]
