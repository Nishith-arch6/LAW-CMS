import asyncio
import os
import shutil
import tempfile
from datetime import date, datetime, timedelta, timezone
from typing import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.main import app
from app.core.database import Base, get_db
from app.core.deps import get_current_user
from app.core.config import settings
from app.core.security import create_access_token
from app.models import User, Client, Case, CaseStatus, CaseType, Hearing, HearingStatus, Document

TEST_DB_URL = "sqlite+aiosqlite:///./test_legal_cms.db"


@pytest.fixture(scope="session", autouse=True)
def cleanup_test_db():
    yield
    for f in ["test_legal_cms.db", "test_legal_cms.db.wal", "test_legal_cms.db-shm"]:
        if os.path.exists(f):
            os.remove(f)


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(scope="session")
async def test_engine():
    engine = create_async_engine(TEST_DB_URL, echo=False)

    @event.listens_for(engine.sync_engine, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest_asyncio.fixture
async def db_session(test_engine) -> AsyncGenerator[AsyncSession, None]:
    session = async_sessionmaker(test_engine, class_=AsyncSession, expire_on_commit=False)()
    try:
        yield session
    finally:
        await session.rollback()
        await session.close()


orig_settings = {
    "upload_dir": settings.upload_dir,
    "debug": settings.debug,
    "secret_key": settings.secret_key,
}


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    tmpdir = tempfile.mkdtemp()
    settings.upload_dir = tmpdir
    settings.debug = False

    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        yield ac
    app.dependency_overrides.clear()
    settings.upload_dir = orig_settings["upload_dir"]
    settings.debug = orig_settings["debug"]

    import shutil
    shutil.rmtree(tmpdir, ignore_errors=True)


@pytest_asyncio.fixture
async def user(db_session: AsyncSession) -> User:
    from app.core.security import hash_password
    u = User(
        full_name="Test Advocate",
        email="advocate@test.com",
        hashed_password=hash_password("testpassword123"),
        bar_number="BAR12345",
        phone="+1234567890",
        is_active=True,
    )
    db_session.add(u)
    await db_session.flush()
    await db_session.refresh(u)
    return u


@pytest_asyncio.fixture
async def second_user(db_session: AsyncSession) -> User:
    from app.core.security import hash_password
    u = User(
        full_name="Second Advocate",
        email="advocate2@test.com",
        hashed_password=hash_password("testpassword456"),
        bar_number="BAR67890",
        phone="+1987654321",
        is_active=True,
    )
    db_session.add(u)
    await db_session.flush()
    await db_session.refresh(u)
    return u


@pytest_asyncio.fixture
async def token(user: User) -> str:
    return create_access_token(data={"sub": str(user.id)})


@pytest_asyncio.fixture
async def auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def client_fixture(db_session: AsyncSession, user: User,
                          token: str) -> AsyncGenerator[AsyncClient, None]:
    tmpdir = tempfile.mkdtemp()
    settings.upload_dir = tmpdir
    settings.debug = False

    async def override_get_db():
        yield db_session

    async def override_get_current_user():
        return user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test",
        headers={"Authorization": f"Bearer {token}"},
    ) as ac:
        yield ac

    app.dependency_overrides.clear()
    settings.upload_dir = orig_settings["upload_dir"]
    settings.debug = orig_settings["debug"]

    import shutil
    shutil.rmtree(tmpdir, ignore_errors=True)


@pytest_asyncio.fixture
async def client_obj(db_session: AsyncSession, user: User) -> Client:
    c = Client(
        name="John Smith",
        email="john@example.com",
        phone="+1987654321",
        address="123 Main St",
        notes="Test client",
        advocate_id=user.id,
    )
    db_session.add(c)
    await db_session.flush()
    await db_session.refresh(c)
    return c


@pytest_asyncio.fixture
async def case_obj(db_session: AsyncSession, user: User,
                    client_obj: Client) -> Case:
    c = Case(
        case_number="CASE-2026-001",
        title="Smith vs. Jones",
        description="Personal injury case",
        case_type=CaseType.CIVIL,
        status=CaseStatus.ACTIVE,
        court_name="Supreme Court",
        client_id=client_obj.id,
        advocate_id=user.id,
        filing_date=datetime.now(timezone.utc),
    )
    db_session.add(c)
    await db_session.flush()
    await db_session.refresh(c)
    return c


@pytest_asyncio.fixture
async def hearing_obj(db_session: AsyncSession, case_obj: Case) -> Hearing:
    h = Hearing(
        case_id=case_obj.id,
        hearing_date=date.today() + timedelta(days=7),
        hearing_time=None,
        court_room="Room 301",
        purpose="Preliminary hearing",
        status=HearingStatus.SCHEDULED,
    )
    db_session.add(h)
    await db_session.flush()
    await db_session.refresh(h)
    return h


@pytest_asyncio.fixture
async def doc_obj(db_session: AsyncSession, case_obj: Case,
                   user: User) -> Document:
    d = Document(
        case_id=case_obj.id,
        file_name="test_document.pdf",
        file_path="/tmp/test_doc.pdf",
        file_type="application/pdf",
        file_size=1024,
        uploaded_by=user.id,
    )
    db_session.add(d)
    await db_session.flush()
    await db_session.refresh(d)
    return d
