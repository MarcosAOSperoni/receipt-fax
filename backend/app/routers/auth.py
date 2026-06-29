import uuid

from fastapi import APIRouter, Depends, HTTPException
from jose import JWTError
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.models.models import ServerConfig, User
from app.schemas.auth import LoginRequest, RefreshRequest, RegisterRequest, TokenResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse, status_code=201)
async def register(body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    config = await db.get(ServerConfig, "registration_enabled")
    if config and config.value == "false":
        raise HTTPException(status_code=403, detail="Registration is disabled")

    existing = await db.execute(select(User).where(User.email == body.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Email already registered")

    count = (await db.execute(select(func.count()).select_from(User))).scalar()
    is_first = count == 0

    user = User(
        id=uuid.uuid4(),
        email=body.email,
        display_name=body.display_name,
        password_hash=hash_password(body.password),
        is_admin=is_first,
    )
    db.add(user)
    await db.commit()

    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
    )


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email))
    user = result.scalar_one_or_none()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    try:
        payload = decode_token(body.refresh_token)
        if payload.get("type") != "refresh":
            raise ValueError("wrong token type")
        user_id = uuid.UUID(payload["sub"])
    except (JWTError, ValueError, KeyError):
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
    )
