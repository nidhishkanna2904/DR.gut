"""Alembic environment script — configured for async SQLAlchemy + asyncpg.

Key changes from the default:
  - Reads DATABASE_URL from our app.config.settings (which reads .env).
  - Uses run_async_migrations() so asyncpg works correctly.
  - Imports all ORM models so autogenerate can detect table changes.
"""
import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

# ── Import app config and ALL models (required for autogenerate) ───────────────
from app.config import settings
from app.database import Base  # noqa: F401 — Base must be imported

# Import every model module so their tables are registered on Base.metadata
from app.models import user, diet_request, calorie_log  # noqa: F401

# ── Alembic config ─────────────────────────────────────────────────────────────
config = context.config

# Inject our DATABASE_URL so alembic.ini doesn't hold secrets.
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

# Set up Python logging from alembic.ini if present.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# This is the MetaData object all migrations will target.
target_metadata = Base.metadata


# ── Offline mode (generate SQL without a live DB connection) ───────────────────
def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


# ── Online mode (run against the real DB) ─────────────────────────────────────
def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
