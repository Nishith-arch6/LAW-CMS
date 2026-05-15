from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.hearing import HearingCreate, HearingResponse, HearingUpdate
from app.services.hearing_service import HearingService

router = APIRouter()


@router.get("/today", response_model=list[HearingResponse])
async def hearings_today(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = HearingService(db, current_user)
    return await service.get_today_hearings(skip=skip, limit=limit)


@router.get("/week", response_model=list[HearingResponse])
async def hearings_week(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = HearingService(db, current_user)
    return await service.get_week_hearings(skip=skip, limit=limit)


@router.get("/", response_model=list[HearingResponse])
async def list_hearings(
    case_id: int | None = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = HearingService(db, current_user)
    return await service.list_hearings(case_id=case_id, skip=skip, limit=limit)


@router.post("/", response_model=HearingResponse, status_code=status.HTTP_201_CREATED)
async def create_hearing(
    payload: HearingCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = HearingService(db, current_user)
    try:
        return await service.create_hearing(payload)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@router.put("/{hearing_id}", response_model=HearingResponse)
async def update_hearing(
    hearing_id: int,
    payload: HearingUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = HearingService(db, current_user)
    hearing = await service.update_hearing(hearing_id, payload)
    if not hearing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Hearing not found")
    return hearing


@router.delete("/{hearing_id}", status_code=status.HTTP_204_NO_CONTENT)
async def cancel_hearing(
    hearing_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = HearingService(db, current_user)
    cancelled = await service.cancel_hearing(hearing_id)
    if not cancelled:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Hearing not found")
