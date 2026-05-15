import os
import uuid

from fastapi import UploadFile

from app.core.config import settings


async def save_upload(file: UploadFile, subdir: str = "") -> str:
    ext = os.path.splitext(file.filename or "file")[1]
    filename = f"{uuid.uuid4().hex}{ext}"
    upload_path = os.path.join(settings.upload_dir, subdir)
    os.makedirs(upload_path, exist_ok=True)
    dest = os.path.join(upload_path, filename)
    content = await file.read()
    with open(dest, "wb") as f:
        f.write(content)
    return dest
