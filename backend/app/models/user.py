"""User ORM model.

Represents every unique person who submits the Dr. Gut form.
Identity is keyed on phone number — one user row per phone.
"""
from datetime import datetime

from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    phone: Mapped[str] = mapped_column(String(15), nullable=False, unique=True, index=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    # Relationships (back-populated by child models)
    diet_requests: Mapped[list["DietPlanRequest"]] = relationship(  # noqa: F821
        "DietPlanRequest", back_populates="user", lazy="select"
    )
    calorie_logs: Mapped[list["CalorieLog"]] = relationship(  # noqa: F821
        "CalorieLog", back_populates="user", lazy="select"
    )

    def __repr__(self) -> str:
        return f"<User id={self.id} phone={self.phone} name={self.name!r}>"
