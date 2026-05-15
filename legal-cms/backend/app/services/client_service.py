from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.case import Case
from app.models.client import Client
from app.models.user import User
from app.schemas.client import ClientCreate, ClientUpdate


class ClientService:
    def __init__(self, db: AsyncSession, current_user: User):
        self.db = db
        self.user = current_user

    def _base_query(self):
        return select(Client).where(Client.advocate_id == self.user.id)

    async def list_clients(
        self, search: str | None = None, skip: int = 0, limit: int = 20
    ) -> list[Client]:
        query = self._base_query()
        if search:
            pattern = f"%{search}%"
            query = query.where(
                or_(Client.name.ilike(pattern), Client.phone.ilike(pattern))
            )
        query = query.order_by(Client.created_at.desc()).offset(skip).limit(limit)
        result = await self.db.execute(query)
        return result.scalars().all()

    async def create_client(self, payload: ClientCreate) -> Client:
        data = payload.model_dump()
        data.pop("advocate_id", None)
        client = Client(**data, advocate_id=self.user.id)
        self.db.add(client)
        await self.db.flush()
        await self.db.refresh(client)
        return client

    async def get_client(self, client_id: int) -> Client | None:
        result = await self.db.execute(
            self._base_query().where(Client.id == client_id)
        )
        return result.scalar_one_or_none()

    async def update_client(
        self, client_id: int, payload: ClientUpdate
    ) -> Client | None:
        result = await self.db.execute(
            self._base_query().where(Client.id == client_id)
        )
        client = result.scalar_one_or_none()
        if not client:
            return None
        for key, val in payload.model_dump(exclude_unset=True).items():
            setattr(client, key, val)
        await self.db.flush()
        await self.db.refresh(client)
        return client

    async def delete_client(self, client_id: int) -> bool:
        result = await self.db.execute(
            self._base_query().where(Client.id == client_id)
        )
        client = result.scalar_one_or_none()
        if not client:
            return False
        await self.db.delete(client)
        await self.db.flush()
        return True

    async def get_client_cases(
        self, client_id: int, skip: int = 0, limit: int = 20
    ) -> list[Case]:
        result = await self.db.execute(
            self._base_query().where(Client.id == client_id)
        )
        client = result.scalar_one_or_none()
        if not client:
            return []

        cases_result = await self.db.execute(
            select(Case)
            .where(
                Case.client_id == client_id,
                Case.advocate_id == self.user.id,
                Case.is_deleted == False,
            )
            .order_by(Case.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        return cases_result.scalars().all()
