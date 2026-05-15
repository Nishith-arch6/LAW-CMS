from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user, get_db
from app.models.case import Case
from app.models.hearing import Hearing
from app.models.user import User

router = APIRouter()


@router.get("/case/{case_id}/pdf")
async def export_case_pdf(
    case_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Case)
        .options(
            selectinload(Case.client),
            selectinload(Case.hearings),
            selectinload(Case.documents),
            selectinload(Case.notes),
        )
        .where(Case.id == case_id, Case.advocate_id == current_user.id, Case.is_deleted == False)
    )
    case = result.scalar_one_or_none()
    if not case:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Case not found")

    lines = []
    lines.append("=" * 60)
    lines.append(f"  CASE SUMMARY — {case.case_number}")
    lines.append("=" * 60)
    lines.append("")
    lines.append(f"Title:            {case.title}")
    lines.append(f"Type:             {case.case_type.value if case.case_type else 'N/A'}")
    lines.append(f"Status:           {case.status.value if case.status else 'N/A'}")
    lines.append(f"Court:            {case.court_name or 'N/A'}")
    lines.append(f"Judge:            {case.judge_name or 'N/A'}")
    lines.append("")
    lines.append("--- Parties ---")
    lines.append(f"Client:           {case.client.name if case.client else 'N/A'}")
    lines.append(f"Opposing Party:   {case.opposing_party or 'N/A'}")
    lines.append(f"Defending Party:  {case.defending_party or 'N/A'}")
    lines.append("")
    lines.append("--- Hearings ---")
    if case.hearings:
        for h in sorted(case.hearings, key=lambda x: x.hearing_date):
            lines.append(f"  {h.hearing_date}  {h.purpose or 'N/A'}  [{h.status.value}]")
    else:
        lines.append("  (none)")
    lines.append("")
    lines.append("--- Documents ---")
    if case.documents:
        for d in case.documents:
            size = d.file_size or 0
            lines.append(f"  {d.file_name}  ({size//1024} KB)")
    else:
        lines.append("  (none)")
    lines.append("")
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    lines.append(f"Generated: {ts}")
    lines.append("=" * 60)

    content = "\n".join(lines)
    filename = f"case_{case.case_number.replace('/', '_')}.txt"
    return Response(
        content=content,
        media_type="text/plain",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/hearings/export")
async def export_hearings_ics(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Hearing)
        .options(selectinload(Hearing.case))
        .where(Hearing.case.has(advocate_id=current_user.id))
        .order_by(Hearing.hearing_date)
    )
    hearings = result.scalars().all()

    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//Legal CMS//EN",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
    ]

    for h in hearings:
        dtstart = h.hearing_date.strftime("%Y%m%d")
        if h.hearing_time:
            dtstart = f"{dtstart}T{h.hearing_time.strftime('%H%M%S')}"
        else:
            dtstart = f"{dtstart}T000000"

        case_num = h.case.case_number if h.case else "N/A"
        summary = f"Hearing: {h.purpose or 'Hearing'} - {case_num}"
        desc = f"Case: {case_num}\\nCourt Room: {h.court_room or 'N/A'}\\nNotes: {h.notes or ''}"

        lines.extend([
            "BEGIN:VEVENT",
            f"UID:{h.id}@legalcms",
            f"DTSTART:{dtstart}",
            f"SUMMARY:{summary}",
            f"DESCRIPTION:{desc}",
            "END:VEVENT",
        ])

    lines.append("END:VCALENDAR")
    content = "\r\n".join(lines)

    return Response(
        content=content,
        media_type="text/calendar",
        headers={"Content-Disposition": "attachment; filename=\"hearings.ics\""},
    )
