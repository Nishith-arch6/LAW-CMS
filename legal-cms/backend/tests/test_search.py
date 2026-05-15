import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Case, CaseStatus, CaseType, Document


class TestSearch:
    @pytest.mark.asyncio
    async def test_search_cases_by_title(self, client_fixture: AsyncClient,
                                          case_obj):
        resp = await client_fixture.get("/api/search/", params={
            "q": "Smith",
            "type": "cases",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert "results" in data
        assert len(data["results"]) >= 1
        assert data["results"][0]["type"] == "case"

    @pytest.mark.asyncio
    async def test_search_cases_by_number(self, client_fixture: AsyncClient,
                                           case_obj):
        resp = await client_fixture.get("/api/search/", params={
            "q": case_obj.case_number,
            "type": "cases",
        })
        assert resp.status_code == 200
        assert len(resp.json()["results"]) >= 1

    @pytest.mark.asyncio
    async def test_search_documents_by_name(self, client_fixture: AsyncClient,
                                             doc_obj):
        resp = await client_fixture.get("/api/search/", params={
            "q": "test_document",
            "type": "documents",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert "results" in data
        assert len(data["results"]) >= 1
        assert data["results"][0]["type"] == "document"

    @pytest.mark.asyncio
    async def test_search_all(self, client_fixture: AsyncClient,
                               case_obj, doc_obj):
        resp = await client_fixture.get("/api/search/", params={
            "q": "test",
            "type": "all",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert "cases" in data
        assert "documents" in data
        assert data["total"] >= 0

    @pytest.mark.asyncio
    async def test_search_no_results(self, client_fixture: AsyncClient):
        resp = await client_fixture.get("/api/search/", params={
            "q": "zzzznonexistent",
            "type": "all",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 0
        assert data["cases"] == []
        assert data["documents"] == []

    @pytest.mark.asyncio
    async def test_search_empty_query(self, client_fixture: AsyncClient):
        resp = await client_fixture.get("/api/search/", params={"q": ""})
        assert resp.status_code == 400

    @pytest.mark.asyncio
    async def test_search_documents_by_ocr(self, client_fixture: AsyncClient,
                                            db_session: AsyncSession, case_obj):
        d = Document(
            case_id=case_obj.id,
            file_name="contract.pdf",
            file_path="/tmp/contract.pdf",
            file_type="application/pdf",
            file_size=2048,
            ocr_text="This contract contains indemnification clauses",
            uploaded_by=case_obj.advocate_id,
        )
        db_session.add(d)
        await db_session.flush()

        resp = await client_fixture.get("/api/search/", params={
            "q": "indemnification",
            "type": "documents",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["results"]) >= 1

    @pytest.mark.asyncio
    async def test_search_cross_user_isolation(self, client_fixture: AsyncClient,
                                                db_session: AsyncSession,
                                                second_user):
        from app.models import Client as ClientModel
        c = ClientModel(name="Other", advocate_id=second_user.id)
        db_session.add(c)
        await db_session.flush()
        oc = Case(
            case_number="SECRET-001",
            title="Secret Case",
            client_id=c.id,
            advocate_id=second_user.id,
        )
        db_session.add(oc)
        await db_session.flush()

        resp = await client_fixture.get("/api/search/", params={
            "q": "Secret",
            "type": "cases",
        })
        assert resp.status_code == 200
        results = resp.json()["results"]
        assert all(r["case_number"] != "SECRET-001" for r in results)
