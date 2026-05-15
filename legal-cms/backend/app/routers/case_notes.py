from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user, get_db
from app.models.case import Case
from app.models.case_note import CaseNote
from app.models.user import User
from app.schemas.case_note import CaseNoteCreate, CaseNoteResponse

router = APIRouter()


@router.post("/", response_model=CaseNoteResponse, status_code=status.HTTP_201_CREATED)
async def add_note(
    payload: CaseNoteCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Case).where(Case.id == payload.case_id, Case.advocate_id == current_user.id, Case.is_deleted == False)
    )
    case = result.scalar_one_or_none()
    if not case:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Case not found")

    note = CaseNote(
        case_id=payload.case_id,
        author_id=current_user.id,
        content=payload.content,
    )
    db.add(note)
    await db.flush()
    await db.refresh(note)
    return note


@router.get("/case/{case_id}", response_model=list[CaseNoteResponse])
async def list_notes(
    case_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(CaseNote)
        .options(selectinload(CaseNote.author))
        .where(
            CaseNote.case.has(advocate_id=current_user.id, is_deleted=False),
            CaseNote.case_id == case_id,
        )
        .order_by(CaseNote.created_at.asc())
    )
    return result.scalars().all()


@router.delete("/{note_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_note(
    note_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(CaseNote).where(CaseNote.id == note_id, CaseNote.author_id == current_user.id)
    )
    note = result.scalar_one_or_none()
    if not note:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Note not found or not yours to delete")

    await db.delete(note)
