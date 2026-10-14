"""CRUD helpers for the User model."""
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


async def get_user_by_phone(db: AsyncSession, phone: str) -> User | None:
    """Return the user with this phone number, or None."""
    clean_phone = phone.strip()
    result = await db.execute(select(User).where(User.phone == clean_phone))
    return result.scalar_one_or_none()


async def get_user_by_email(db: AsyncSession, email: str) -> User | None:
    """Return the user with this email address, or None."""
    clean_email = email.strip().lower()
    result = await db.execute(select(User).where(User.email == clean_email))
    return result.scalar_one_or_none()


async def get_user_by_phone_or_email(db: AsyncSession, identifier: str) -> User | None:
    """Return a user matching either phone or email."""
    ident = identifier.strip()
    result = await db.execute(
        select(User).where(or_(User.phone == ident, User.email == ident.lower()))
    )
    return result.scalar_one_or_none()


async def create_user(
    db: AsyncSession, name: str, phone: str, email: str | None = None
) -> User:
    """Create a brand new user row in the database."""
    user = User(
        name=name.strip(),
        phone=phone.strip(),
        email=email.strip().lower() if email else None,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


async def get_or_create_user(
    db: AsyncSession, name: str, phone: str, email: str | None = None
) -> User:
    """Return an existing user by phone, or create a new one.

    If the user already exists their name or email is updated in case it changed.
    """
    clean_phone = phone.strip()
    user = await get_user_by_phone(db, clean_phone)
    if user:
        updated = False
        if user.name != name.strip():
            user.name = name.strip()
            updated = True
        if email and user.email != email.strip().lower():
            user.email = email.strip().lower()
            updated = True
        if updated:
            await db.commit()
            await db.refresh(user)
        return user

    return await create_user(db, name=name, phone=clean_phone, email=email)
