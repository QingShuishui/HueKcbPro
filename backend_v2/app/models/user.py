from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    display_name: Mapped[str | None]
    last_login_at: Mapped[str | None]

    academic_bindings = relationship("AcademicBinding", back_populates="user")
