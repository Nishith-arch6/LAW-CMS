from fastapi import HTTPException, UploadFile, status

from app.core.config import settings

MAGIC_BYTES: dict[str, bytes] = {
    "pdf": b"%PDF",
    "jpg": b"\xff\xd8\xff",
    "jpeg": b"\xff\xd8\xff",
    "png": b"\x89PNG\r\n\x1a\n",
}

EXT_MAP: dict[str, str] = {
    "pdf": "application/pdf",
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "txt": "text/plain",
    "doc": "application/msword",
    "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
}

ALLOWED_MIME_TYPES = set(EXT_MAP.values())


async def validate_upload(file: UploadFile) -> None:
    content = await file.read()
    await file.seek(0)

    if len(content) > settings.max_upload_size_mb * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File exceeds {settings.max_upload_size_mb} MB limit",
        )

    ext = file.filename.rsplit(".", 1)[-1].lower() if file.filename else ""

    if ext in MAGIC_BYTES:
        expected_header = MAGIC_BYTES[ext]
        if not content.startswith(expected_header):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"File extension '.{ext}' does not match actual file content",
            )

    if ext in EXT_MAP and EXT_MAP[ext] not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File type '.{ext}' is not allowed",
        )

    if ext not in EXT_MAP:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File extension '.{ext}' is not supported",
        )
