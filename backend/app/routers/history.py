"""History endpoints — retrieve past diet plans for a user by phone number."""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import APIRouter, Depends, HTTPException

from app.deps import get_db
from app.models.user import User
from app.crud.diet_request import get_user_diet_history

router = APIRouter(prefix="/history", tags=["history"])


@router.get("/{phone}", summary="Get past diet plans for a user")
async def get_history(phone: str, db: AsyncSession = Depends(get_db)):
    """Return the 20 most recent diet plan requests for this phone number.

    Returns 404 if no user with this phone is found.
    """
    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail=f"No user found with phone {phone!r}.")

    records = await get_user_diet_history(db, user.id)

    return {
        "user": {
            "id": user.id,
            "name": user.name,
            "phone": user.phone,
            "member_since": user.created_at.isoformat(),
        },
        "total_plans": len(records),
        "plans": [
            {
                "id": r.id,
                "location": r.location,
                "plan_type": r.plan_type,
                "budget": r.budget,
                "status": r.status,
                "created_at": r.created_at.isoformat(),
                "result": r.result_json,
            }
            for r in records
        ],
    }
