import re
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, field_validator


class UserBase(BaseModel):
    full_name: str
    email: EmailStr
    bar_number: str | None = None
    phone: str | None = None
    profile_photo_url: str | None = None
    is_active: bool = True

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str | None) -> str | None:
        if v is not None and not re.match(r"^\+?[1-9]\d{7,14}$", v):
            raise ValueError("Phone must be a valid number with 8-15 digits")
        return v

    @field_validator("bar_number")
    @classmethod
    def validate_bar_number(cls, v: str | None) -> str | None:
        if v is not None and not v.strip():
            raise ValueError("Bar number cannot be empty")
        return v.strip() if v else None


class UserCreate(UserBase):
    password: str

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


class UserUpdate(BaseModel):
    full_name: str | None = None
    email: EmailStr | None = None
    bar_number: str | None = None
    phone: str | None = None
    profile_photo_url: str | None = None
    is_active: bool | None = None
    password: str | None = None

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str | None) -> str | None:
        if v is not None and not re.match(r"^\+?[1-9]\d{7,14}$", v):
            raise ValueError("Phone must be a valid number with 8-15 digits")
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str | None) -> str | None:
        if v is not None and len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


class UserResponse(UserBase):
    id: int
    created_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
