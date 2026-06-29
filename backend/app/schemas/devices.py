import uuid
from datetime import datetime

from pydantic import BaseModel


class DeviceCreate(BaseModel):
    name: str


class DeviceResponse(BaseModel):
    id: uuid.UUID
    name: str
    last_seen_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}


class DeviceCreateResponse(DeviceResponse):
    api_key: str
