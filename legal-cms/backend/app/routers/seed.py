from datetime import date, datetime, time, timedelta, timezone

from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.security import hash_password
from app.models.case import Case, CaseStatus, CaseType
from app.models.case_note import CaseNote
from app.models.client import Client
from app.models.document import Document
from app.models.hearing import Hearing, HearingStatus
from app.models.notification import Notification, NotificationType
from app.models.user import User

router = APIRouter()

TEST_CREDENTIALS = {"email": "advocate.sharma@legalcms.com", "password": "advocate123"}
SAMPLE_DOC_TEXT = (
    "This document pertains to the aforementioned legal matter. "
    "The parties involved have been duly notified and all relevant evidence has been submitted. "
    "The court is requested to take the necessary action as per the provisions of the law."
)

today = date.today()


def dt(y: int, m: int, d: int) -> datetime:
    return datetime(y, m, d, tzinfo=timezone.utc)


@router.post("/seed", status_code=status.HTTP_201_CREATED)
async def seed_all(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == TEST_CREDENTIALS["email"]))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            full_name="Advocate Rahul Sharma",
            email=TEST_CREDENTIALS["email"],
            hashed_password=hash_password(TEST_CREDENTIALS["password"]),
            bar_number="BAR001",
            phone="+1234567890",
            is_active=True,
        )
        db.add(user)
        await db.flush()
        await db.refresh(user)

    uid = user.id

    clients_data = [
        {"name": "Rajesh Sharma", "email": "rajesh@example.com", "phone": "+919876543210", "address": "12, MG Road, Mumbai, Maharashtra 400001"},
        {"name": "Priya Patel", "email": "priya@example.com", "phone": "+919876543211", "address": "45, Brigade Road, Bengaluru, Karnataka 560001"},
        {"name": "Amit Singh", "email": "amit@example.com", "phone": "+919876543212", "address": "78, Park Street, Kolkata, West Bengal 700001"},
        {"name": "Sunita Verma", "email": "sunita@example.com", "phone": "+919876543213", "address": "23, Connaught Place, New Delhi 110001"},
        {"name": "Vikram Joshi", "email": "vikram@example.com", "phone": "+919876543214", "address": "56, FC Road, Pune, Maharashtra 411004"},
        {"name": "Ananya Gupta", "email": "ananya@example.com", "phone": "+919876543215", "address": "90, Jubilee Hills, Hyderabad, Telangana 500033"},
        {"name": "Meera Nair", "email": "meera@example.com", "phone": "+919876543216", "address": "34, Marine Drive, Kochi, Kerala 682001"},
        {"name": "Arun Khanna", "email": "arun@example.com", "phone": "+919876543217", "address": "67, CP Colony, Lucknow, Uttar Pradesh 226001"},
        {"name": "Deepa Iyer", "email": "deepa@example.com", "phone": "+919876543218", "address": "21, Nungambakkam, Chennai, Tamil Nadu 600034"},
        {"name": "Rohit Deshmukh", "email": "rohit@example.com", "phone": "+919876543219", "address": "88, Koregaon Park, Pune, Maharashtra 411001"},
        {"name": "Kavita Menon", "email": "kavita@example.com", "phone": "+919876543220", "address": "5, Panjim, Goa 403001"},
        {"name": "Suresh Reddy", "email": "suresh@example.com", "phone": "+919876543221", "address": "42, Banjara Hills, Hyderabad, Telangana 500034"},
    ]

    clients = []
    for cd in clients_data:
        r = await db.execute(select(Client).where(Client.email == cd["email"]).where(Client.advocate_id == uid))
        c = r.scalar_one_or_none()
        if not c:
            c = Client(advocate_id=uid, **cd)
            db.add(c)
            await db.flush()
            await db.refresh(c)
        clients.append(c)

    now = datetime.now(timezone.utc)

    cases_data = [
        {"case_number": "CIV-2024-001", "title": "Property Dispute — Sharma vs. Municipal Corporation", "description": "Dispute regarding illegal demolition of residential property located at Andheri West.", "case_type": CaseType.CIVIL, "status": CaseStatus.ACTIVE, "court_name": "Mumbai Civil Court", "court_building": "Central Court Complex", "court_floor": "3rd Floor, Room 305", "judge_name": "Hon'ble Judge S. Patil", "client_idx": 0, "opposing_party": "Municipal Corporation of Greater Mumbai", "defending_party": "Mr. Rajesh Sharma", "created_at": dt(2024, 3, 15)},
        {"case_number": "CRIM-2024-002", "title": "State vs. Amit Singh — Fraud Allegation", "description": "Allegations of financial fraud involving shell companies and money laundering.", "case_type": CaseType.CRIMINAL, "status": CaseStatus.ACTIVE, "court_name": "Sessions Court, Tis Hazari", "court_building": "Tis Hazari Courts Complex", "court_floor": "5th Floor, Court 12", "judge_name": "Hon'ble Judge A. Mehta", "client_idx": 2, "opposing_party": "State of Delhi", "defending_party": "Mr. Amit Singh", "created_at": dt(2024, 6, 20)},
        {"case_number": "FAM-2024-003", "title": "Patel Divorce Proceedings", "description": "Mutual consent divorce petition with child custody and alimony considerations.", "case_type": CaseType.FAMILY, "status": CaseStatus.PENDING, "court_name": "Family Court, Bengaluru", "court_building": "Family Court Building", "court_floor": "2nd Floor, Chamber 7", "judge_name": "Hon'ble Judge L. Krishnan", "client_idx": 1, "opposing_party": "Mr. Rohan Patel", "defending_party": "Ms. Priya Patel", "created_at": dt(2024, 9, 5)},
        {"case_number": "CORP-2024-004", "title": "Verma Enterprises vs. Tax Department", "description": "Appeal against income tax reassessment order for the financial year 2022-23.", "case_type": CaseType.CORPORATE, "status": CaseStatus.ACTIVE, "court_name": "Income Tax Appellate Tribunal", "court_building": "ITAT Building", "court_floor": "4th Floor, Bench B", "judge_name": "Hon'ble Member R. Kapoor", "client_idx": 3, "opposing_party": "Income Tax Department", "defending_party": "Verma Enterprises Pvt. Ltd.", "created_at": dt(2024, 1, 10)},
        {"case_number": "CIV-2025-005", "title": "Joshi vs. Insurance Company — Claim Settlement", "description": "Insurance claim dispute for medical insurance coverage denial.", "case_type": CaseType.CIVIL, "status": CaseStatus.ACTIVE, "court_name": "Consumer Disputes Redressal Commission", "court_building": "Consumer Court Building", "court_floor": "1st Floor, Court 3", "judge_name": "Hon'ble Judge M. Deshmukh", "client_idx": 4, "opposing_party": "National Insurance Co. Ltd.", "defending_party": "Mr. Vikram Joshi", "created_at": dt(2025, 2, 1)},
        {"case_number": "CIV-2025-006", "title": "Gupta vs. Builder — Flat Possession Delay", "description": "Delay in possession of residential flat beyond the agreed timeline of 36 months.", "case_type": CaseType.CIVIL, "status": CaseStatus.PENDING, "court_name": "RERA Tribunal, Hyderabad", "court_building": "RERA Office Complex", "court_floor": "Ground Floor, Tribunal 1", "judge_name": "Hon'ble Chairperson K. Rao", "client_idx": 5, "opposing_party": "Green Valley Builders", "defending_party": "Ms. Ananya Gupta", "created_at": dt(2025, 4, 18)},
        {"case_number": "CRIM-2025-007", "title": "Cyber Crime Investigation — Sharma Complaint", "description": "Investigation into phishing attack and unauthorized bank transactions of Rs. 12.5 lakhs.", "case_type": CaseType.CRIMINAL, "status": CaseStatus.PENDING, "court_name": "Cyber Crime Court", "court_building": "Justice City Complex", "court_floor": "6th Floor, Cyber Cell", "judge_name": "Hon'ble Judge N. Iyer", "client_idx": 0, "opposing_party": "State of Maharashtra", "defending_party": "Mr. Rajesh Sharma (Victim)", "created_at": dt(2025, 5, 10)},
        {"case_number": "FAM-2025-008", "title": "Singh Child Custody Case", "description": "Child custody dispute between separated parents regarding two minor children.", "case_type": CaseType.FAMILY, "status": CaseStatus.ACTIVE, "court_name": "Family Court, Kolkata", "court_building": "City Civil Court", "court_floor": "3rd Floor, Family Bench", "judge_name": "Hon'ble Judge S. Banerjee", "client_idx": 2, "opposing_party": "Ms. Neha Singh", "defending_party": "Mr. Amit Singh", "created_at": dt(2025, 1, 22)},
        {"case_number": "CORP-2025-009", "title": "Nair Enterprises Merger Approval", "description": "Application for court approval of merger between two private limited companies.", "case_type": CaseType.CORPORATE, "status": CaseStatus.ACTIVE, "court_name": "High Court, Kerala", "court_building": "High Court Building", "court_floor": "2nd Floor, Company Bench", "judge_name": "Hon'ble Justice K. George", "client_idx": 6, "opposing_party": "Registrar of Companies", "defending_party": "Nair Enterprises Pvt. Ltd.", "created_at": dt(2025, 8, 14)},
        {"case_number": "CIV-2025-010", "title": "Khanna vs. Neighbors — Easement Rights", "description": "Dispute over right of way and easement through neighboring property.", "case_type": CaseType.CIVIL, "status": CaseStatus.ACTIVE, "court_name": "Civil Judge Court, Lucknow", "court_building": "District Court Complex", "court_floor": "1st Floor, Civil Court 2", "judge_name": "Hon'ble Judge R. Tiwari", "client_idx": 7, "opposing_party": "Mr. S. Verma & Mrs. Verma", "defending_party": "Mr. Arun Khanna", "created_at": dt(2025, 10, 5)},
        {"case_number": "CIV-2024-011", "title": "Iyer vs. Hospital — Medical Negligence", "description": "Medical negligence case regarding improper post-surgery care leading to complications.", "case_type": CaseType.CIVIL, "status": CaseStatus.CLOSED, "court_name": "District Consumer Forum", "court_building": "Consumer Court", "court_floor": "3rd Floor, Court 1", "judge_name": "Hon'ble President S. Rao", "client_idx": 8, "opposing_party": "City Hospital & Research Centre", "defending_party": "Ms. Deepa Iyer", "created_at": dt(2024, 11, 20)},
        {"case_number": "FAM-2025-012", "title": "Deshmukh Maintenance Petition", "description": "Petition for spousal maintenance under Section 125 of CrPC.", "case_type": CaseType.FAMILY, "status": CaseStatus.ACTIVE, "court_name": "Family Court, Pune", "court_building": "Pune Court Complex", "court_floor": "2nd Floor, Court 4", "judge_name": "Hon'ble Judge A. Kulkarni", "client_idx": 9, "opposing_party": "Mrs. Sneha Deshmukh", "defending_party": "Mr. Rohit Deshmukh", "created_at": dt(2025, 6, 30)},
        {"case_number": "OTHER-2025-013", "title": "Menon Trust Registration", "description": "Registration of a charitable trust for educational purposes.", "case_type": CaseType.OTHER, "status": CaseStatus.CLOSED, "court_name": "Office of Charity Commissioner", "court_building": "Charity Building", "court_floor": "Ground Floor", "judge_name": "Charity Commissioner", "client_idx": 10, "opposing_party": "N/A", "defending_party": "Ms. Kavita Menon (Trustee)", "created_at": dt(2025, 3, 12)},
        {"case_number": "CORP-2026-014", "title": "Reddy Constructions — Contract Dispute", "description": "Breach of construction contract regarding commercial complex development.", "case_type": CaseType.CORPORATE, "status": CaseStatus.ACTIVE, "court_name": "Commercial Court", "court_building": "Commercial Court Complex", "court_floor": "4th Floor, Court 2", "judge_name": "Hon'ble Judge P. Reddy", "client_idx": 11, "opposing_party": "Skyline Developers", "defending_party": "Reddy Constructions Pvt. Ltd.", "created_at": dt(2026, 1, 8)},
        {"case_number": "CRIM-2026-015", "title": "State vs. Unknown — Hit & Run", "description": "Investigation into a hit-and-run accident causing grievous injury.", "case_type": CaseType.CRIMINAL, "status": CaseStatus.PENDING, "court_name": "Magistrate Court", "court_building": "City Civil Court", "court_floor": "1st Floor, Magistrate 3", "judge_name": "Hon'ble Magistrate S. Joshi", "client_idx": 4, "opposing_party": "State of Maharashtra", "defending_party": "Mr. Vikram Joshi (Complainant)", "created_at": dt(2026, 2, 20)},
    ]

    cases = []
    for cd in cases_data:
        r = await db.execute(select(Case).where(Case.case_number == cd["case_number"]))
        c = r.scalar_one_or_none()
        if not c:
            c = Case(
                client_id=clients[cd["client_idx"]].id,
                advocate_id=uid,
                case_number=cd["case_number"],
                title=cd["title"],
                description=cd["description"],
                case_type=cd["case_type"],
                status=cd["status"],
                court_name=cd["court_name"],
                court_building=cd["court_building"],
                court_floor=cd["court_floor"],
                judge_name=cd["judge_name"],
                opposing_party=cd["opposing_party"],
                defending_party=cd["defending_party"],
                filing_date=cd["created_at"],
                created_at=cd["created_at"],
            )
            db.add(c)
            await db.flush()
            await db.refresh(c)
        cases.append(c)

    hearings_data = [
        # Case 0 - Property Dispute
        {"case_idx": 0, "hearing_date": today, "hearing_time": time(10, 30), "court_room": "Room 305", "purpose": "Final arguments", "status": HearingStatus.SCHEDULED},
        {"case_idx": 0, "hearing_date": today - timedelta(days=30), "hearing_time": time(11, 0), "court_room": "Room 305", "purpose": "Evidence submission", "status": HearingStatus.COMPLETED},
        {"case_idx": 0, "hearing_date": today - timedelta(days=60), "hearing_time": time(10, 0), "court_room": "Room 305", "purpose": "First hearing", "status": HearingStatus.COMPLETED},
        # Case 1 - Fraud
        {"case_idx": 1, "hearing_date": today + timedelta(days=2), "hearing_time": time(14, 0), "court_room": "Court 12", "purpose": "Cross-examination of witness", "status": HearingStatus.SCHEDULED},
        {"case_idx": 1, "hearing_date": today - timedelta(days=15), "hearing_time": time(14, 0), "court_room": "Court 12", "purpose": "Framing of charges", "status": HearingStatus.COMPLETED},
        {"case_idx": 1, "hearing_date": today - timedelta(days=45), "hearing_time": time(14, 0), "court_room": "Court 12", "purpose": "Production of documents", "status": HearingStatus.COMPLETED},
        # Case 2 - Divorce
        {"case_idx": 2, "hearing_date": today + timedelta(days=5), "hearing_time": time(9, 30), "court_room": "Chamber 7", "purpose": "Mediation session", "status": HearingStatus.SCHEDULED},
        {"case_idx": 2, "hearing_date": today - timedelta(days=10), "hearing_time": time(9, 30), "court_room": "Chamber 7", "purpose": "Initial mediation", "status": HearingStatus.COMPLETED},
        # Case 3 - Tax Appeal
        {"case_idx": 3, "hearing_date": today + timedelta(days=3), "hearing_time": time(10, 0), "court_room": "Bench B", "purpose": "Hearing on stay petition", "status": HearingStatus.SCHEDULED},
        {"case_idx": 3, "hearing_date": today - timedelta(days=20), "hearing_time": time(10, 0), "court_room": "Bench B", "purpose": "Preliminary hearing", "status": HearingStatus.COMPLETED},
        # Case 4 - Insurance Claim
        {"case_idx": 4, "hearing_date": today + timedelta(days=1), "hearing_time": time(15, 0), "court_room": "Court 3", "purpose": "Arguments on admissibility", "status": HearingStatus.SCHEDULED},
        {"case_idx": 4, "hearing_date": today - timedelta(days=7), "hearing_time": time(15, 0), "court_room": "Court 3", "purpose": "Evidence submission", "status": HearingStatus.COMPLETED},
        # Case 5 - RERA
        {"case_idx": 5, "hearing_date": today + timedelta(days=6), "hearing_time": time(11, 30), "court_room": "Tribunal 1", "purpose": "Initial hearing", "status": HearingStatus.SCHEDULED},
        # Case 7 - Child Custody
        {"case_idx": 7, "hearing_date": today + timedelta(days=4), "hearing_time": time(9, 0), "court_room": "Family Bench", "purpose": "Custody hearing", "status": HearingStatus.SCHEDULED},
        {"case_idx": 7, "hearing_date": today - timedelta(days=30), "hearing_time": time(9, 0), "court_room": "Family Bench", "purpose": "Interim order hearing", "status": HearingStatus.COMPLETED},
        # Case 9 - Merger
        {"case_idx": 8, "hearing_date": today + timedelta(days=12), "hearing_time": time(10, 30), "court_room": "Company Bench", "purpose": "Petition admission", "status": HearingStatus.SCHEDULED},
        # Case 10 - Easement
        {"case_idx": 9, "hearing_date": today + timedelta(days=8), "hearing_time": time(11, 0), "court_room": "Civil Court 2", "purpose": "Site inspection order", "status": HearingStatus.SCHEDULED},
        # Case 11 - Medical Negligence (CLOSED case, completed hearings)
        {"case_idx": 10, "hearing_date": today - timedelta(days=90), "hearing_time": time(10, 0), "court_room": "Court 1", "purpose": "Final judgment", "status": HearingStatus.COMPLETED},
        {"case_idx": 10, "hearing_date": today - timedelta(days=120), "hearing_time": time(10, 0), "court_room": "Court 1", "purpose": "Final arguments", "status": HearingStatus.COMPLETED},
        # Case 12 - Maintenance
        {"case_idx": 11, "hearing_date": today + timedelta(days=15), "hearing_time": time(9, 30), "court_room": "Court 4", "purpose": "Maintenance quantum hearing", "status": HearingStatus.SCHEDULED},
        # Case 14 - Contract Dispute
        {"case_idx": 13, "hearing_date": today + timedelta(days=10), "hearing_time": time(14, 30), "court_room": "Court 2", "purpose": "Case management conference", "status": HearingStatus.SCHEDULED},
        # Case 15 - Hit & Run
        {"case_idx": 14, "hearing_date": today + timedelta(days=20), "hearing_time": time(11, 0), "court_room": "Magistrate 3", "purpose": "Investigation report review", "status": HearingStatus.SCHEDULED},
    ]

    hearings = []
    for hd in hearings_data:
        c = cases[hd["case_idx"]]
        r = await db.execute(
            select(Hearing).where(Hearing.case_id == c.id).where(Hearing.hearing_date == hd["hearing_date"])
        )
        h = r.scalar_one_or_none()
        if not h:
            h = Hearing(
                case_id=c.id,
                hearing_date=hd["hearing_date"],
                hearing_time=hd["hearing_time"],
                court_room=hd["court_room"],
                purpose=hd["purpose"],
                status=hd["status"],
            )
            db.add(h)
            await db.flush()
            await db.refresh(h)
        hearings.append(h)

    notes_data = [
        {"case_idx": 0, "content": "Client confirmed all property documents are in order. Next step is to file an affidavit."},
        {"case_idx": 0, "content": "Received notice from Municipal Corporation — they are seeking an out-of-court settlement."},
        {"case_idx": 0, "content": "Drafting final submissions. Key precedent: Supreme Court ruling on eminent domain."},
        {"case_idx": 1, "content": "Forensic audit report received. Key findings indicate irregularities in the balance sheet."},
        {"case_idx": 1, "content": "Witness list finalized. 5 witnesses to be examined including the forensic auditor."},
        {"case_idx": 2, "content": "Client is agreeable to mediation. Both parties showing willingness to settle."},
        {"case_idx": 2, "content": "Mediation session scheduled. Children's welfare is the primary concern."},
        {"case_idx": 3, "content": "Tax department has filed a counter-affidavit. Need to prepare rejoinder by next week."},
        {"case_idx": 3, "content": "Strong grounds for appeal — assessment order lacks proper reasoning on key issues."},
        {"case_idx": 4, "content": "Medical reports and insurance policy documents compiled and submitted to court."},
        {"case_idx": 4, "content": "Insurance company offered Rs. 3.5 lakhs as settlement. Client considering."},
        {"case_idx": 5, "content": "Builder has proposed a new possession timeline. Client wants to negotiate compensation."},
        {"case_idx": 5, "content": "RERA registration number verified. Project is registered under RERA."},
        {"case_idx": 8, "content": "Board resolution for merger approved by both companies. Filing petition next week."},
        {"case_idx": 9, "content": "Site inspection conducted. Neighbor's construction violates the set-back rule."},
        {"case_idx": 10, "content": "Case settled in favor of client. Total compensation awarded: Rs. 8,50,000."},
        {"case_idx": 11, "content": "Client's income documents submitted. Seeking maintenance of Rs. 25,000 per month."},
        {"case_idx": 13, "content": "Contract documents reviewed. Breach is clear — delay of 14 months beyond timeline."},
        {"case_idx": 14, "content": "CCTV footage obtained from the traffic department. Vehicle number partially visible."},
    ]

    for nd in notes_data:
        c = cases[nd["case_idx"]]
        r = await db.execute(
            select(CaseNote).where(CaseNote.case_id == c.id).where(CaseNote.content == nd["content"])
        )
        if not r.scalar_one_or_none():
            note = CaseNote(case_id=c.id, author_id=uid, content=nd["content"])
            db.add(note)

    docs_data = [
        {"case_idx": 0, "file_name": "property_deed.pdf", "file_type": "application/pdf", "description": "Original property deed and sale agreement dated 2012"},
        {"case_idx": 0, "file_name": "demolition_photos.zip", "file_type": "application/zip", "description": "Site photographs taken after the demolition"},
        {"case_idx": 0, "file_name": "notice_to_municipal.pdf", "file_type": "application/pdf", "description": "Legal notice served to Municipal Corporation"},
        {"case_idx": 1, "file_name": "forensic_audit_report.pdf", "file_type": "application/pdf", "description": "Forensic audit report by KPMG — 45 pages"},
        {"case_idx": 1, "file_name": "bank_statements.pdf", "file_type": "application/pdf", "description": "Bank statements of the accused for FY 2022-24"},
        {"case_idx": 2, "file_name": "marriage_certificate.pdf", "file_type": "application/pdf", "description": "Marriage certificate and wedding photographs"},
        {"case_idx": 3, "file_name": "tax_assessment_order.pdf", "file_type": "application/pdf", "description": "Income tax reassessment order for FY 2022-23"},
        {"case_idx": 3, "file_name": "appeal_memo.pdf", "file_type": "application/pdf", "description": "Memorandum of appeal filed before ITAT"},
        {"case_idx": 4, "file_name": "insurance_policy.pdf", "file_type": "application/pdf", "description": "Medical insurance policy document with terms"},
        {"case_idx": 4, "file_name": "claim_rejection_letter.pdf", "file_type": "application/pdf", "description": "Insurance company's claim rejection letter"},
        {"case_idx": 5, "file_name": "sale_agreement.pdf", "file_type": "application/pdf", "description": "Flat sale agreement and payment receipts"},
        {"case_idx": 5, "file_name": "rera_certificate.pdf", "file_type": "application/pdf", "description": "RERA registration certificate of the project"},
        {"case_idx": 8, "file_name": "merger_agreement_draft.pdf", "file_type": "application/pdf", "description": "Draft merger agreement between the two companies"},
        {"case_idx": 10, "file_name": "judgment_order.pdf", "file_type": "application/pdf", "description": "Final judgment order from Consumer Forum"},
        {"case_idx": 13, "file_name": "construction_contract.pdf", "file_type": "application/pdf", "description": "Signed construction contract with all schedules"},
    ]

    for dd in docs_data:
        c = cases[dd["case_idx"]]
        r = await db.execute(
            select(Document).where(Document.case_id == c.id).where(Document.file_name == dd["file_name"])
        )
        if not r.scalar_one_or_none():
            doc = Document(
                case_id=c.id,
                file_name=dd["file_name"],
                file_path=f"/uploads/{dd['file_name']}",
                file_type=dd["file_type"],
                file_size=len(SAMPLE_DOC_TEXT) * 10,
                description=dd["description"],
                ocr_text=SAMPLE_DOC_TEXT,
                uploaded_by=uid,
            )
            db.add(doc)

    notif_data = [
        {"type": NotificationType.WELCOME, "title": "Welcome to Legal CMS", "message": "Your account has been created. Start managing your practice efficiently."},
        {"type": NotificationType.CASE_UPDATE, "title": "New Case Assigned", "message": "Property Dispute — Sharma vs. Municipal Corporation has been assigned to you."},
        {"type": NotificationType.HEARING_REMINDER, "title": "Hearing Tomorrow", "message": "Joshi vs. Insurance Company has a hearing tomorrow at 3:00 PM in Court 3."},
        {"type": NotificationType.HEARING_REMINDER, "title": "Upcoming Hearing in 2 Days", "message": "State vs. Amit Singh — cross-examination hearing on at 2:00 PM in Court 12."},
        {"type": NotificationType.CASE_UPDATE, "title": "Case Closed", "message": "Iyer vs. Hospital (Medical Negligence) has been marked as CLOSED — decided in favor of client."},
        {"type": NotificationType.HEARING_REMINDER, "title": "Weekly Hearing Summary", "message": "You have 6 hearings scheduled this week across 5 cases."},
    ]

    for nd in notif_data:
        r = await db.execute(
            select(Notification).where(Notification.user_id == uid).where(Notification.title == nd["title"])
        )
        if not r.scalar_one_or_none():
            notif = Notification(user_id=uid, type=nd["type"], title=nd["title"], message=nd["message"])
            db.add(notif)

    await db.commit()

    return {
        "message": "Sample data created",
        "credentials": TEST_CREDENTIALS,
        "summary": {
            "clients": len(clients),
            "cases": len(cases),
            "hearings": len(hearings),
            "notes": len(notes_data),
            "documents": len(docs_data),
            "notifications": len(notif_data),
        },
    }
