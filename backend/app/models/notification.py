from datetime import datetime
from sqlalchemy import Column, String, Integer, DateTime, Text, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import TimestampMixin, generate_uuid


class Notification(Base, TimestampMixin):
    """
    Hospital Notification Model.
    Tracks user and role-directed clinical alerts, queue announcements, and results.
    """
    __tablename__ = "notifications"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True)
    target_role = Column(String(50), nullable=True, index=True)  # "doctor", "nurse", "receptionist", "patient", "all"
    
    title = Column(String(200), nullable=False)
    message = Column(Text, nullable=False)
    category = Column(String(50), nullable=False, default="general", index=True)  # alert, queue, lab, pharmacy, billing, general
    priority = Column(String(20), nullable=False, default="NORMAL")  # EMERGENCY, PRIORITY, NORMAL
    
    is_read = Column(Boolean, nullable=False, default=False, index=True)
    read_at = Column(DateTime, nullable=True)
    
    target_route = Column(String(200), nullable=True)  # /queue, /laboratory, /billing, /patients
    entity_type = Column(String(50), nullable=True)    # Visit, LabOrder, Prescription, Bill, Patient
    entity_id = Column(String(50), nullable=True)

    user = relationship("User", backref="notifications")
