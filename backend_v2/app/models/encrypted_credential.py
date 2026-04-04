from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class EncryptedCredential(Base):
    __tablename__ = "encrypted_credentials"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    binding_id: Mapped[int] = mapped_column(
        ForeignKey("academic_bindings.id"),
        unique=True,
    )
    encrypted_password: Mapped[str]

    binding = relationship("AcademicBinding", back_populates="credential")
