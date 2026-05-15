from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    bar_number: Mapped[str | None] = mapped_column(String(100), unique=True, nullable=True, index=True)
    phone: Mapped[str | None] = mapped_column(String(50), nullable=True)
    profile_photo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    clients = relationship("Client", back_populates="advocate", lazy="selectin")
    cases = relationship("Case", back_populates="advocate", lazy="selectin", foreign_keys="Case.advocate_id")
    uploaded_documents = relationship("Document", back_populates="uploader", lazy="selectin")
    case_notes = relationship("CaseNote", back_populates="author", lazy="selectin")

    def __repr__(self) -> str:
        return f"<User(id={self.id}, full_name={self.full_name!r}, email={self.email!r})>"
