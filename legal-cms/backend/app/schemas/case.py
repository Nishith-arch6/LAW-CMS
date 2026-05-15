from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.case import CaseStatus, CaseType


class CaseBase(BaseModel):
    case_number: str
    title: str
    description: str | None = None
    case_type: CaseType = CaseType.CIVIL
    status: CaseStatus = CaseStatus.ACTIVE
    court_name: str | None = None
    court_building: str | None = None
    court_floor: str | None = None
    judge_name: str | None = None
    client_id: int
    opposing_party: str | None = None
    defending_party: str | None = None
    filing_date: datetime | None = None


class CaseCreate(CaseBase):
    pass


class CaseUpdate(BaseModel):
    case_number: str | None = None
    title: str | None = None
    description: str | None = None
    case_type: CaseType | None = None
    status: CaseStatus | None = None
    court_name: str | None = None
    court_building: str | None = None
    court_floor: str | None = None
    judge_name: str | None = None
    client_id: int | None = None
    opposing_party: str | None = None
    defending_party: str | None = None
    filing_date: datetime | None = None


class CaseResponse(CaseBase):
    id: int
    advocate_id: int
    next_hearing_date: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
