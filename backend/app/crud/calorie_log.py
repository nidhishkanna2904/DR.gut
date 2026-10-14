"""CRUD helpers for CalorieLog."""
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.calorie_log import CalorieLog


async def create_calorie_log(
    db: AsyncSession,
    *,
    user_id: int | None = None,
    total_calories: int,
    protein_g: float,
    carbs_g: float,
    fat_g: float,
    fiber_g: float = 0.0,
    confidence: str = "medium",
    result_json: dict | None = None,
) -> CalorieLog:
    """Persist a calorie estimation result."""
    log = CalorieLog(
        user_id=user_id,
        total_calories=total_calories,
        protein_g=protein_g,
        carbs_g=carbs_g,
        fat_g=fat_g,
        fiber_g=fiber_g,
        confidence=confidence,
        result_json=result_json,
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return log
