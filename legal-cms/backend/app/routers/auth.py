from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.core.rate_limiter import limiter
from app.models.user import User
from app.schemas.auth import AuthResponseSchema, LoginSchema, TokenSchema
from app.schemas.user import UserCreate, UserResponse
from app.services.auth_service import AuthService

router = APIRouter()
security = HTTPBearer()


@router.post("/register", response_model=AuthResponseSchema, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
async def register(request: Request, payload: UserCreate, db: AsyncSession = Depends(get_db)):
    service = AuthService(db)
    try:
        user = await service.register_user(payload)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    token = await service.issue_token(user)
    return AuthResponseSchema(access_token=token, user=UserResponse.model_validate(user))


@router.post("/login", response_model=AuthResponseSchema)
@limiter.limit("10/minute")
async def login(request: Request, payload: LoginSchema, db: AsyncSession = Depends(get_db)):
    service = AuthService(db)
    try:
        user = await service.authenticate_user(payload.email, payload.password)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))
    token = await service.issue_token(user)
    return AuthResponseSchema(access_token=token, user=UserResponse.model_validate(user))


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    credentials=Depends(security),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = AuthService(db)
    await service.blacklist_token(credentials.credentials)


@router.get("/me", response_model=UserResponse)
async def me(current_user: User = Depends(get_current_user)):
    return current_user
