from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class AndroidRelease(Base):
    __tablename__ = "android_releases"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    version: Mapped[str]
    build_number: Mapped[int]
    force_update: Mapped[bool] = mapped_column(default=False)
    notes: Mapped[str] = mapped_column(default="")
    apk_url: Mapped[str]
    sha256: Mapped[str]
    published_at: Mapped[str]
