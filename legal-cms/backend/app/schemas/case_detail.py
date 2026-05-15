from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.case import CaseStatus, CaseType
from app.schemas.case_note import CaseNoteResponse
from app.schemas.document import DocumentResponse
from app.schemas.hearing import HearingResponse


class CaseDetailResponse(BaseModel):
    id: int
    case_number: str
    title: str
    description: str | None = None
    case_type: CaseType
    status: CaseStatus
    court_name: str | None = None
    court_building: str | None = None
    court_floor: str | None = None
    judge_name: str | None = None
    client_id: int
    client_name: str | None = None
    advocate_id: int
    opposing_party: str | None = None
    defending_party: str | None = None
    filing_date: datetime | None = None
    next_hearing_date: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
    hearings: list[HearingResponse] = []
    documents: list[DocumentResponse] = []
    notes: list[CaseNoteResponse] = []

    model_config = ConfigDict(from_attributes=True)
