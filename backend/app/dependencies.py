import uuid

from fastapi import Depends, Header, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import decode_token, hash_api_key
from app.models.models import Device, User

bearer = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: AsyncSession = Depends(get_db),
) -> User:
    try:
        payload = decode_token(credentials.credentials)
        if payload.get("type") != "access":
            raise ValueError("wrong token type")
        user_id = uuid.UUID(payload["sub"])
    except (JWTError, ValueError, KeyError):
        raise HTTPException(status_code=401, detail="Invalid token")

    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user


async def require_admin(user: User = Depends(get_current_user)) -> User:
    if not user.is_admin:
        raise HTTPException(status_code=403, detail="Admin required")
    return user


async def get_device(
    x_device_key: str = Header(...),
    db: AsyncSession = Depends(get_db),
) -> Device:
    key_hash = hash_api_key(x_device_key)
    result = await db.execute(select(Device).where(Device.api_key_hash == key_hash))
    device = result.scalar_one_or_none()
    if not device:
        raise HTTPException(status_code=401, detail="Invalid device key")
    return device
