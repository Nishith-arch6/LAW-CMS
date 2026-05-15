import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.models.hearing import Hearing
from app.models.notification import Notification, NotificationType
from app.models.user import User

logger = logging.getLogger("legal_cms.notifications")


def send_email(to: str, subject: str, html: str) -> bool:
    if not settings.smtp_host:
        logger.warning("SMTP not configured — skipping email to %s", to)
        return False
    try:
        msg = MIMEMultipart("alternative")
        msg["From"] = settings.smtp_from
        msg["To"] = to
        msg["Subject"] = subject
        msg.attach(MIMEText(html, "html"))

        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as server:
            if settings.smtp_tls:
                server.starttls()
            if settings.smtp_user:
                server.login(settings.smtp_user, settings.smtp_password)
            server.send_message(msg)
        logger.info("Email sent to %s: %s", to, subject)
        return True
    except Exception as e:
        logger.error("Failed to send email to %s: %s", to, e)
        return False


def _advocate_color(status: str) -> str:
    return {"ACTIVE": "#27ae60", "CLOSED": "#e74c3c", "PENDING": "#f39c12", "ADJOURNED": "#8e44ad"}.get(status, "#333")


def format_hearing_reminder(
    hearing: Hearing,
    advocate: User,
    client_name: str | None,
) -> str:
    from app.utils.email_templates import HEARING_REMINDER_HTML

    time_str = hearing.hearing_time.strftime("%I:%M %p") if hearing.hearing_time else "—"
    return HEARING_REMINDER_HTML.safe_substitute(
        advocate_name=advocate.full_name,
        case_number=hearing.case.case_number,
        case_title=hearing.case.title,
        hearing_date=hearing.hearing_date.strftime("%A, %B %d, %Y"),
        hearing_time=time_str,
        court_room=hearing.court_room or "—",
        purpose=hearing.purpose or "—",
        client_name=client_name or "—",
    )


def format_case_update(
    advocate: User,
    case,
    client_name: str | None,
) -> str:
    from app.utils.email_templates import CASE_UPDATE_HTML

    return CASE_UPDATE_HTML.safe_substitute(
        advocate_name=advocate.full_name,
        case_number=case.case_number,
        case_title=case.title,
        status=case.status.value if hasattr(case.status, "value") else str(case.status),
        status_color=_advocate_color(case.status.value if hasattr(case.status, "value") else str(case.status)),
        client_name=client_name or "—",
        extra_info="",
    )


def format_welcome_email(user: User) -> str:
    from app.utils.email_templates import WELCOME_HTML

    return WELCOME_HTML.safe_substitute(
        full_name=user.full_name,
        email=user.email,
        bar_number=user.bar_number,
    )


async def send_hearing_reminder(
    hearing: Hearing,
    advocate: User,
    client_name: str | None,
    db: AsyncSession,
) -> bool:
    html = format_hearing_reminder(hearing, advocate, client_name)
    subject = f"Hearing Reminder: {hearing.case.case_number} — {hearing.hearing_date}"
    success = send_email(advocate.email, subject, html)

    notif = Notification(
        user_id=advocate.id,
        hearing_id=hearing.id,
        type=NotificationType.HEARING_REMINDER,
        title=subject,
        message=html[:500],
        read=False,
    )
    db.add(notif)

    if success:
        hearing.reminder_sent = True

    await db.flush()
    return success


async def send_welcome_email(user: User, db: AsyncSession) -> bool:
    html = format_welcome_email(user)
    subject = "Welcome to Legal CMS"
    success = send_email(user.email, subject, html)

    notif = Notification(
        user_id=user.id,
        type=NotificationType.WELCOME,
        title=subject,
        message=html[:500],
        read=False,
    )
    db.add(notif)
    await db.flush()
    return success


async def send_case_update_notification(
    advocate: User,
    case,
    client_name: str | None,
    db: AsyncSession,
) -> bool:
    html = format_case_update(advocate, case, client_name)
    subject = f"Case Update: {case.case_number} — {case.status.value if hasattr(case.status, 'value') else case.status}"
    success = send_email(advocate.email, subject, html)

    notif = Notification(
        user_id=advocate.id,
        type=NotificationType.CASE_UPDATE,
        title=subject,
        message=html[:500],
        read=False,
    )
    db.add(notif)
    await db.flush()
    return success


async def mark_reminder_sent(hearing_id: int, db: AsyncSession) -> None:
    result = await db.execute(select(Hearing).where(Hearing.id == hearing_id))
    hearing = result.scalar_one_or_none()
    if hearing:
        hearing.reminder_sent = True
        await db.flush()
