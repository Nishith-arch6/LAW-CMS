import hashlib

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, hash_password, verify_password
from app.models.token_blacklist import BlacklistedToken
from app.models.user import User
from app.schemas.user import UserCreate


class AuthService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def register_user(self, payload: UserCreate) -> User:
        result = await self.db.execute(select(User).where(User.email == payload.email))
        if result.scalar_one_or_none():
            raise ValueError("Email already registered")

        if payload.bar_number:
            result = await self.db.execute(
                select(User).where(User.bar_number == payload.bar_number)
            )
            if result.scalar_one_or_none():
                raise ValueError("Bar number already registered")

        user = User(
            full_name=payload.full_name,
            email=payload.email,
            hashed_password=hash_password(payload.password),
            bar_number=payload.bar_number,
            phone=payload.phone,
            is_active=True,
        )
        self.db.add(user)
        await self.db.flush()
        await self.db.refresh(user)
        return user

    async def authenticate_user(self, email: str, password: str) -> User:
        result = await self.db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if not user or not verify_password(password, user.hashed_password):
            raise ValueError("Invalid credentials")
        if not user.is_active:
            raise ValueError("Account is deactivated")
        return user

    async def get_user_by_email(self, email: str) -> User | None:
        result = await self.db.execute(select(User).where(User.email == email))
        return result.scalar_one_or_none()

    async def issue_token(self, user: User) -> str:
        return create_access_token(data={"sub": str(user.id)})

    async def blacklist_token(self, token: str) -> None:
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        existing = await self.db.execute(
            select(BlacklistedToken).where(BlacklistedToken.token_hash == token_hash)
        )
        if not existing.scalar_one_or_none():
            entry = BlacklistedToken(token_hash=token_hash)
            self.db.add(entry)
            await self.db.flush()
