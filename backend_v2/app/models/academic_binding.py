from sqlalchemy import ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class AcademicBinding(Base):
    __tablename__ = "academic_bindings"
    __table_args__ = (UniqueConstraint("school_code", "academic_username"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    school_code: Mapped[str] = mapped_column(default="hue")
    academic_username: Mapped[str]
    connector_key: Mapped[str] = mapped_column(default="hue")
    credential_status: Mapped[str] = mapped_column(default="valid")

    user = relationship("User", back_populates="academic_bindings")
    credential = relationship(
        "EncryptedCredential",
        back_populates="binding",
        uselist=False,
    )
    sync_state = relationship(
        "ScheduleSyncState",
        back_populates="binding",
        uselist=False,
    )
