"""Helper to generate test legal text data for ML/document tests."""

import random


def _lorem_words(n: int = 20) -> str:
    words = [
        "lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing",
        "elit", "sed", "do", "eiusmod", "tempor", "incididunt", "ut", "labore",
        "et", "dolore", "magna", "aliqua", "ut", "enim", "ad", "minim", "veniam",
    ]
    return " ".join(random.choices(words, k=n))


def legal_case_text() -> str:
    return (
        "IN THE SUPREME COURT OF CONFIDENCE\n\n"
        "Case No. CIVIL-2026-0420\n\n"
        "Plaintiff: John Alexander Smith\n"
        "Defendant: Jane Elizabeth Doe\n"
        "Advocate: Sarah Johnson\n"
        "Advocate: Michael Brown\n\n"
        "FILING DATE: March 15, 2026\n"
        "HEARING DATE: May 20, 2026\n"
        "DEADLINE for response: June 10, 2026\n\n"
        "This is a civil matter regarding a breach of contract "
        "between the plaintiff and the defendant. The plaintiff alleges that "
        "the defendant failed to fulfill the terms of the agreement dated "
        "January 5, 2025. The plaintiff seeks damages in the amount of "
        "$500,000 plus legal costs. The defendant has filed a counterclaim "
        "denying all allegations. A preliminary hearing has been scheduled "
        "for May 20, 2026 at 10:00 AM in Court Room 302. Both parties have "
        "been notified of the hearing date and are required to appear. "
        "The court has ordered mediation before the next hearing date. "
    )


def legal_document_text() -> str:
    return (
        "CONTRACT OF SALE\n\n"
        "This agreement is made on 12/02/2026 between:\n"
        "1. ABC Corporation, having its registered office at 123 Business "
        "Park, New York (hereinafter referred to as the 'Seller')\n"
        "2. XYZ Limited, having its registered office at 456 Commerce "
        "Street, Chicago (hereinafter referred to as the 'Buyer')\n\n"
        "Advocate for Seller: Robert Williams\n"
        "Advocate for Buyer: Emily Davis\n\n"
        "WHEREAS the Seller agrees to sell and the Buyer agrees to purchase "
        "the property described in Schedule A attached hereto.\n\n"
        "The total consideration for the sale is $2,000,000 (Two Million "
        "Dollars) payable in installments as follows:\n"
        "- First installment of $500,000 due on 15/03/2026\n"
        "- Second installment of $750,000 due on 15/06/2026\n"
        "- Final installment of $750,000 due on 15/09/2026\n\n"
        "This contract shall be governed by the laws of the State of New York. "
        "Any dispute arising out of this contract shall be subject to the "
        "exclusive jurisdiction of the courts of New York.\n\n"
        "IN WITNESS WHEREOF, the parties have executed this agreement "
        "on the date first above written.\n\n"
        "_____________________\n"
        "For ABC Corporation\n\n"
        "_____________________\n"
        "For XYZ Limited\n"
    )


def case_titles() -> list[str]:
    return [
        "Smith vs. Jones — Breach of Contract",
        "Estate of Williams — Probate Matter",
        "State vs. Anderson — Criminal Appeal",
        "Johnson Divorce Proceeding",
        "ABC Corp vs. DEF Ltd — Patent Infringement",
        "Child Custody Dispute — Miller vs. Miller",
        "Tax Appeal — Individual vs. Revenue Authority",
        "Land Dispute — Boundary Determination",
        "Insurance Claim — Fire Damage Assessment",
        "Employment Tribunal — Wrongful Dismissal",
    ]


def case_descriptions() -> list[str]:
    return [
        "A dispute arising from a commercial contract for the supply of goods. "
        "The plaintiff alleges non-delivery and seeks damages.",
        "Probate matter concerning the last will and testament of the deceased. "
        "Beneficiaries have raised objections.",
        "Criminal appeal against conviction for white-collar crime. "
        "The appellant challenges the admissibility of evidence.",
        "Divorce proceedings involving division of matrimonial assets "
        "and child custody arrangements.",
        "Patent infringement case involving pharmaceutical compounds. "
        "The plaintiff holds a valid patent for the compound.",
        "Child custody and visitation rights dispute between estranged parents. "
        "Mediation has been ordered by the court.",
        "Tax assessment appeal concerning disallowed deductions "
        "for business expenses.",
        "Boundary dispute between neighboring landowners. "
        "Survey evidence has been submitted by both parties.",
        "Insurance claim dispute over fire damage valuation. "
        "Independent assessor appointed.",
        "Wrongful termination claim by former employee. "
        "Allegations of unfair dismissal and discrimination.",
    ]
