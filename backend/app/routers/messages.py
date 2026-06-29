import json
import shutil
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.dependencies import get_current_user, get_device
from app.models.models import Device, Message, MessageStatus, User
from app.schemas.messages import FailRequest, MessageResponse

router = APIRouter(tags=["messages"])


@router.post("/messages", response_model=MessageResponse, status_code=201)
async def send_message(
    device_id: uuid.UUID = Form(...),
    body: str | None = Form(None),
    style: str = Form("{}"),
    image: UploadFile | None = File(None),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    device = await db.get(Device, device_id)
    if not device or device.owner_id != user.id:
        raise HTTPException(status_code=404, detail="Device not found")

    if not body and not image:
        raise HTTPException(status_code=422, detail="Message must have body or image")

    image_path = None
    if image:
        date_prefix = datetime.now(timezone.utc).strftime("%Y/%m")
        rel_dir = Path(date_prefix)
        abs_dir = Path(settings.media_dir) / rel_dir
        abs_dir.mkdir(parents=True, exist_ok=True)

        suffix = Path(image.filename or "image").suffix or ".jpg"
        filename = f"{uuid.uuid4()}{suffix}"
        abs_path = abs_dir / filename

        with abs_path.open("wb") as f:
            shutil.copyfileobj(image.file, f)

        image_path = str(rel_dir / filename)

    message = Message(
        id=uuid.uuid4(),
        sender_id=user.id,
        device_id=device_id,
        body=body,
        style=json.loads(style),
        image_path=image_path,
        status=MessageStatus.pending,
    )
    db.add(message)
    await db.commit()
    await db.refresh(message)
    return message


@router.get("/messages", response_model=list[MessageResponse])
async def list_messages(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Message)
        .where(Message.sender_id == user.id)
        .order_by(Message.created_at.desc())
    )
    return result.scalars().all()


@router.delete("/messages/{message_id}", status_code=204)
async def delete_message(
    message_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    message = await db.get(Message, message_id)
    if not message or message.sender_id != user.id:
        raise HTTPException(status_code=404, detail="Message not found")
    await db.delete(message)
    await db.commit()
