import enum
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class CaseType(str, enum.Enum):
    CIVIL = "CIVIL"
    CRIMINAL = "CRIMINAL"
    FAMILY = "FAMILY"
    CORPORATE = "CORPORATE"
    OTHER = "OTHER"


class CaseStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    CLOSED = "CLOSED"
    PENDING = "PENDING"
    ADJOURNED = "ADJOURNED"


class Case(Base):
    __tablename__ = "cases"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    case_number: Mapped[str] = mapped_column(String(100), unique=True, nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    case_type: Mapped[CaseType] = mapped_column(Enum(CaseType), default=CaseType.CIVIL, nullable=False)
    status: Mapped[CaseStatus] = mapped_column(Enum(CaseStatus), default=CaseStatus.ACTIVE, nullable=False)
    court_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    court_building: Mapped[str | None] = mapped_column(String(255), nullable=True)
    court_floor: Mapped[str | None] = mapped_column(String(100), nullable=True)
    judge_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    client_id: Mapped[int] = mapped_column(Integer, ForeignKey("clients.id"), nullable=False)
    advocate_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    opposing_party: Mapped[str | None] = mapped_column(String(255), nullable=True)
    defending_party: Mapped[str | None] = mapped_column(String(255), nullable=True)
    filing_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), onupdate=func.now(), nullable=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    client = relationship("Client", back_populates="cases")
    advocate = relationship("User", back_populates="cases", foreign_keys=[advocate_id])
    hearings = relationship("Hearing", back_populates="case", lazy="selectin", cascade="all, delete-orphan")
    documents = relationship("Document", back_populates="case", lazy="selectin", cascade="all, delete-orphan")
    notes = relationship("CaseNote", back_populates="case", lazy="selectin", cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<Case(id={self.id}, case_number={self.case_number!r}, title={self.title!r})>"
