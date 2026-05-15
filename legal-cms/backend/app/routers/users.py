import os
import uuid

from fastapi import APIRouter, Depends, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate

router = APIRouter()


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.put("/me", response_model=UserResponse)
async def update_me(
    payload: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    update_data = payload.model_dump(exclude_unset=True, exclude={"password"})

    if payload.email is not None and payload.email != current_user.email:
        result = await db.execute(select(User).where(User.email == payload.email))
        if result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Email already in use",
            )
        current_user.email = payload.email

    if payload.bar_number is not None and payload.bar_number != current_user.bar_number:
        result = await db.execute(
            select(User).where(User.bar_number == payload.bar_number)
        )
        if result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Bar number already in use",
            )
        current_user.bar_number = payload.bar_number

    if payload.password is not None:
        from app.core.security import hash_password

        current_user.hashed_password = hash_password(payload.password)

    for field, value in update_data.items():
        setattr(current_user, field, value)

    await db.flush()
    await db.refresh(current_user)
    return current_user


@router.post("/me/photo", response_model=UserResponse)
async def upload_photo(
    file: UploadFile,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    allowed_types = {"image/jpeg", "image/png", "image/webp"}
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPEG, PNG, and WebP images are allowed",
        )

    content = await file.read()
    if len(content) > settings.max_upload_size_mb * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File exceeds {settings.max_upload_size_mb}MB limit",
        )

    ext = os.path.splitext(file.filename or "photo")[1]
    filename = f"profile_{uuid.uuid4().hex}{ext}"
    upload_path = os.path.join(settings.upload_dir, "profiles")
    os.makedirs(upload_path, exist_ok=True)
    dest = os.path.join(upload_path, filename)

    with open(dest, "wb") as f:
        f.write(content)

    current_user.profile_photo_url = dest
    await db.flush()
    await db.refresh(current_user)
    return current_user
