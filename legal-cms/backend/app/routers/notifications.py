from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user, get_db
from app.models.hearing import Hearing, HearingStatus
from app.models.notification import Notification
from app.models.user import User
from app.services.notification_service import send_hearing_reminder

router = APIRouter()


@router.get("/")
async def list_notifications(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    unread_only: bool = Query(False),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = (
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .order_by(Notification.sent_at.desc())
        .offset(skip)
        .limit(limit)
    )
    if unread_only:
        query = query.where(Notification.read == False)

    result = await db.execute(query)
    notifications = result.scalars().all()

    return [
        {
            "id": n.id,
            "type": n.type.value,
            "title": n.title,
            "message": n.message[:200],
            "sent_at": str(n.sent_at) if n.sent_at else None,
            "read": n.read,
            "hearing_id": n.hearing_id,
        }
        for n in notifications
    ]


@router.post("/test-reminder")
async def test_reminder(
    hearing_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Hearing)
        .options(selectinload(Hearing.case))
        .where(Hearing.id == hearing_id)
    )
    hearing = result.scalar_one_or_none()
    if not hearing:
        raise HTTPException(status_code=404, detail="Hearing not found")
    if hearing.case.advocate_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")

    client_result = await db.execute(
        select(type("Client", (), {"name": None})).where(
            type("Client", (), {"id": 0}).id == 0
        )
    )
    from app.models.client import Client
    client_result = await db.execute(
        select(Client).where(Client.id == hearing.case.client_id)
    )
    client = client_result.scalar_one_or_none()

    success = await send_hearing_reminder(
        hearing=hearing,
        advocate=current_user,
        client_name=client.name if client else None,
        db=db,
    )
    await db.commit()

    return {
        "success": success,
        "message": "Reminder sent" if success else "Email not sent (check SMTP config)",
    }
