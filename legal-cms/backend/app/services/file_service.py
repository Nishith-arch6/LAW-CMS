import os
from typing import Any

from fastapi import HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.models.case import Case
from app.models.document import Document
from app.models.user import User
from app.schemas.document import DocumentResponse
from app.utils.storage import (
    MAX_FILE_SIZE,
    build_upload_path,
    generate_unique_filename,
    get_file_extension,
)


class FileService:
    OCR_EXTENSIONS = frozenset({".pdf", ".jpg", ".jpeg", ".png", ".txt", ".doc", ".docx"})

    def __init__(self, db: AsyncSession, current_user: User):
        self.db = db
        self.user = current_user

    async def validate_and_get_case(self, case_id: int) -> Case:
        result = await self.db.execute(
            select(Case).where(
                Case.id == case_id,
                Case.advocate_id == self.user.id,
                Case.is_deleted == False,
            )
        )
        case = result.scalar_one_or_none()
        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Case not found"
            )
        return case

    async def validate_file(self, file: UploadFile) -> None:
        ext = get_file_extension(file.filename or "")
        if ext not in self.OCR_EXTENSIONS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"File type '{ext}' is not allowed. Allowed: PDF, DOC, DOCX, JPG, PNG, TXT",
            )
        content = await file.read()
        if len(content) > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"File exceeds {settings.max_upload_size_mb}MB limit",
            )
        await file.seek(0)

    async def save_upload_file(
        self,
        file: UploadFile,
        case_id: int,
        description: str | None = None,
    ) -> DocumentResponse:
        await self.validate_and_get_case(case_id)
        await self.validate_file(file)

        content = await file.read()
        unique_name = generate_unique_filename(file.filename or "document")
        file_path = build_upload_path(self.user.id, case_id, unique_name)
        mime = file.content_type or "application/octet-stream"

        with open(file_path, "wb") as f:
            f.write(content)

        doc = Document(
            case_id=case_id,
            file_name=file.filename or unique_name,
            file_path=file_path,
            file_type=mime,
            file_size=len(content),
            description=description,
            uploaded_by=self.user.id,
        )
        self.db.add(doc)
        await self.db.flush()
        await self.db.refresh(doc)

        return DocumentResponse(
            id=doc.id,
            case_id=doc.case_id,
            file_name=doc.file_name,
            file_path=doc.file_path,
            file_type=doc.file_type,
            file_size=doc.file_size,
            description=doc.description,
            ocr_text=doc.ocr_text,
            uploaded_by=doc.uploaded_by,
            uploaded_at=str(doc.uploaded_at) if doc.uploaded_at else None,
        )

    async def list_all_documents(
        self, search: str | None = None, skip: int = 0, limit: int = 50
    ) -> list[DocumentResponse]:
        query = (
            select(Document)
            .join(Case)
            .where(Case.advocate_id == self.user.id, Case.is_deleted == False)
            .options(selectinload(Document.case))
            .order_by(Document.uploaded_at.desc())
        )
        if search:
            pattern = f"%{search}%"
            query = query.where(Document.file_name.ilike(pattern))
        query = query.offset(skip).limit(limit)
        result = await self.db.execute(query)
        docs = result.scalars().all()
        return [
            DocumentResponse(
                id=d.id,
                case_id=d.case_id,
                case_title=d.case.title if d.case else None,
                file_name=d.file_name,
                file_path=d.file_path,
                file_type=d.file_type,
                file_size=d.file_size,
                description=d.description,
                ocr_text=d.ocr_text,
                uploaded_by=d.uploaded_by,
                uploaded_at=str(d.uploaded_at) if d.uploaded_at else None,
            )
            for d in docs
        ]

    async def list_case_documents(self, case_id: int) -> list[DocumentResponse]:
        await self.validate_and_get_case(case_id)
        result = await self.db.execute(
            select(Document)
            .where(Document.case_id == case_id)
            .options(selectinload(Document.case))
            .order_by(Document.uploaded_at.desc())
        )
        docs = result.scalars().all()
        return [
            DocumentResponse(
                id=d.id,
                case_id=d.case_id,
                case_title=d.case.title if d.case else None,
                file_name=d.file_name,
                file_path=d.file_path,
                file_type=d.file_type,
                file_size=d.file_size,
                description=d.description,
                ocr_text=d.ocr_text,
                uploaded_by=d.uploaded_by,
                uploaded_at=str(d.uploaded_at) if d.uploaded_at else None,
            )
            for d in docs
        ]

    async def get_document(self, doc_id: int) -> Document | None:
        result = await self.db.execute(
            select(Document)
            .where(Document.id == doc_id)
            .options(selectinload(Document.case))
        )
        doc = result.scalar_one_or_none()
        if doc and doc.case.advocate_id != self.user.id:
            return None
        if doc and doc.case.is_deleted:
            return None
        return doc

    async def delete_document(self, doc_id: int) -> bool:
        doc = await self.get_document(doc_id)
        if not doc:
            return False
        if os.path.exists(doc.file_path):
            os.remove(doc.file_path)
        await self.db.delete(doc)
        await self.db.flush()
        return True

    async def get_ocr_text(self, doc_id: int) -> str | None:
        doc = await self.get_document(doc_id)
        if not doc:
            return None
        return doc.ocr_text
