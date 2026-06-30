import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, Header, HTTPException
from fastapi.responses import FileResponse
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.security import decode_token, hash_api_key
from app.models.models import Device, User

router = APIRouter(tags=["media"])


@router.get("/media/{path:path}")
async def serve_media(
    path: str,
    authorization: str | None = Header(None),
    x_device_key: str | None = Header(None),
    db: AsyncSession = Depends(get_db),
):
    authenticated = False

    if authorization and authorization.startswith("Bearer "):
        try:
            payload = decode_token(authorization[7:])
            if payload.get("type") == "access":
                user = await db.get(User, uuid.UUID(payload["sub"]))
                authenticated = user is not None
        except (JWTError, ValueError):
            pass

    if not authenticated and x_device_key:
        result = await db.execute(
            select(Device).where(Device.api_key_hash == hash_api_key(x_device_key))
        )
        authenticated = result.scalar_one_or_none() is not None

    if not authenticated:
        raise HTTPException(status_code=401, detail="Authentication required")

    media_root = Path(settings.media_dir).resolve()
    file_path = (media_root / path).resolve()

    try:
        file_path.relative_to(media_root)
    except ValueError:
        raise HTTPException(status_code=403, detail="Invalid path")

    if not file_path.is_file():
        raise HTTPException(status_code=404, detail="File not found")

    return FileResponse(file_path)
