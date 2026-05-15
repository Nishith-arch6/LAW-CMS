import re
from datetime import datetime

from pydantic import BaseModel, ConfigDict, field_validator


class ClientBase(BaseModel):
    name: str
    email: str | None = None
    phone: str | None = None
    address: str | None = None
    notes: str | None = None

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str | None) -> str | None:
        if v is not None and "@" not in v:
            raise ValueError("Invalid email format")
        return v

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str | None) -> str | None:
        if v is not None and not re.match(r"^\+?[1-9]\d{7,14}$", v):
            raise ValueError("Phone must be a valid number with 8-15 digits")
        return v


class ClientCreate(ClientBase):
    pass


class ClientUpdate(BaseModel):
    name: str | None = None
    email: str | None = None
    phone: str | None = None
    address: str | None = None
    notes: str | None = None

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str | None) -> str | None:
        if v is not None and "@" not in v:
            raise ValueError("Invalid email format")
        return v

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str | None) -> str | None:
        if v is not None and not re.match(r"^\+?[1-9]\d{7,14}$", v):
            raise ValueError("Phone must be a valid number with 8-15 digits")
        return v


class ClientResponse(ClientBase):
    id: int
    advocate_id: int
    created_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
