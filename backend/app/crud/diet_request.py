"""CRUD helpers for DietPlanRequest."""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.diet_request import DietPlanRequest


async def create_diet_request(
    db: AsyncSession,
    *,
    user_id: int,
    location: str,
    lat: float,
    lng: float,
    disease: str,
    allergies: str,
    dislikes: str,
    budget: str,
    plan_type: str,
    result_json: dict | None = None,
    status: str = "success",
    error_msg: str | None = None,
) -> DietPlanRequest:
    """Persist a completed (or failed) diet plan request."""
    req = DietPlanRequest(
        user_id=user_id,
        location=location,
        lat=lat,
        lng=lng,
        disease=disease,
        allergies=allergies,
        dislikes=dislikes,
        budget=budget,
        plan_type=plan_type,
        result_json=result_json,
        status=status,
        error_msg=error_msg,
    )
    db.add(req)
    await db.commit()
    await db.refresh(req)
    return req


async def get_user_diet_history(
    db: AsyncSession, user_id: int, limit: int = 20
) -> list[DietPlanRequest]:
    """Return the most recent `limit` diet requests for this user."""
    result = await db.execute(
        select(DietPlanRequest)
        .where(DietPlanRequest.user_id == user_id)
        .order_by(DietPlanRequest.created_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())
