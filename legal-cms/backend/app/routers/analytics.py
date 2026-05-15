from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.models.case import Case, CaseType
from app.models.hearing import Hearing, HearingStatus
from app.models.user import User

router = APIRouter()


@router.get("/case-trends")
async def case_trends(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    now = datetime.now(timezone.utc)
    twelve_months_ago = now - timedelta(days=365)

    result = await db.execute(
        select(
            func.date_trunc("month", Case.created_at).label("month"),
            func.count(Case.id).label("count"),
        )
        .where(
            Case.advocate_id == current_user.id,
            Case.is_deleted == False,
            Case.created_at >= twelve_months_ago,
        )
        .group_by(func.date_trunc("month", Case.created_at))
        .order_by(func.date_trunc("month", Case.created_at))
    )
    rows = result.all()

    months = []
    counts = []
    for r in rows:
        months.append(r.month.strftime("%Y-%m") if hasattr(r.month, "strftime") else str(r.month))
        counts.append(r.count)

    return {"months": months, "counts": counts}


@router.get("/hearing-compliance")
async def hearing_compliance(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(
            func.count(Hearing.id).label("total"),
            func.sum(
                func.cast(Hearing.status == HearingStatus.COMPLETED, func.Integer)
            ).label("completed"),
            func.sum(
                func.cast(Hearing.status == HearingStatus.SCHEDULED, func.Integer)
            ).label("scheduled"),
        ).where(Hearing.case.has(advocate_id=current_user.id))
    )
    row = result.one()
    total = row.total or 0
    completed = row.completed or 0
    scheduled = row.scheduled or 0
    compliance_rate = round((completed / total * 100), 1) if total > 0 else 0.0

    return {
        "total_hearings": total,
        "completed": completed,
        "scheduled": scheduled,
        "compliance_rate": compliance_rate,
    }


@router.get("/case-type-breakdown")
async def case_type_breakdown(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Case.case_type, func.count(Case.id).label("count"))
        .where(
            Case.advocate_id == current_user.id,
            Case.is_deleted == False,
        )
        .group_by(Case.case_type)
    )
    rows = result.all()
    breakdown = {r.case_type.value: r.count for r in rows} if rows else {}
    return breakdown
