import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, field_validator

from app.models.models import MessageStatus


class RichSpan(BaseModel):
    text: str
    bold: bool


class RichLine(BaseModel):
    size: Literal["normal", "large", "header"]
    align: Literal["left", "center"]
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
    font: str = "monospace"

    @field_validator("font", mode="before")
    @classmethod
    def default_font(cls, v: str | None) -> str:
        return v or "monospace"

    model_config = {"from_attributes": True}


class FailRequest(BaseModel):
    reason: str = "Unknown error"
