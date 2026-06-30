import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.dependencies import require_admin
from app.models.models import ServerConfig, User
from app.schemas.admin import ConfigResponse, ConfigUpdate, UserAdminResponse

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/config", response_model=list[ConfigResponse])
async def get_config(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    result = await db.execute(select(ServerConfig))
    return result.scalars().all()


@router.patch("/config", response_model=ConfigResponse)
async def update_config(
    body: ConfigUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    config = await db.get(ServerConfig, body.key)
    if config:
        config.value = body.value
    else:
        config = ServerConfig(key=body.key, value=body.value)
        db.add(config)
    await db.commit()
    await db.refresh(config)
    return config


@router.get("/users", response_model=list[UserAdminResponse])
async def list_users(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    result = await db.execute(select(User).order_by(User.created_at))
    return result.scalars().all()


@router.delete("/users/{user_id}", status_code=204)
async def delete_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    if user_id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot delete your own account")
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    await db.delete(user)
    await db.commit()
