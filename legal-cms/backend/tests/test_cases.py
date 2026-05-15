import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Case, CaseStatus, CaseType


class TestCreateCase:
    @pytest.mark.asyncio
    async def test_create_case_success(self, client_fixture: AsyncClient,
                                        client_obj):
        payload = {
            "case_number": "CASE-2026-100",
            "title": "New Test Case",
            "client_id": client_obj.id,
            "case_type": "CIVIL",
            "status": "ACTIVE",
        }
        resp = await client_fixture.post("/api/cases/", json=payload)
        assert resp.status_code == 201
        data = resp.json()
        assert data["case_number"] == "CASE-2026-100"
        assert data["title"] == "New Test Case"
        assert data["case_type"] == "CIVIL"

    @pytest.mark.asyncio
    async def test_create_case_missing_required(self, client_fixture: AsyncClient):
        resp = await client_fixture.post("/api/cases/", json={})
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_create_case_duplicate_number(self, client_fixture: AsyncClient,
                                                 client_obj, case_obj):
        payload = {
            "case_number": case_obj.case_number,
            "title": "Duplicate",
            "client_id": client_obj.id,
        }
        resp = await client_fixture.post("/api/cases/", json=payload)
        assert resp.status_code == 409 or resp.status_code == 500

    @pytest.mark.asyncio
    async def test_create_case_invalid_client(self, client_fixture: AsyncClient):
        payload = {
            "case_number": "CASE-2026-999",
            "title": "Bad Client",
            "client_id": 99999,
        }
        resp = await client_fixture.post("/api/cases/", json=payload)
        assert resp.status_code == 404


class TestListCases:
    @pytest.mark.asyncio
    async def test_list_cases(self, client_fixture: AsyncClient, case_obj):
        resp = await client_fixture.get("/api/cases/")
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        assert len(data) >= 1

    @pytest.mark.asyncio
    async def test_list_cases_pagination(self, client_fixture: AsyncClient):
        resp = await client_fixture.get("/api/cases/?skip=0&limit=5")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    @pytest.mark.asyncio
    async def test_filter_by_status(self, client_fixture: AsyncClient, case_obj):
        resp = await client_fixture.get(f"/api/cases/?status={CaseStatus.ACTIVE.value}")
        assert resp.status_code == 200
        for c in resp.json():
            assert c["status"] == CaseStatus.ACTIVE.value

    @pytest.mark.asyncio
    async def test_filter_by_type(self, client_fixture: AsyncClient, case_obj):
        resp = await client_fixture.get(f"/api/cases/?case_type={CaseType.CIVIL.value}")
        assert resp.status_code == 200
        for c in resp.json():
            assert c["case_type"] == CaseType.CIVIL.value

    @pytest.mark.asyncio
    async def test_filter_no_results(self, client_fixture: AsyncClient):
        resp = await client_fixture.get("/api/cases/?status=CLOSED")
        assert resp.status_code == 200
        assert resp.json() == []


class TestSearchCases:
    @pytest.mark.asyncio
    async def test_search_by_case_number(self, client_fixture: AsyncClient,
                                          case_obj):
        resp = await client_fixture.get(f"/api/cases/?search={case_obj.case_number}")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) >= 1
        assert data[0]["case_number"] == case_obj.case_number

    @pytest.mark.asyncio
    async def test_search_by_title(self, client_fixture: AsyncClient, case_obj):
        resp = await client_fixture.get("/api/cases/?search=Smith")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) >= 1

    @pytest.mark.asyncio
    async def test_search_no_match(self, client_fixture: AsyncClient):
        resp = await client_fixture.get("/api/cases/?search=zzzznonexistent")
        assert resp.status_code == 200
        assert resp.json() == []


class TestGetCase:
    @pytest.mark.asyncio
    async def test_get_case_success(self, client_fixture: AsyncClient, case_obj):
        resp = await client_fixture.get(f"/api/cases/{case_obj.id}")
        assert resp.status_code == 200
        data = resp.json()
        assert data["id"] == case_obj.id
        assert data["case_number"] == case_obj.case_number

    @pytest.mark.asyncio
    async def test_get_case_detail_includes_relations(self, client_fixture: AsyncClient,
                                                       case_obj):
        resp = await client_fixture.get(f"/api/cases/{case_obj.id}")
        assert resp.status_code == 200
        data = resp.json()
        assert "hearings" in data
        assert "documents" in data
        assert "notes" in data

    @pytest.mark.asyncio
    async def test_get_case_not_found(self, client_fixture: AsyncClient):
        resp = await client_fixture.get("/api/cases/99999")
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_get_case_access_denied(self, client_fixture: AsyncClient,
                                           db_session: AsyncSession, second_user):
        from app.models import Client as ClientModel
        c = ClientModel(
            name="Other Client",
            email="other@test.com",
            advocate_id=second_user.id,
        )
        db_session.add(c)
        await db_session.flush()

        from app.models import Case as CaseModel
        other_case = CaseModel(
            case_number="CASE-OTHER-001",
            title="Other Case",
            client_id=c.id,
            advocate_id=second_user.id,
        )
        db_session.add(other_case)
        await db_session.flush()

        resp = await client_fixture.get(f"/api/cases/{other_case.id}")
        assert resp.status_code == 404


class TestUpdateCase:
    @pytest.mark.asyncio
    async def test_update_case_success(self, client_fixture: AsyncClient, case_obj):
        resp = await client_fixture.put(
            f"/api/cases/{case_obj.id}",
            json={"title": "Updated Title", "status": "PENDING"},
        )
        assert resp.status_code == 200
        assert resp.json()["title"] == "Updated Title"
        assert resp.json()["status"] == "PENDING"

    @pytest.mark.asyncio
    async def test_update_case_not_found(self, client_fixture: AsyncClient):
        resp = await client_fixture.put("/api/cases/99999", json={"title": "Nope"})
        assert resp.status_code == 404


class TestDeleteCase:
    @pytest.mark.asyncio
    async def test_soft_delete_case(self, client_fixture: AsyncClient, case_obj):
        resp = await client_fixture.delete(f"/api/cases/{case_obj.id}")
        assert resp.status_code == 204

        resp = await client_fixture.get("/api/cases/")
        ids = [c["id"] for c in resp.json()]
        assert case_obj.id not in ids

    @pytest.mark.asyncio
    async def test_delete_case_not_found(self, client_fixture: AsyncClient):
        resp = await client_fixture.delete("/api/cases/99999")
        assert resp.status_code == 404


class TestDashboard:
    @pytest.mark.asyncio
    async def test_dashboard_stats(self, client_fixture: AsyncClient, case_obj):
        resp = await client_fixture.get("/api/cases/stats/dashboard")
        assert resp.status_code == 200
        data = resp.json()
        assert "total_cases" in data
        assert "active_cases" in data
        assert "pending_hearings_today" in data
        assert "pending_hearings_week" in data
        assert "recent_cases" in data
        assert data["total_cases"] >= 1


class TestCaseTimeline:
    @pytest.mark.asyncio
    async def test_get_timeline(self, client_fixture: AsyncClient, case_obj):
        resp = await client_fixture.get(f"/api/cases/{case_obj.id}/timeline")
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        if data:
            assert "event_type" in data[0]
            assert "description" in data[0]
