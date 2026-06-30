import uuid
from datetime import datetime

from pydantic import BaseModel


class ConfigUpdate(BaseModel):
    key: str
    value: str


class ConfigResponse(BaseModel):
    key: str
    value: str

    model_config = {"from_attributes": True}


class UserAdminResponse(BaseModel):
    id: uuid.UUID
    email: str
    display_name: str
    is_admin: bool
    created_at: datetime

    model_config = {"from_attributes": True}
