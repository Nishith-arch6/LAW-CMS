from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.models.user import User
from app.services.search_service import search_all, search_cases, search_documents

router = APIRouter()


@router.get("/")
async def search(
    q: str = Query(..., min_length=1),
    type: str = Query("all", regex="^(cases|documents|all)$"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    q = q.strip()
    if not q:
        raise HTTPException(status_code=400, detail="q must not be empty")

    if type == "cases":
        results = await search_cases(q, current_user.id, db, skip, limit)
        return {"results": results, "total": len(results)}
    elif type == "documents":
        results = await search_documents(q, current_user.id, db, skip, limit)
        return {"results": results, "total": len(results)}
    else:
        return await search_all(q, current_user.id, db, skip, limit)
