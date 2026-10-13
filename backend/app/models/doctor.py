from sqlalchemy import Column, String, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import TimestampMixin, generate_uuid


class Doctor(Base, TimestampMixin):
    __tablename__ = "doctors"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False, index=True)
    department_id = Column(String(36), ForeignKey("departments.id"), nullable=False, index=True)

    qualification = Column(String(150), nullable=False)  # e.g., MBBS, MD (Medicine)
    specialization = Column(String(150), nullable=False) # e.g., Internal Medicine, Cardiology
    registration_number = Column(String(50), unique=True, nullable=False, index=True) # Medical Council Reg No
    room_number = Column(String(30), nullable=True)
    consultation_fee = Column(String(20), default="500.00", nullable=False)
    is_available = Column(Boolean, default=True, nullable=False)

    user = relationship("User", back_populates="doctor_profile")
    department = relationship("Department", back_populates="doctors")
    visits = relationship("OPDVisit", back_populates="doctor")
    clinical_records = relationship("ClinicalRecord", back_populates="doctor")
