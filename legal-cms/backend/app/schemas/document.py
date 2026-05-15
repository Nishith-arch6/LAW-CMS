from datetime import datetime

from pydantic import BaseModel, ConfigDict


class DocumentBase(BaseModel):
    case_id: int
    file_name: str
    file_path: str
    file_type: str | None = None
    file_size: int | None = None
    description: str | None = None
    ocr_text: str | None = None


class DocumentCreate(DocumentBase):
    uploaded_by: int


class DocumentUpdate(BaseModel):
    file_name: str | None = None
    file_path: str | None = None
    file_type: str | None = None
    file_size: int | None = None
    description: str | None = None
    ocr_text: str | None = None


class DocumentResponse(DocumentBase):
    id: int
    uploaded_by: int
    case_title: str | None = None
    uploaded_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
