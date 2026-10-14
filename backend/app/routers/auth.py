"""Authentication and account creation endpoints for Dr. Gut."""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.user import (
    create_user,
    get_user_by_email,
    get_user_by_phone,
    get_user_by_phone_or_email,
)
from app.deps import get_db

router = APIRouter(prefix="/auth", tags=["auth"])


class LoginRequest(BaseModel):
    identifier: str = Field(..., description="Phone number or email address to log in")


class RegisterRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100, description="Full name of user")
    phone: str = Field(..., min_length=7, max_length=20, description="Contact phone number")
    email: str | None = Field(None, max_length=255, description="Optional email address")


class UserResponse(BaseModel):
    id: int
    name: str
    phone: str
    email: str | None = None
    created_at: str


@router.post("/login", summary="Sign in with phone or email")
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    """Authenticate an existing user by phone or email.

    If no user exists in the database, returns a 404 with a clear message
    instructing the client to prompt for account creation.
    """
    clean_id = req.identifier.strip()
    if not clean_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please provide a valid phone number or email.",
        )

    user = await get_user_by_phone_or_email(db, clean_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No account found in database for '{clean_id}'. Please create an account.",
        )

    return {
        "status": "success",
        "exists": true if False else True,
        "message": f"Welcome back, {user.name}!",
        "user": {
            "id": user.id,
            "name": user.name,
            "phone": user.phone,
            "email": user.email,
            "created_at": user.created_at.isoformat(),
        },
    }


@router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
    summary="Create a new user account in database",
)
@router.post(
    "/create-account",
    status_code=status.HTTP_201_CREATED,
    summary="Create a new user account (alias)",
)
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """Register a new user in the PostgreSQL database."""
    clean_name = req.name.strip()
    clean_phone = req.phone.strip()
    clean_email = req.email.strip().lower() if req.email and req.email.strip() else None

    if not clean_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Name cannot be blank.",
        )

    if not clean_phone:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number cannot be blank.",
        )

    # Check if user with phone already exists
    existing_by_phone = await get_user_by_phone(db, clean_phone)
    if existing_by_phone:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"An account with phone number '{clean_phone}' already exists. Please sign in.",
        )

    # Check if user with email already exists
    if clean_email:
        existing_by_email = await get_user_by_email(db, clean_email)
        if existing_by_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"An account with email '{clean_email}' already exists. Please sign in.",
            )

    new_user = await create_user(
        db, name=clean_name, phone=clean_phone, email=clean_email
    )

    return {
        "status": "success",
        "message": f"Account created successfully. Welcome to Dr. Gut, {new_user.name}!",
        "user": {
            "id": new_user.id,
            "name": new_user.name,
            "phone": new_user.phone,
            "email": new_user.email,
            "created_at": new_user.created_at.isoformat(),
        },
    }


@router.get("/check/{identifier}", summary="Check if an account exists in database")
async def check_account(identifier: str, db: AsyncSession = Depends(get_db)):
    """Quick check to see if an account exists in database by phone or email."""
    clean_id = identifier.strip()
    user = await get_user_by_phone_or_email(db, clean_id)
    if not user:
        return {
            "exists": False,
            "message": f"No account found in database for '{clean_id}'.",
            "user": None,
        }

    return {
        "exists": True,
        "message": "Account found.",
        "user": {
            "id": user.id,
            "name": user.name,
            "phone": user.phone,
            "email": user.email,
        },
    }
