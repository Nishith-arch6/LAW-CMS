"""
APScheduler integration — runs reminder and digest jobs.
"""

import logging
from datetime import date, timedelta

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.database import async_session_factory

logger = logging.getLogger("legal_cms.scheduler")
scheduler = AsyncIOScheduler()


async def check_upcoming_hearings():
    logger.info("Scheduler: checking upcoming hearings ...")
    today = date.today()
    targets = {today + timedelta(days=1), today + timedelta(days=3)}

    async with async_session_factory() as db:
        for offset in targets:
            from app.models.hearing import Hearing
            from app.models.hearing import HearingStatus

            result = await db.execute(
                select(Hearing)
                .options(
                    selectinload(Hearing.case),
                )
                .where(
                    Hearing.hearing_date == offset,
                    Hearing.reminder_sent == False,
                    Hearing.status == HearingStatus.SCHEDULED,
                )
            )
            hearings = result.scalars().all()

            for hearing in hearings:
                try:
                    from app.models.client import Client
                    from app.models.user import User
                    from app.services.notification_service import (
                        send_hearing_reminder,
                    )

                    advocate_result = await db.execute(
                        select(User).where(User.id == hearing.case.advocate_id)
                    )
                    advocate = advocate_result.scalar_one_or_none()
                    if not advocate:
                        continue

                    client_result = await db.execute(
                        select(Client).where(Client.id == hearing.case.client_id)
                    )
                    client = client_result.scalar_one_or_none()

                    await send_hearing_reminder(
                        hearing=hearing,
                        advocate=advocate,
                        client_name=client.name if client else None,
                        db=db,
                    )
                    logger.info(
                        "Reminder sent for hearing %d (%s) to %s",
                        hearing.id,
                        hearing.case.case_number,
                        advocate.email,
                    )
                except Exception as e:
                    logger.error("Failed to process hearing %d: %s", hearing.id, e)

        await db.commit()


async def daily_digest():
    logger.info("Scheduler: generating daily digest ...")
    async with async_session_factory() as db:
        from app.models.case import Case
        from app.models.hearing import Hearing, HearingStatus
        from app.models.user import User
        from app.services.notification_service import send_email

        today = date.today()
        tomorrow = today + timedelta(days=1)

        result = await db.execute(
            select(User).where(User.is_active == True)
        )
        advocates = result.scalars().all()

        for advocate in advocates:
            try:
                cases_result = await db.execute(
                    select(Case).where(
                        Case.advocate_id == advocate.id,
                        Case.is_deleted == False,
                        Case.status != "CLOSED",
                    )
                )
                active_cases = cases_result.scalars().all()

                hearings_result = await db.execute(
                    select(Hearing)
                    .options(selectinload(Hearing.case))
                    .where(
                        Hearing.hearing_date == tomorrow,
                        Hearing.status == HearingStatus.SCHEDULED,
                    )
                )
                tomorrow_hearings = [
                    h for h in hearings_result.scalars().all()
                    if h.case.advocate_id == advocate.id
                ]

                if not active_cases and not tomorrow_hearings:
                    continue

                html_lines = [
                    "<h2>Daily Digest — Legal CMS</h2>",
                    f"<p>Good morning, <strong>{advocate.full_name}</strong></p>",
                    f"<h3>Active Cases ({len(active_cases)})</h3><ul>",
                ]
                for c in active_cases[:10]:
                    html_lines.append(
                        f"<li>{c.case_number} — {c.title} "
                        f"<em>({c.status.value if hasattr(c.status, 'value') else c.status})</em></li>"
                    )
                if len(active_cases) > 10:
                    html_lines.append(f"<li>... and {len(active_cases) - 10} more</li>")
                html_lines.append("</ul>")

                html_lines.append(f"<h3>Tomorrow's Hearings ({len(tomorrow_hearings)})</h3><ul>")
                for h in tomorrow_hearings:
                    html_lines.append(
                        f"<li>{h.case.case_number} — {h.purpose or 'Hearing'} "
                        f"at {h.hearing_time.strftime('%I:%M %p') if h.hearing_time else '—'}</li>"
                    )
                html_lines.append("</ul>")
                html_lines.append(
                    '<p style="color: #888; font-size: 12px;">'
                    "Sent automatically by Legal CMS</p>"
                )

                send_email(
                    to=advocate.email,
                    subject=f"Daily Digest — {today.strftime('%b %d, %Y')}",
                    html="\n".join(html_lines),
                )
            except Exception as e:
                logger.error("Digest failed for user %d: %s", advocate.id, e)

        await db.commit()


def start_scheduler():
    if scheduler.running:
        return
    scheduler.add_job(
        check_upcoming_hearings,
        "interval",
        hours=1,
        id="check_upcoming_hearings",
        replace_existing=True,
    )
    scheduler.add_job(
        daily_digest,
        "cron",
        hour=8,
        minute=0,
        id="daily_digest",
        replace_existing=True,
    )
    scheduler.start()
    logger.info("Scheduler started with %d jobs", len(scheduler.get_jobs()))


def stop_scheduler():
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("Scheduler stopped")
