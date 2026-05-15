from datetime import date

from pydantic import BaseModel

from app.models.case import CaseStatus


class CaseSummarySchema(BaseModel):
    id: int
    case_number: str
    title: str
    status: CaseStatus
    next_hearing_date: date | None = None
    client_name: str | None = None


class DashboardStatsSchema(BaseModel):
    total_cases: int = 0
    active_cases: int = 0
    pending_hearings_today: int = 0
    pending_hearings_week: int = 0
    case_type_breakdown: dict[str, int] = {}
    recent_cases: list[CaseSummarySchema] = []
