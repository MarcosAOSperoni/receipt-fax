import uuid
from datetime import datetime

from pydantic import BaseModel

from app.models.models import MessageStatus


class RichSpan(BaseModel):
    text: str
    bold: bool


class RichLine(BaseModel):
    size: str   # "normal" | "large" | "header"
    align: str  # "left" | "center"
    spans: list[RichSpan]


class MessageResponse(BaseModel):
    id: uuid.UUID
    device_id: uuid.UUID
    body: str | None
    style: dict
    image_path: str | None
    status: MessageStatus
    failure_reason: str | None
    created_at: datetime
    printed_at: datetime | None
    rich_body: list[RichLine] | None = None

    model_config = {"from_attributes": True}


class FailRequest(BaseModel):
    reason: str = "Unknown error"
