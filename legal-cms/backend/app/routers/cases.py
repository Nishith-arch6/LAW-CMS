from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.models.case import CaseStatus, CaseType
from app.models.hearing import HearingStatus
from app.models.user import User
from app.schemas.case import CaseCreate, CaseResponse, CaseUpdate
from app.schemas.case_detail import CaseDetailResponse
from app.schemas.dashboard import DashboardStatsSchema
from app.schemas.timeline import TimelineEventSchema
from app.services.case_service import CaseService

router = APIRouter()


@router.get("/stats/dashboard", response_model=DashboardStatsSchema)
async def dashboard_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = CaseService(db, current_user)
    return await service.get_dashboard_stats()


@router.get("/", response_model=list[CaseResponse])
async def list_cases(
    status: CaseStatus | None = Query(None),
    case_type: CaseType | None = Query(None),
    search: str | None = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = CaseService(db, current_user)
    return await service.list_cases(
        status=status, case_type=case_type, search=search, skip=skip, limit=limit
    )


@router.post("/", response_model=CaseResponse, status_code=status.HTTP_201_CREATED)
async def create_case(
    payload: CaseCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = CaseService(db, current_user)
    return await service.create_case(payload)


@router.get("/{case_id}", response_model=CaseDetailResponse)
async def get_case(
    case_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = CaseService(db, current_user)
    case = await service.get_case(case_id)
    if not case:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Case not found")

    today = date.today()
    next_hearing = next(
        (
            str(h.hearing_date)
            for h in sorted(case.hearings, key=lambda x: x.hearing_date)
            if h.hearing_date >= today and h.status == HearingStatus.SCHEDULED
        ),
        None,
    )

    return CaseDetailResponse(
        id=case.id,
        case_number=case.case_number,
        title=case.title,
        description=case.description,
        case_type=case.case_type,
        status=case.status,
        court_name=case.court_name,
        court_building=case.court_building,
        court_floor=case.court_floor,
        judge_name=case.judge_name,
        client_id=case.client_id,
        client_name=case.client.name if case.client else None,
        advocate_id=case.advocate_id,
        opposing_party=case.opposing_party,
        defending_party=case.defending_party,
        filing_date=str(case.filing_date) if case.filing_date else None,
        next_hearing_date=next_hearing,
        created_at=str(case.created_at) if case.created_at else None,
        updated_at=str(case.updated_at) if case.updated_at else None,
        hearings=list(case.hearings),
        documents=list(case.documents),
        notes=list(case.notes),
    )


@router.put("/{case_id}", response_model=CaseResponse)
async def update_case(
    case_id: int,
    payload: CaseUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = CaseService(db, current_user)
    case = await service.update_case(case_id, payload)
    if not case:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Case not found")
    return case


@router.delete("/{case_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_case(
    case_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = CaseService(db, current_user)
    deleted = await service.soft_delete_case(case_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Case not found")


@router.get("/{case_id}/timeline", response_model=list[TimelineEventSchema])
async def get_timeline(
    case_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = CaseService(db, current_user)
    events = await service.get_timeline(case_id)
    return events
