from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import TimestampMixin, generate_uuid


class AuditLog(Base, TimestampMixin):
    __tablename__ = "audit_logs"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)

    action = Column(String(100), nullable=False, index=True) # e.g. LOGIN, CREATE_VISIT, UPDATE_VITALS, DISPENSE_MEDS
    entity_type = Column(String(100), nullable=False, index=True) # e.g. Patient, OPDVisit, ClinicalRecord
    entity_id = Column(String(36), nullable=True, index=True)
    ip_address = Column(String(45), nullable=True)
    details_json = Column(Text, nullable=True)

    user = relationship("User", back_populates="audit_logs")
