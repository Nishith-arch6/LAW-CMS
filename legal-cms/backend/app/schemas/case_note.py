from datetime import datetime

from pydantic import BaseModel, Field


class CaseNoteBase(BaseModel):
    content: str = Field(..., min_length=1)


class CaseNoteCreate(CaseNoteBase):
    case_id: int


class CaseNoteUpdate(BaseModel):
    content: str = Field(..., min_length=1)


class CaseNoteResponse(CaseNoteBase):
    id: int
    case_id: int
    author_id: int
    created_at: datetime

    model_config = {"from_attributes": True}
