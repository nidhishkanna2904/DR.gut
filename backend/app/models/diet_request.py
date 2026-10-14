"""DietPlanRequest ORM model.

Every call to POST /diet-plan creates one row here.
The full JSON result from Claude is stored in result_json.
"""
from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class DietPlanRequest(Base):
    __tablename__ = "diet_plan_requests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # ── Input fields (from the Flutter form) ─────────────────────────────────
    location: Mapped[str] = mapped_column(String(255), nullable=False)
    lat: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    lng: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    disease: Mapped[str] = mapped_column(Text, default="", nullable=False)
    allergies: Mapped[str] = mapped_column(Text, default="", nullable=False)
    dislikes: Mapped[str] = mapped_column(Text, default="", nullable=False)
    budget: Mapped[str] = mapped_column(String(50), nullable=False)
    plan_type: Mapped[str] = mapped_column(String(10), default="day", nullable=False)  # 'day' | 'week'

    # ── Output / result ───────────────────────────────────────────────────────
    # Stored as JSONB for efficient querying inside Postgres
    result_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="success", nullable=False)  # success | error
    error_msg: Mapped[str | None] = mapped_column(Text, nullable=True)

    # ── Timing ────────────────────────────────────────────────────────────────
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)

    # ── Relationship ──────────────────────────────────────────────────────────
    user: Mapped["User"] = relationship("User", back_populates="diet_requests")  # noqa: F821

    def __repr__(self) -> str:
        return f"<DietPlanRequest id={self.id} user_id={self.user_id} status={self.status!r}>"
