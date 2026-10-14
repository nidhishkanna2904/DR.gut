import asyncio
from app.database import engine
from sqlalchemy import text

async def migrate():
    async with engine.begin() as conn:
        await conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS weight DOUBLE PRECISION;"))
        await conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS height DOUBLE PRECISION;"))
        await conn.execute(text("ALTER TABLE diet_plan_requests ADD COLUMN IF NOT EXISTS weight DOUBLE PRECISION;"))
        await conn.execute(text("ALTER TABLE diet_plan_requests ADD COLUMN IF NOT EXISTS height DOUBLE PRECISION;"))
        print("Schema migration completed successfully!")

if __name__ == "__main__":
    asyncio.run(migrate())
