"""Dr. Gut backend entrypoint.

Exports the FastAPI `app` from `app.main` so both:
    uvicorn main:app --reload
and
    uvicorn app.main:app --reload
work seamlessly.
"""
from app.main import app

__all__ = ["app"]
