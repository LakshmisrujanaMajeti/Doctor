from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import TimestampMixin, generate_uuid


class SupportTicket(Base, TimestampMixin):
    __tablename__ = "support_tickets"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    patient_id = Column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)

    subject = Column(String(200), nullable=False)
    category = Column(String(50), default="GENERAL", nullable=False)  # GENERAL, APPOINTMENT, BILLING, MEDICAL_RECORDS, PHARMACY, TECHNICAL
    priority = Column(String(20), default="NORMAL", nullable=False)   # LOW, NORMAL, HIGH, URGENT
    message = Column(Text, nullable=False)

    status = Column(String(30), default="OPEN", nullable=False, index=True)  # OPEN, IN_PROGRESS, RESOLVED, CLOSED
    assigned_to_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    admin_response = Column(Text, nullable=True)
    resolved_at = Column(DateTime, nullable=True)

    patient = relationship("Patient")
    user = relationship("User", foreign_keys=[user_id])
    assigned_to = relationship("User", foreign_keys=[assigned_to_user_id])
