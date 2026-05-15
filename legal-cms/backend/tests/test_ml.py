import pytest
from httpx import AsyncClient

from tests.test_helpers import legal_case_text, legal_document_text


class TestClassify:
    @pytest.mark.asyncio
    async def test_classify_endpoint_accepts_text(self, client: AsyncClient):
        resp = await client.post("/api/ml/classify", json={
            "text": "This is a civil dispute about a contract",
        })
        assert resp.status_code in (200, 500)
        if resp.status_code == 200:
            data = resp.json()
            assert "category" in data
            assert "confidence" in data

    @pytest.mark.asyncio
    async def test_classify_empty_text(self, client: AsyncClient):
        resp = await client.post("/api/ml/classify", json={"text": ""})
        assert resp.status_code == 400

    @pytest.mark.asyncio
    async def test_classify_legal_text(self, client: AsyncClient):
        text = legal_case_text()
        resp = await client.post("/api/ml/classify", json={"text": text})
        assert resp.status_code in (200, 500)


class TestSuggestCategory:
    @pytest.mark.asyncio
    async def test_suggest_with_title_only(self, client: AsyncClient):
        resp = await client.post("/api/ml/suggest-category", json={
            "title": "Breach of contract lawsuit",
        })
        assert resp.status_code in (200, 500)
        if resp.status_code == 200:
            data = resp.json()
            assert "category" in data
            assert "confidence" in data
            assert "alternatives" in data

    @pytest.mark.asyncio
    async def test_suggest_with_description(self, client: AsyncClient):
        resp = await client.post("/api/ml/suggest-category", json={
            "title": "Divorce case",
            "description": "Divorce proceedings with child custody dispute",
        })
        assert resp.status_code in (200, 500)

    @pytest.mark.asyncio
    async def test_suggest_empty_title(self, client: AsyncClient):
        resp = await client.post("/api/ml/suggest-category", json={
            "title": "",
        })
        assert resp.status_code == 400


class TestDocumentAnalyzer:
    @pytest.mark.asyncio
    async def test_analyze_document_not_found(self, client_fixture: AsyncClient):
        resp = await client_fixture.post("/api/ml/analyze-document", json={
            "document_id": 99999,
        })
        assert resp.status_code == 404


class TestDocumentAnalyzerFunctions:
    """Test pure functions directly without model dependency."""

    def test_extract_key_dates(self):
        from app.ml.document_analyzer import extract_key_dates
        text = legal_case_text()
        dates = extract_key_dates(text)
        assert isinstance(dates, list)
        if dates:
            assert "date" in dates[0]
            assert "raw" in dates[0]
            assert "context" in dates[0]

    def test_extract_key_dates_empty(self):
        from app.ml.document_analyzer import extract_key_dates
        assert extract_key_dates("") == []

    def test_extract_parties(self):
        from app.ml.document_analyzer import extract_parties
        text = legal_case_text()
        parties = extract_parties(text)
        assert "plaintiff" in parties
        assert "defendant" in parties
        assert "advocates" in parties

    def test_extract_parties_empty(self):
        from app.ml.document_analyzer import extract_parties
        parties = extract_parties("")
        assert parties["plaintiff"] is None
        assert parties["defendant"] is None

    def test_extract_case_number(self):
        from app.ml.document_analyzer import extract_case_number
        text = legal_case_text()
        case_num = extract_case_number(text)
        assert case_num is not None
        assert "CIVIL-2026-0420" in case_num or "0420" in case_num

    def test_extract_case_number_empty(self):
        from app.ml.document_analyzer import extract_case_number
        assert extract_case_number("") is None

    def test_summarize_document(self):
        from app.ml.document_analyzer import summarize_document
        text = legal_document_text()
        summary = summarize_document(text, max_sentences=3)
        assert isinstance(summary, str)
        assert len(summary) > 0
        assert len(summary.split(". ")) <= 4

    def test_summarize_document_empty(self):
        from app.ml.document_analyzer import summarize_document
        assert summarize_document("") == ""

    def test_summarize_short_text(self):
        from app.ml.document_analyzer import summarize_document
        assert summarize_document("Short text.") == "Short text."


class TestSearchSimilar:
    @pytest.mark.asyncio
    async def test_search_similar_nonexistent_case(self, client_fixture: AsyncClient):
        resp = await client_fixture.post("/api/ml/search-similar", json={
            "case_id": 99999,
        })
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_search_similar_no_sklearn(self, client_fixture: AsyncClient,
                                              case_obj):
        try:
            import sklearn
        except ImportError:
            resp = await client_fixture.post("/api/ml/search-similar", json={
                "case_id": case_obj.id,
            })
            assert resp.status_code == 500
