from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.case import Case, CaseStatus, CaseType
from app.models.case_note import CaseNote
from app.models.client import Client
from app.models.document import Document
from app.models.hearing import Hearing, HearingStatus
from app.models.user import User
from app.schemas.case import CaseCreate, CaseUpdate
from app.schemas.dashboard import CaseSummarySchema, DashboardStatsSchema
from app.schemas.timeline import TimelineEventSchema


class CaseService:
    def __init__(self, db: AsyncSession, current_user: User):
        self.db = db
        self.user = current_user

    def _base_query(self):
        return select(Case).where(
            Case.advocate_id == self.user.id,
            Case.is_deleted == False,
        )

    async def list_cases(
        self,
        status: CaseStatus | None = None,
        case_type: CaseType | None = None,
        search: str | None = None,
        skip: int = 0,
        limit: int = 20,
    ) -> list[Case]:
        query = self._base_query()

        if status is not None:
            query = query.where(Case.status == status)
        if case_type is not None:
            query = query.where(Case.case_type == case_type)
        if search:
            pattern = f"%{search}%"
            query = query.where(
                or_(Case.title.ilike(pattern), Case.case_number.ilike(pattern))
            )

        query = query.order_by(Case.created_at.desc()).offset(skip).limit(limit)
        result = await self.db.execute(query)
        return result.scalars().all()

    async def create_case(self, payload: CaseCreate) -> Case:
        case = Case(**payload.model_dump(), advocate_id=self.user.id)
        self.db.add(case)
        await self.db.flush()
        await self.db.refresh(case)
        return case

    async def get_case(self, case_id: int) -> Case | None:
        query = (
            self._base_query()
            .where(Case.id == case_id)
            .options(
                selectinload(Case.hearings),
                selectinload(Case.documents),
                selectinload(Case.notes),
                selectinload(Case.client),
            )
        )
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def update_case(self, case_id: int, payload: CaseUpdate) -> Case | None:
        result = await self.db.execute(self._base_query().where(Case.id == case_id))
        case = result.scalar_one_or_none()
        if not case:
            return None
        for key, val in payload.model_dump(exclude_unset=True).items():
            setattr(case, key, val)
        await self.db.flush()
        await self.db.refresh(case)
        return case

    async def soft_delete_case(self, case_id: int) -> bool:
        result = await self.db.execute(self._base_query().where(Case.id == case_id))
        case = result.scalar_one_or_none()
        if not case:
            return False
        case.is_deleted = True
        case.deleted_at = datetime.now(timezone.utc)
        await self.db.flush()
        return True

    async def get_dashboard_stats(self) -> DashboardStatsSchema:
        today = date.today()
        week_end = today + timedelta(days=7)

        total_q = await self.db.execute(
            select(func.count(Case.id)).where(
                Case.advocate_id == self.user.id, Case.is_deleted == False
            )
        )
        total_cases = total_q.scalar() or 0

        active_q = await self.db.execute(
            select(func.count(Case.id)).where(
                Case.advocate_id == self.user.id,
                Case.is_deleted == False,
                Case.status == CaseStatus.ACTIVE,
            )
        )
        active_cases = active_q.scalar() or 0

        today_q = await self.db.execute(
            select(func.count(Hearing.id))
            .join(Case)
            .where(
                Case.advocate_id == self.user.id,
                Case.is_deleted == False,
                Hearing.hearing_date == today,
                Hearing.status == HearingStatus.SCHEDULED,
            )
        )
        pending_hearings_today = today_q.scalar() or 0

        week_q = await self.db.execute(
            select(func.count(Hearing.id))
            .join(Case)
            .where(
                Case.advocate_id == self.user.id,
                Case.is_deleted == False,
                Hearing.hearing_date.between(today, week_end),
                Hearing.status == HearingStatus.SCHEDULED,
            )
        )
        pending_hearings_week = week_q.scalar() or 0

        recent_q = await self.db.execute(
            self._base_query()
            .options(selectinload(Case.client), selectinload(Case.hearings))
            .order_by(Case.created_at.desc())
            .limit(5)
        )
        recent_cases_raw = recent_q.scalars().all()

        breakdown_q = await self.db.execute(
            select(Case.case_type, func.count(Case.id).label("count"))
            .where(Case.advocate_id == self.user.id, Case.is_deleted == False)
            .group_by(Case.case_type)
        )
        case_type_breakdown = {r.case_type.value: r.count for r in breakdown_q.all()}

        recent_cases = []
        for c in recent_cases_raw:
            next_h = next(
                (
                    h.hearing_date
                    for h in sorted(c.hearings, key=lambda x: x.hearing_date)
                    if h.hearing_date >= today and h.status == HearingStatus.SCHEDULED
                ),
                None,
            )
            recent_cases.append(
                CaseSummarySchema(
                    id=c.id,
                    case_number=c.case_number,
                    title=c.title,
                    status=c.status,
                    next_hearing_date=next_h,
                    client_name=c.client.name if c.client else None,
                )
            )

        return DashboardStatsSchema(
            total_cases=total_cases,
            active_cases=active_cases,
            pending_hearings_today=pending_hearings_today,
            pending_hearings_week=pending_hearings_week,
            case_type_breakdown=case_type_breakdown,
            recent_cases=recent_cases,
        )

    async def get_timeline(self, case_id: int) -> list[TimelineEventSchema]:
        result = await self.db.execute(self._base_query().where(Case.id == case_id))
        case = result.scalar_one_or_none()
        if not case:
            return []

        events: list[TimelineEventSchema] = []

        events.append(
            TimelineEventSchema(
                event_type="case_created",
                description=f"Case {case.case_number} was created",
                timestamp=case.created_at,
                metadata={"case_number": case.case_number, "status": case.status.value},
            )
        )

        h_result = await self.db.execute(
            select(Hearing)
            .where(Hearing.case_id == case_id)
            .order_by(Hearing.created_at.asc())
        )
        for h in h_result.scalars().all():
            events.append(
                TimelineEventSchema(
                    event_type="hearing",
                    description=f"Hearing scheduled on {h.hearing_date} — {h.purpose or 'No purpose'}",
                    timestamp=h.created_at,
                    metadata={
                        "hearing_id": h.id,
                        "hearing_date": str(h.hearing_date),
                        "status": h.status.value,
                    },
                )
            )

        d_result = await self.db.execute(
            select(Document)
            .where(Document.case_id == case_id)
            .order_by(Document.uploaded_at.asc())
        )
        for d in d_result.scalars().all():
            events.append(
                TimelineEventSchema(
                    event_type="document_uploaded",
                    description=f"Document '{d.file_name}' uploaded",
                    timestamp=d.uploaded_at,
                    metadata={"document_id": d.id, "file_name": d.file_name},
                )
            )

        n_result = await self.db.execute(
            select(CaseNote)
            .where(CaseNote.case_id == case_id)
            .order_by(CaseNote.created_at.asc())
        )
        for n in n_result.scalars().all():
            events.append(
                TimelineEventSchema(
                    event_type="note_added",
                    description=f"Note added by user #{n.author_id}",
                    timestamp=n.created_at,
                    metadata={"note_id": n.id, "author_id": n.author_id},
                )
            )

        events.sort(key=lambda e: e.timestamp)
        return events
