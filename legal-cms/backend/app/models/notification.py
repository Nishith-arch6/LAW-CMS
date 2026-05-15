import enum
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class NotificationType(str, enum.Enum):
    HEARING_REMINDER = "hearing_reminder"
    CASE_UPDATE = "case_update"
    WELCOME = "welcome"


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    hearing_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("hearings.id"), nullable=True)
    type: Mapped[NotificationType] = mapped_column(Enum(NotificationType), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    sent_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    read: Mapped[bool] = mapped_column(Boolean, default=False)

    user = relationship("User")
    hearing = relationship("Hearing")

    def __repr__(self) -> str:
        return f"<Notification(id={self.id}, type={self.type.value}, user_id={self.user_id})>"
