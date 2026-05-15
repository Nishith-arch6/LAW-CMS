import os
import uuid

from app.core.config import settings

ALLOWED_MIME_TYPES: dict[str, set[str]] = {
    "document": {
        "application/pdf",
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    },
    "image": {"image/jpeg", "image/png"},
    "text": {"text/plain"},
}

ALLOWED_EXTENSIONS: set[str] = {".pdf", ".doc", ".docx", ".jpg", ".jpeg", ".png", ".txt"}

MAX_FILE_SIZE = settings.max_upload_size_mb * 1024 * 1024


def ensure_directory(path: str) -> str:
    os.makedirs(path, exist_ok=True)
    return path


def generate_unique_filename(original_name: str) -> str:
    ext = os.path.splitext(original_name)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        ext = ".bin"
    return f"{uuid.uuid4().hex}{ext}"


def get_file_extension(filename: str) -> str:
    return os.path.splitext(filename)[1].lower()


def build_upload_path(advocate_id: int, case_id: int, filename: str) -> str:
    relative = os.path.join(str(advocate_id), str(case_id))
    directory = os.path.join(settings.upload_dir, relative)
    ensure_directory(directory)
    return os.path.join(directory, filename)


def is_image_mime(mime: str) -> bool:
    return mime in ALLOWED_MIME_TYPES["image"]


def is_pdf_mime(mime: str) -> bool:
    return mime == "application/pdf"
