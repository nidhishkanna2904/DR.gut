"""FastAPI dependency: yields an AsyncSession for each request.

Usage in route handlers:
    from app.deps import get_db
    async def my_route(db: AsyncSession = Depends(get_db)):
        ...
"""
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession

from app.database import SessionLocal


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Provide a transactional async database session per request."""
    async with SessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
