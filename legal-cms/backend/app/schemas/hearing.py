from datetime import date, datetime, time

from pydantic import BaseModel, ConfigDict, field_validator

from app.models.hearing import HearingStatus


class HearingBase(BaseModel):
    case_id: int
    hearing_date: date
    hearing_time: time | None = None
    court_room: str | None = None
    purpose: str | None = None
    notes: str | None = None
    reminder_sent: bool = False
    status: HearingStatus = HearingStatus.SCHEDULED


class HearingCreate(HearingBase):

    @field_validator("hearing_date")
    @classmethod
    def validate_hearing_date(cls, v: date) -> date:
        if v < date.today():
            raise ValueError("hearing_date must not be in the past")
        return v


class HearingUpdate(BaseModel):
    case_id: int | None = None
    hearing_date: date | None = None
    hearing_time: time | None = None
    court_room: str | None = None
    purpose: str | None = None
    notes: str | None = None
    reminder_sent: bool | None = None
    status: HearingStatus | None = None

    @field_validator("hearing_date")
    @classmethod
    def validate_hearing_date(cls, v: date | None) -> date | None:
        if v is not None and v < date.today():
            raise ValueError("hearing_date must not be in the past")
        return v


class HearingResponse(HearingBase):
    id: int
    created_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
