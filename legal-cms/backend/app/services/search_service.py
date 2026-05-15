import asyncio
import logging

from sqlalchemy import func, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.case import Case
from app.models.client import Client
from app.models.document import Document

logger = logging.getLogger("legal_cms.search")


def _highlight(text: str | None, query: str, max_len: int = 200) -> str | None:
    if not text:
        return None
    idx = text.lower().find(query.lower())
    if idx == -1:
        return text[:max_len]
    start = max(0, idx - 60)
    end = min(len(text), idx + len(query) + 60)
    snippet = text[start:end].strip()
    if start > 0:
        snippet = f"...{snippet}"
    if end < len(text):
        snippet = f"{snippet}..."
    if len(snippet) > max_len:
        snippet = snippet[:max_len] + "..."
    return snippet


async def search_cases(
    query: str,
    advocate_id: int,
    db: AsyncSession,
    skip: int = 0,
    limit: int = 20,
) -> list[dict]:
    pattern = f"%{query}%"
    stmt = (
        select(Case, Client.name.label("client_name"))
        .outerjoin(Client, Case.client_id == Client.id)
        .where(
            Case.advocate_id == advocate_id,
            Case.is_deleted == False,
            or_(
                Case.title.ilike(pattern),
                Case.description.ilike(pattern),
                Case.case_number.ilike(pattern),
                Client.name.ilike(pattern),
            ),
        )
        .order_by(Case.updated_at.desc().nullslast())
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(stmt)
    rows = result.all()
    return [
        {
            "type": "case",
            "id": row.Case.id,
            "case_number": row.Case.case_number,
            "title": row.Case.title,
            "status": row.Case.status.value,
            "client_name": row.client_name,
            "snippet": _highlight(
                f"{row.Case.title} {row.Case.description or ''}", query
            ),
            "rank": 1.0,
        }
        for row in rows
    ]


async def search_documents(
    query: str,
    advocate_id: int,
    db: AsyncSession,
    skip: int = 0,
    limit: int = 20,
) -> list[dict]:
    pattern = f"%{query}%"
    stmt = (
        select(Document, Case.case_number, Case.title.label("case_title"))
        .join(Case, Document.case_id == Case.id)
        .where(
            Case.advocate_id == advocate_id,
            Case.is_deleted == False,
            or_(
                Document.file_name.ilike(pattern),
                Document.description.ilike(pattern),
                Document.ocr_text.ilike(pattern),
            ),
        )
        .order_by(Document.uploaded_at.desc())
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(stmt)
    rows = result.all()
    return [
        {
            "type": "document",
            "id": row.Document.id,
            "file_name": row.Document.file_name,
            "file_type": row.Document.file_type,
            "case_id": row.Document.case_id,
            "case_number": row.case_number,
            "case_title": row.case_title,
            "snippet": _highlight(
                row.Document.ocr_text or row.Document.description or row.Document.file_name,
                query,
            ),
            "rank": 1.0,
        }
        for row in rows
    ]


async def search_all(
    query: str,
    advocate_id: int,
    db: AsyncSession,
    skip: int = 0,
    limit: int = 20,
) -> dict:
    if not query.strip():
        return {"cases": [], "documents": [], "total": 0}

    cases, docs = await asyncio.gather(
        search_cases(query, advocate_id, db, skip, limit),
        search_documents(query, advocate_id, db, skip, limit),
    )
    return {
        "cases": cases,
        "documents": docs,
        "total": len(cases) + len(docs),
    }
