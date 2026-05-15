"""
Document intelligence: extract dates, parties, case numbers, and summarize text.
"""

import logging
import re
from collections import Counter

logger = logging.getLogger("legal_cms.ml.document_analyzer")

try:
    import dateparser
except ImportError:
    dateparser = None


# ── date extraction ─────────────────────────────────────────────────


_DATE_PATTERNS = [
    r"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}",
    r"\d{4}[/-]\d{1,2}[/-]\d{1,2}",
    r"(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|"
    r"Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)"
    r"\s+\d{1,2},?\s+\d{4}",
    r"\d{1,2}\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|"
    r"Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)"
    r",?\s+\d{4}",
]

_DATE_CONTEXT_WORDS = [
    "hearing", "deadline", "filing", "due", "appear", "scheduled",
    "adjourned", "submission", "response", "served", "noticed",
]


def extract_key_dates(text: str) -> list[dict]:
    if not text:
        return []
    found = set()
    results = []
    for pattern in _DATE_PATTERNS:
        for match in re.finditer(pattern, text, re.IGNORECASE):
            raw = match.group()
            if raw in found:
                continue
            found.add(raw)
            start = max(0, match.start() - 60)
            end = min(len(text), match.end() + 60)
            context = text[start:end].strip()
            if start > 0:
                context = f"...{context}"
            if end < len(text):
                context = f"{context}..."
            parsed = None
            if dateparser:
                parsed = str(dateparser.parse(raw).date()) if dateparser.parse(raw) else None
            results.append({
                "date": parsed or raw,
                "raw": raw,
                "context": context,
            })
    return results[:20]


# ── party extraction ─────────────────────────────────────────────────


def extract_parties(text: str) -> dict:
    parties = {"plaintiff": None, "defendant": None, "advocates": []}
    if not text:
        return parties

    patterns = {
        "plaintiff": [
            r"(?:Plaintiff|Petitioner|Applicant)\s*[:\-–]\s*([A-Z][A-Za-z\s.]+?)(?=[,;\n]|and\s+|v\.|vs\.)",
            r"(?:Filed by|Filed on behalf of)\s+([A-Z][A-Za-z\s.]+?)(?=[,;\n]|and\s+)",
        ],
        "defendant": [
            r"(?:Defendant|Respondent|Opponent)\s*[:\-–]\s*([A-Z][A-Za-z\s.]+?)(?=[,;\n]|and\s+|v\.|vs\.)",
            r"(?:against|versus|v\.|vs\.)\s+([A-Z][A-Za-z\s.]+?)(?=[,;\n]|and\s+)",
        ],
        "advocate": [
            r"(?:Advocate|Counsel|Attorney|Lawyer)\s*[:\-–]\s*([A-Z][A-Za-z\s.]+?)(?=[,;\n]|and\s+|for\s+)",
            r"(?:Represented by|Counsel for|Advocate for)\s+([A-Z][A-Za-z\s.]+?)(?=[,;\n]|and\s+)",
        ],
    }

    text_block = text[:3000]
    for role, role_patterns in patterns.items():
        for pat in role_patterns:
            matches = re.findall(pat, text_block, re.IGNORECASE)
            if matches:
                val = matches[0].strip()
                if role == "advocate":
                    parties["advocates"].append(val)
                else:
                    parties[role] = val
                break

    parties["advocates"] = list(dict.fromkeys(parties["advocates"]))
    return parties


# ── case number extraction ────────────────────────────────────────────


_CASE_NUMBER_PATTERNS = [
    r"\b(?:Case|Case No|C\.?C\.?|Suit|Petition|Appeal)\s*[.:#]?\s*([A-Z0-9/\-]{4,30})\b",
    r"\b(\d{4,}\s*[-–]\s*\d{1,6}[A-Za-z]?)\b",
    r"\b([A-Z]{2,4}\s*[-–]\s*\d{2,6}\s*[-–]\s*\d{4})\b",
]


def extract_case_number(text: str) -> str | None:
    if not text:
        return None
    for pattern in _CASE_NUMBER_PATTERNS:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return match.group(1) if match.lastindex else match.group(0)
    return None


# ── extractive summarization (TF-IDF) ─────────────────────────────────


def summarize_document(text: str, max_sentences: int = 5) -> str:
    if not text:
        return ""
    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    if len(sentences) <= max_sentences:
        return text.strip()

    try:
        from sklearn.feature_extraction.text import TfidfVectorizer
        import numpy as np

        vectorizer = TfidfVectorizer(
            max_features=1000,
            stop_words="english",
            ngram_range=(1, 2),
        )
        tfidf_matrix = vectorizer.fit_transform(sentences)
        sentence_scores = np.array(tfidf_matrix.sum(axis=1)).flatten()
        top_indices = set(sentence_scores.argsort()[-max_sentences:][::-1])
        selected = [sentences[i] for i in range(len(sentences)) if i in top_indices]
        return " ".join(selected)
    except ImportError:
        logger.warning("sklearn not available — using first N sentences")
        return " ".join(sentences[:max_sentences])
    except Exception as e:
        logger.error("Summarization failed: %s", e)
        return " ".join(sentences[:max_sentences])
