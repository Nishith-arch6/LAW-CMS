import io
import os

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession


class TestDocumentUpload:
    @pytest.mark.asyncio
    async def test_upload_document_success(self, client_fixture: AsyncClient,
                                            case_obj):
        content = b"This is a test document content for upload testing."
        resp = await client_fixture.post(
            "/api/documents/upload",
            files={"file": ("test.txt", content, "text/plain")},
            data={"case_id": str(case_obj.id)},
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["file_name"] == "test.txt"
        assert data["case_id"] == case_obj.id
        assert data["file_type"] == "text/plain"

    @pytest.mark.asyncio
    async def test_upload_document_missing_case(self, client_fixture: AsyncClient):
        content = b"Test content"
        resp = await client_fixture.post(
            "/api/documents/upload",
            files={"file": ("test.txt", content, "text/plain")},
            data={"case_id": "99999"},
        )
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_upload_document_no_file(self, client_fixture: AsyncClient):
        resp = await client_fixture.post(
            "/api/documents/upload",
            data={"case_id": "1"},
        )
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_upload_pdf(self, client_fixture: AsyncClient, case_obj):
        content = b"%PDF-1.4 fake pdf content for testing"
        resp = await client_fixture.post(
            "/api/documents/upload",
            files={"file": ("doc.pdf", content, "application/pdf")},
            data={"case_id": str(case_obj.id)},
        )
        assert resp.status_code == 201
        assert resp.json()["file_type"] == "application/pdf"

    @pytest.mark.asyncio
    async def test_upload_with_description(self, client_fixture: AsyncClient,
                                            case_obj):
        content = b"Test doc with description"
        resp = await client_fixture.post(
            "/api/documents/upload",
            files={"file": ("desc.txt", content, "text/plain")},
            data={"case_id": str(case_obj.id), "description": "Test description"},
        )
        assert resp.status_code == 201
        assert resp.json()["description"] == "Test description"


class TestListDocuments:
    @pytest.mark.asyncio
    async def test_list_case_documents(self, client_fixture: AsyncClient,
                                        case_obj, doc_obj):
        resp = await client_fixture.get(f"/api/documents/case/{case_obj.id}")
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        assert len(data) >= 1

    @pytest.mark.asyncio
    async def test_list_documents_empty(self, client_fixture: AsyncClient,
                                         case_obj):
        resp = await client_fixture.get(f"/api/documents/case/{case_obj.id}")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    @pytest.mark.asyncio
    async def test_list_documents_invalid_case(self, client_fixture: AsyncClient):
        resp = await client_fixture.get("/api/documents/case/99999")
        assert resp.status_code == 404


class TestDownloadDocument:
    @pytest.mark.asyncio
    async def test_download_document(self, client_fixture: AsyncClient,
                                      case_obj):
        content = b"Downloadable content"
        upload_resp = await client_fixture.post(
            "/api/documents/upload",
            files={"file": ("download.txt", content, "text/plain")},
            data={"case_id": str(case_obj.id)},
        )
        doc_id = upload_resp.json()["id"]

        resp = await client_fixture.get(f"/api/documents/{doc_id}/download")
        assert resp.status_code == 200
        assert resp.headers.get("content-type") == "text/plain"

    @pytest.mark.asyncio
    async def test_download_nonexistent(self, client_fixture: AsyncClient):
        resp = await client_fixture.get("/api/documents/99999/download")
        assert resp.status_code == 404


class TestDocumentOcr:
    @pytest.mark.asyncio
    async def test_get_ocr_text_empty(self, client_fixture: AsyncClient,
                                       doc_obj):
        resp = await client_fixture.get(f"/api/documents/{doc_obj.id}/ocr-text")
        assert resp.status_code == 200
        data = resp.json()
        assert "ocr_text" in data
        assert data["ocr_text"] is None


class TestDeleteDocument:
    @pytest.mark.asyncio
    async def test_delete_document(self, client_fixture: AsyncClient,
                                    case_obj):
        content = b"To be deleted"
        upload_resp = await client_fixture.post(
            "/api/documents/upload",
            files={"file": ("delete.txt", content, "text/plain")},
            data={"case_id": str(case_obj.id)},
        )
        doc_id = upload_resp.json()["id"]

        resp = await client_fixture.delete(f"/api/documents/{doc_id}")
        assert resp.status_code == 204

        resp = await client_fixture.get(f"/api/documents/{doc_id}/download")
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_nonexistent(self, client_fixture: AsyncClient):
        resp = await client_fixture.delete("/api/documents/99999")
        assert resp.status_code == 404
