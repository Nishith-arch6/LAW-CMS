from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.case import Case
from app.models.hearing import Hearing, HearingStatus
from app.models.user import User
from app.schemas.hearing import HearingCreate, HearingUpdate


class HearingService:
    def __init__(self, db: AsyncSession, current_user: User):
        self.db = db
        self.user = current_user

    def _base_query(self):
        return (
            select(Hearing)
            .join(Case)
            .where(
                Case.advocate_id == self.user.id,
                Case.is_deleted == False,
            )
        )

    async def list_hearings(
        self,
        case_id: int | None = None,
        skip: int = 0,
        limit: int = 20,
    ) -> list[Hearing]:
        query = self._base_query()
        if case_id is not None:
            query = query.where(Hearing.case_id == case_id)
        query = query.order_by(Hearing.hearing_date.asc()).offset(skip).limit(limit)
        result = await self.db.execute(query)
        return result.scalars().all()

    async def create_hearing(self, payload: HearingCreate) -> Hearing:
        result = await self.db.execute(
            select(Case).where(
                Case.id == payload.case_id,
                Case.advocate_id == self.user.id,
                Case.is_deleted == False,
            )
        )
        if not result.scalar_one_or_none():
            raise ValueError("Case not found or access denied")

        hearing = Hearing(**payload.model_dump())
        self.db.add(hearing)
        await self.db.flush()
        await self.db.refresh(hearing)
        return hearing

    async def update_hearing(
        self, hearing_id: int, payload: HearingUpdate
    ) -> Hearing | None:
        result = await self.db.execute(
            self._base_query().where(Hearing.id == hearing_id)
        )
        hearing = result.scalar_one_or_none()
        if not hearing:
            return None
        for key, val in payload.model_dump(exclude_unset=True).items():
            setattr(hearing, key, val)
        await self.db.flush()
        await self.db.refresh(hearing)
        return hearing

    async def cancel_hearing(self, hearing_id: int) -> bool:
        result = await self.db.execute(
            self._base_query().where(Hearing.id == hearing_id)
        )
        hearing = result.scalar_one_or_none()
        if not hearing:
            return False
        hearing.status = HearingStatus.CANCELLED
        await self.db.flush()
        return True

    async def get_today_hearings(
        self, skip: int = 0, limit: int = 50
    ) -> list[Hearing]:
        today = date.today()
        query = (
            self._base_query()
            .where(Hearing.hearing_date == today)
            .order_by(Hearing.hearing_time.asc().nullslast())
            .offset(skip)
            .limit(limit)
        )
        result = await self.db.execute(query)
        return result.scalars().all()

    async def get_week_hearings(
        self, skip: int = 0, limit: int = 50
    ) -> list[Hearing]:
        today = date.today()
        week_end = today + timedelta(days=7)
        query = (
            self._base_query()
            .where(Hearing.hearing_date.between(today, week_end))
            .order_by(Hearing.hearing_date.asc(), Hearing.hearing_time.asc().nullslast())
            .offset(skip)
            .limit(limit)
        )
        result = await self.db.execute(query)
        return result.scalars().all()
