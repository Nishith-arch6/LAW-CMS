import enum
from datetime import date, datetime, time

from sqlalchemy import Boolean, Date, DateTime, Enum, ForeignKey, Integer, String, Text, Time, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class HearingStatus(str, enum.Enum):
    SCHEDULED = "SCHEDULED"
    COMPLETED = "COMPLETED"
    ADJOURNED = "ADJOURNED"
    CANCELLED = "CANCELLED"


class Hearing(Base):
    __tablename__ = "hearings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    case_id: Mapped[int] = mapped_column(Integer, ForeignKey("cases.id"), nullable=False)
    hearing_date: Mapped[date] = mapped_column(Date, nullable=False)
    hearing_time: Mapped[time | None] = mapped_column(Time, nullable=True)
    court_room: Mapped[str | None] = mapped_column(String(100), nullable=True)
    purpose: Mapped[str | None] = mapped_column(Text, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    reminder_sent: Mapped[bool] = mapped_column(Boolean, default=False)
    status: Mapped[HearingStatus] = mapped_column(Enum(HearingStatus), default=HearingStatus.SCHEDULED, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    case = relationship("Case", back_populates="hearings")

    def __repr__(self) -> str:
        return f"<Hearing(id={self.id}, case_id={self.case_id}, date={self.hearing_date})>"
