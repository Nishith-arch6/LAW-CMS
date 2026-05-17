from fastapi import APIRouter, BackgroundTasks, Depends, Form, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.document import DocumentResponse
from app.services.file_service import FileService
from app.services.ocr_service import run_ocr_and_save
from app.utils.storage import get_file_extension
from app.utils.upload_validator import validate_upload

router = APIRouter()


def _should_ocr(filename: str) -> bool:
    return get_file_extension(filename) in {".pdf", ".jpg", ".jpeg", ".png", ".txt", ".doc", ".docx"}


@router.get("/", response_model=list[DocumentResponse])
async def list_all_documents(
    search: str | None = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = FileService(db, current_user)
    return await service.list_all_documents(search=search, skip=skip, limit=limit)


@router.post("/upload", response_model=DocumentResponse, status_code=status.HTTP_201_CREATED)
async def upload_document(
    background_tasks: BackgroundTasks,
    file: UploadFile,
    case_id: int = Form(...),
    description: str | None = Form(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await validate_upload(file)
    service = FileService(db, current_user)
    doc = await service.save_upload_file(
        file=file, case_id=case_id, description=description
    )

    if _should_ocr(doc.file_name):
        background_tasks.add_task(
            run_ocr_and_save,
            document_id=doc.id,
            file_path=doc.file_path,
            file_type=doc.file_type or "",
        )

    return doc


@router.get("/case/{case_id}", response_model=list[DocumentResponse])
async def list_case_documents(
    case_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = FileService(db, current_user)
    return await service.list_case_documents(case_id)


@router.get("/{doc_id}/download")
async def download_document(
    doc_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = FileService(db, current_user)
    doc = await service.get_document(doc_id)
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")
    return FileResponse(
        path=doc.file_path,
        filename=doc.file_name,
        media_type=doc.file_type or "application/octet-stream",
    )


@router.delete("/{doc_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    doc_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = FileService(db, current_user)
    deleted = await service.delete_document(doc_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")


@router.get("/{doc_id}/ocr-text")
async def get_document_ocr(
    doc_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = FileService(db, current_user)
    text = await service.get_ocr_text(doc_id)
    if text is None:
        doc = await service.get_document(doc_id)
        if not doc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Document not found"
            )
        return {"ocr_text": None, "message": "OCR text not available for this document"}
    return {"ocr_text": text}
