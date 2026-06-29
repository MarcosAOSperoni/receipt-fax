import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import generate_api_key
from app.dependencies import get_current_user
from app.models.models import Device, User
from app.schemas.devices import DeviceCreate, DeviceCreateResponse, DeviceResponse

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("", response_model=DeviceCreateResponse, status_code=201)
async def create_device(
    body: DeviceCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    raw_key, key_hash = generate_api_key()
    device = Device(
        id=uuid.uuid4(),
        owner_id=user.id,
        name=body.name,
        api_key_hash=key_hash,
    )
    db.add(device)
    await db.commit()
    await db.refresh(device)
    return DeviceCreateResponse(
        id=device.id,
        name=device.name,
        last_seen_at=device.last_seen_at,
        created_at=device.created_at,
        api_key=raw_key,
    )


@router.get("", response_model=list[DeviceResponse])
async def list_devices(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Device).where(Device.owner_id == user.id).order_by(Device.created_at)
    )
    return result.scalars().all()


@router.delete("/{device_id}", status_code=204)
async def delete_device(
    device_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    device = await db.get(Device, device_id)
    if not device or device.owner_id != user.id:
        raise HTTPException(status_code=404, detail="Device not found")
    await db.delete(device)
    await db.commit()
