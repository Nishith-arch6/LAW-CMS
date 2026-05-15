import asyncio
import logging
import os

from PIL import Image, ImageFilter, ImageOps
from sqlalchemy import select

from app.core.config import settings
from app.core.database import async_session_factory
from app.models.document import Document
from app.utils.pdf_utils import convert_pdf_to_images

logger = logging.getLogger("legal_cms.ocr")
pytesseract = None

try:
    import pytesseract

    pytesseract.pytesseract.tesseract_cmd = settings.tesseract_cmd
except Exception:
    logger.warning("pytesseract not available — OCR disabled")

cv2 = None
try:
    import cv2 as cv2_lib

    cv2 = cv2_lib
except ImportError:
    logger.info("OpenCV not available — using Pillow-only preprocessing")


def _preprocess_image(image: Image.Image) -> Image.Image:
    gray = ImageOps.grayscale(image)
    if cv2:
        import numpy as np

        arr = np.array(gray)
        denoised = cv2.fastNlMeansDenoising(arr, None, 30, 7, 21)
        _, thresholded = cv2.threshold(denoised, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        return Image.fromarray(thresholded)
    denoised = gray.filter(ImageFilter.MedianFilter(size=3))
    thresholded = denoised.point(lambda p: 255 if p > 128 else 0)
    return thresholded


def extract_text_from_image(image_path: str) -> str:
    if pytesseract is None:
        return ""
    try:
        image = Image.open(image_path)
        processed = _preprocess_image(image)
        text = pytesseract.image_to_string(processed, lang="eng")
        return text.strip()
    except Exception as e:
        logger.error("OCR failed for %s: %s", image_path, e)
        return ""


async def extract_text_from_pdf(pdf_path: str) -> str:
    if pytesseract is None:
        return ""
    try:
        images = await asyncio.to_thread(convert_pdf_to_images, pdf_path)
        text_parts = []
        for img in images:
            processed = await asyncio.to_thread(_preprocess_image, img)
            text = await asyncio.to_thread(
                pytesseract.image_to_string, processed, "eng"
            )
            text_parts.append(text.strip())
        return "\n".join(text_parts).strip()
    except ImportError:
        logger.warning("pdf2image not installed — cannot OCR PDFs")
        return ""
    except Exception as e:
        logger.error("PDF OCR failed for %s: %s", pdf_path, e)
        return ""


def _extract_text_from_txt(file_path: str) -> str:
    try:
        with open(file_path, "r", encoding="utf-8", errors="replace") as f:
            return f.read().strip()
    except Exception as e:
        logger.error("Failed to read text file %s: %s", file_path, e)
        return ""


def _extract_text_from_docx(file_path: str) -> str:
    try:
        from docx import Document as DocxDocument

        doc = DocxDocument(file_path)
        return "\n".join(p.text for p in doc.paragraphs).strip()
    except ImportError:
        logger.warning("python-docx not installed — cannot extract .docx text")
        return ""
    except Exception as e:
        logger.error("Failed to extract .docx text from %s: %s", file_path, e)
        return ""


async def extract_text_auto(file_path: str, file_type: str) -> str:
    ext = os.path.splitext(file_path)[1].lower()
    if ext in (".jpg", ".jpeg", ".png", ".webp"):
        return await asyncio.to_thread(extract_text_from_image, file_path)
    if ext == ".pdf":
        return await extract_text_from_pdf(file_path)
    if ext == ".txt":
        return _extract_text_from_txt(file_path)
    if ext in (".doc", ".docx"):
        return _extract_text_from_docx(file_path)
    return ""


async def run_ocr_and_save(
    document_id: int,
    file_path: str,
    file_type: str,
) -> None:
    db = async_session_factory()
    try:
        text = await extract_text_auto(file_path, file_type)
        if not text:
            logger.info("No OCR text extracted for document %d", document_id)
            return
        result = await db.execute(select(Document).where(Document.id == document_id))
        doc = result.scalar_one_or_none()
        if doc:
            doc.ocr_text = text
            await db.commit()
            logger.info("OCR saved for document %d (%d chars)", document_id, len(text))
    except Exception as e:
        logger.error("OCR background task failed for doc %d: %s", document_id, e)
        await db.rollback()
    finally:
        await db.close()
