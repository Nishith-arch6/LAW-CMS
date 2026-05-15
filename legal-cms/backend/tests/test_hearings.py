from datetime import date, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Hearing, HearingStatus


class TestCreateHearing:
    @pytest.mark.asyncio
    async def test_create_hearing_success(self, client_fixture: AsyncClient,
                                           case_obj):
        future_date = (date.today() + timedelta(days=14)).isoformat()
        payload = {
            "case_id": case_obj.id,
            "hearing_date": future_date,
            "hearing_time": "10:30:00",
            "court_room": "Room 401",
            "purpose": "Status hearing",
            "status": "SCHEDULED",
        }
        resp = await client_fixture.post("/api/hearings/", json=payload)
        assert resp.status_code == 201
        data = resp.json()
        assert data["hearing_date"] == future_date
        assert data["purpose"] == "Status hearing"

    @pytest.mark.asyncio
    async def test_create_hearing_past_date(self, client_fixture: AsyncClient,
                                             case_obj):
        past_date = (date.today() - timedelta(days=1)).isoformat()
        payload = {
            "case_id": case_obj.id,
            "hearing_date": past_date,
        }
        resp = await client_fixture.post("/api/hearings/", json=payload)
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_create_hearing_invalid_case(self, client_fixture: AsyncClient):
        future_date = (date.today() + timedelta(days=14)).isoformat()
        payload = {
            "case_id": 99999,
            "hearing_date": future_date,
        }
        resp = await client_fixture.post("/api/hearings/", json=payload)
        assert resp.status_code == 404


class TestListHearings:
    @pytest.mark.asyncio
    async def test_list_all_hearings(self, client_fixture: AsyncClient,
                                      hearing_obj):
        resp = await client_fixture.get("/api/hearings/")
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        assert len(data) >= 1

    @pytest.mark.asyncio
    async def test_list_hearings_by_case(self, client_fixture: AsyncClient,
                                          hearing_obj):
        resp = await client_fixture.get(f"/api/hearings/?case_id={hearing_obj.case_id}")
        assert resp.status_code == 200
        for h in resp.json():
            assert h["case_id"] == hearing_obj.case_id


class TestTodayHearings:
    @pytest.mark.asyncio
    async def test_hearings_today(self, client_fixture: AsyncClient,
                                   db_session: AsyncSession, case_obj):
        today_str = date.today().isoformat()
        h = Hearing(
            case_id=case_obj.id,
            hearing_date=date.today(),
            purpose="Today hearing",
            status=HearingStatus.SCHEDULED,
        )
        db_session.add(h)
        await db_session.flush()

        resp = await client_fixture.get("/api/hearings/today")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) >= 1
        assert data[0]["hearing_date"] == today_str

    @pytest.mark.asyncio
    async def test_hearings_today_empty(self, client_fixture: AsyncClient):
        resp = await client_fixture.get("/api/hearings/today")
        assert resp.status_code == 200
        assert resp.json() == []


class TestWeekHearings:
    @pytest.mark.asyncio
    async def test_hearings_week(self, client_fixture: AsyncClient,
                                  db_session: AsyncSession, case_obj):
        h = Hearing(
            case_id=case_obj.id,
            hearing_date=date.today() + timedelta(days=3),
            purpose="Week hearing",
            status=HearingStatus.SCHEDULED,
        )
        db_session.add(h)
        await db_session.flush()

        resp = await client_fixture.get("/api/hearings/week")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) >= 1
        assert data[0]["purpose"] == "Week hearing"


class TestUpdateHearing:
    @pytest.mark.asyncio
    async def test_update_hearing_success(self, client_fixture: AsyncClient,
                                           hearing_obj):
        resp = await client_fixture.put(
            f"/api/hearings/{hearing_obj.id}",
            json={"purpose": "Updated purpose", "court_room": "Room 500"},
        )
        assert resp.status_code == 200
        assert resp.json()["purpose"] == "Updated purpose"

    @pytest.mark.asyncio
    async def test_update_hearing_not_found(self, client_fixture: AsyncClient):
        resp = await client_fixture.put("/api/hearings/99999", json={"purpose": "Nope"})
        assert resp.status_code == 404


class TestCancelHearing:
    @pytest.mark.asyncio
    async def test_cancel_hearing(self, client_fixture: AsyncClient, hearing_obj):
        resp = await client_fixture.delete(f"/api/hearings/{hearing_obj.id}")
        assert resp.status_code == 204

    @pytest.mark.asyncio
    async def test_cancel_hearing_not_found(self, client_fixture: AsyncClient):
        resp = await client_fixture.delete("/api/hearings/99999")
        assert resp.status_code == 404


class TestAccessControl:
    @pytest.mark.asyncio
    async def test_cross_user_hearing_access(self, client_fixture: AsyncClient,
                                              db_session: AsyncSession, second_user):
        from app.models import Client as ClientModel
        from app.models import Case as CaseModel
        c = ClientModel(name="Other", advocate_id=second_user.id)
        db_session.add(c)
        await db_session.flush()
        oc = CaseModel(
            case_number="OTHER-001", title="Other",
            client_id=c.id, advocate_id=second_user.id,
        )
        db_session.add(oc)
        await db_session.flush()
        oh = Hearing(
            case_id=oc.id,
            hearing_date=date.today() + timedelta(days=10),
            purpose="Other hearing",
        )
        db_session.add(oh)
        await db_session.flush()

        resp = await client_fixture.get(f"/api/hearings/{oh.id}")
        # No direct GET endpoint for single hearing, test update instead
        resp = await client_fixture.put(
            f"/api/hearings/{oh.id}",
            json={"purpose": "Hacked"},
        )
        assert resp.status_code == 404
