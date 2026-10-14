"""Application settings — loaded from the .env file via pydantic-settings.

All code that needs a config value imports `settings` from here, e.g.:
    from app.config import settings
    print(settings.DATABASE_URL)
"""
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

_ENV_FILE = Path(__file__).resolve().parent.parent / ".env"


class Settings(BaseSettings):
    # ── Database ──────────────────────────────────────────────────────────────
    DATABASE_URL: str  # e.g. postgresql+asyncpg://user:pass@host:5432/db

    # ── Anthropic / Claude ────────────────────────────────────────────────────
    ANTHROPIC_API_KEY: str
    DR_GUT_MODEL: str = "claude-sonnet-4-5"

    model_config = SettingsConfigDict(
        env_file=(str(_ENV_FILE), ".env"),
        env_file_encoding="utf-8",
        case_sensitive=True,
    )


# Single shared instance — import this everywhere.
settings = Settings()
