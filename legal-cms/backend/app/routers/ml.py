from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.ml.classifier import classify_text, suggest_category
from app.ml.document_analyzer import (
    extract_case_number,
    extract_key_dates,
    extract_parties,
    summarize_document,
)
from app.models.case import Case as CaseModel
from app.models.document import Document
from app.models.user import User
from app.services.file_service import FileService

router = APIRouter()


# ── request / response models ──────────────────────────────────────────


class ClassifyRequest(BaseModel):
    text: str


class ClassifyResponse(BaseModel):
    category: str
    confidence: float


class SuggestRequest(BaseModel):
    title: str
    description: str = ""


class SuggestResponse(BaseModel):
    category: str
    confidence: float
    alternatives: list[dict] = []


class AnalyzeDocumentRequest(BaseModel):
    document_id: int


class AnalyzeDocumentResponse(BaseModel):
    key_dates: list[dict] = []
    parties: dict = {}
    case_number: str | None = None
    summary: str = ""


class SearchSimilarRequest(BaseModel):
    case_id: int
    limit: int = 5


class SearchSimilarResponse(BaseModel):
    similar_cases: list[dict] = []


# ── endpoints ──────────────────────────────────────────────────────────


@router.post("/classify", response_model=ClassifyResponse)
async def classify(payload: ClassifyRequest):
    if not payload.text.strip():
        raise HTTPException(status_code=400, detail="text must not be empty")
    try:
        return classify_text(payload.text)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Classification failed: {e}")


@router.post("/suggest-category", response_model=SuggestResponse)
async def suggest(payload: SuggestRequest):
    if not payload.title.strip():
        raise HTTPException(status_code=400, detail="title must not be empty")
    try:
        return suggest_category(payload.title, payload.description)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Suggestion failed: {e}")


@router.post("/analyze-document", response_model=AnalyzeDocumentResponse)
async def analyze_document(
    payload: AnalyzeDocumentRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = FileService(db, current_user)
    doc = await service.get_document(payload.document_id)
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    text = (doc.ocr_text or "") + "\n" + (doc.description or "")
    if not text.strip():
        return AnalyzeDocumentResponse()

    key_dates = extract_key_dates(text)
    parties = extract_parties(text)
    case_number = extract_case_number(text)
    summary = summarize_document(text)

    return AnalyzeDocumentResponse(
        key_dates=key_dates,
        parties=parties,
        case_number=case_number,
        summary=summary,
    )


@router.post("/search-similar", response_model=SearchSimilarResponse)
async def search_similar(
    payload: SearchSimilarRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(CaseModel).where(
            CaseModel.id == payload.case_id,
            CaseModel.advocate_id == current_user.id,
            CaseModel.is_deleted == False,
        )
    )
    source = result.scalar_one_or_none()
    if not source:
        raise HTTPException(status_code=404, detail="Case not found")

    source_text = f"{source.title} {source.description or ''} {source.opposing_party or ''}"

    cases_result = await db.execute(
        select(CaseModel).where(
            CaseModel.advocate_id == current_user.id,
            CaseModel.is_deleted == False,
            CaseModel.id != source.id,
        )
    )
    all_cases = cases_result.scalars().all()
    if not all_cases or not source_text.strip():
        return SearchSimilarResponse()

    try:
        from sklearn.feature_extraction.text import TfidfVectorizer
        import numpy as np

        corpus = [source_text] + [
            f"{c.title} {c.description or ''} {c.opposing_party or ''}" for c in all_cases
        ]
        vectorizer = TfidfVectorizer(max_features=5000, stop_words="english")
        tfidf = vectorizer.fit_transform(corpus)
        similarities = (tfidf[0] @ tfidf[1:].T).toarray()[0]
        top_n = similarities.argsort()[::-1][: payload.limit]

        similar = []
        for idx in top_n:
            sim_val = float(similarities[idx])
            if sim_val < 0.05:
                break
            c = all_cases[idx]
            similar.append({
                "id": c.id,
                "case_number": c.case_number,
                "title": c.title,
                "status": c.status.value,
                "case_type": c.case_type.value,
                "similarity": round(sim_val, 4),
            })

        return SearchSimilarResponse(similar_cases=similar)
    except ImportError:
        raise HTTPException(status_code=500, detail="sklearn not available for similarity search")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Similarity search failed: {e}")
