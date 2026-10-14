"""CalorieLog ORM model.

Every call to POST /estimate-calories creates one row here.
"""
from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class CalorieLog(Base):
    __tablename__ = "calorie_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    # user_id is nullable — calorie estimation does not require a full profile
    user_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )

    # ── Nutritional summary ───────────────────────────────────────────────────
    total_calories: Mapped[int] = mapped_column(Integer, nullable=False)
    protein_g: Mapped[float] = mapped_column(Float, nullable=False)
    carbs_g: Mapped[float] = mapped_column(Float, nullable=False)
    fat_g: Mapped[float] = mapped_column(Float, nullable=False)
    fiber_g: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    confidence: Mapped[str] = mapped_column(String(20), default="medium", nullable=False)

    # ── Full model response ───────────────────────────────────────────────────
    result_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    # ── Timing ────────────────────────────────────────────────────────────────
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)

    # ── Relationship ──────────────────────────────────────────────────────────
    user: Mapped["User | None"] = relationship("User", back_populates="calorie_logs")  # noqa: F821

    def __repr__(self) -> str:
        return f"<CalorieLog id={self.id} kcal={self.total_calories} confidence={self.confidence!r}>"
