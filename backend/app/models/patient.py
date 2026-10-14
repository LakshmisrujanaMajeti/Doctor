from datetime import datetime
from sqlalchemy import Column, String, Integer, Date, DateTime, Text, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import TimestampMixin, generate_uuid


class Patient(Base, TimestampMixin):
    """
    OPD Patient Registration Demographics.
    Based on the official hospital OPD booklet registration header.
    """
    __tablename__ = "patients"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    uhid = Column(String(50), unique=True, nullable=False, index=True) # Unique Health ID (e.g. C407662 or UHID-2026-00001)
    hospital_reg_num = Column(String(50), unique=True, nullable=True, index=True) # Hospital Reg No (e.g. REG-2026-00001)
    abha_number = Column(String(50), nullable=True, index=True) # Ayushman Bharat Health Account (e.g. 78-6882-8324-4837)
    
    full_name = Column(String(150), nullable=False, index=True)
    parent_spouse_name = Column(String(150), nullable=True) # S/o, D/o, W/o, H/o, Care of
    parent_spouse_relation = Column(String(30), nullable=True) # "S/o", "D/o", "W/o", "H/o", "Care of"
    
    date_of_birth = Column(Date, nullable=True)
    age_years = Column(Integer, nullable=True)
    age_months = Column(Integer, nullable=True)
    gender = Column(String(20), nullable=False) # MALE, FEMALE, OTHER, PREFER_NOT_TO_SAY
    
    phone = Column(String(30), nullable=False, index=True)
    email = Column(String(255), nullable=True)
    address = Column(Text, nullable=True)
    city = Column(String(100), nullable=True)
    state = Column(String(100), nullable=True)
    postal_code = Column(String(20), nullable=True)
    blood_group = Column(String(10), nullable=True) # A+, B+, O+, AB+, etc.

    registration_date = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    barcode_value = Column(String(100), unique=True, nullable=True, index=True)
    qr_code_data = Column(String(255), nullable=True)

    emergency_contact_name = Column(String(150), nullable=True)
    emergency_contact_phone = Column(String(30), nullable=True)
    emergency_contact_relation = Column(String(50), nullable=True)

    # Staff attribution tracking (who registered the patient)
    registered_by_staff_id = Column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    registered_by_staff_name = Column(String(150), nullable=True)
    registered_by_staff_role = Column(String(50), nullable=True)
    registered_by_staff = relationship("User", foreign_keys=[registered_by_staff_id])

    # Authorized linked dependents (pediatric or elderly dependents)
    guardian_id = Column(String(36), ForeignKey("patients.id", ondelete="SET NULL"), nullable=True, index=True)
    dependents = relationship("Patient", backref="guardian", remote_side=[id])

    visits = relationship("OPDVisit", back_populates="patient", cascade="all, delete-orphan")
    clinical_records = relationship("ClinicalRecord", back_populates="patient")
    documents = relationship("MedicalDocument", back_populates="patient", cascade="all, delete-orphan")
    bills = relationship("Bill", back_populates="patient")
