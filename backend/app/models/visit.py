from datetime import datetime
from sqlalchemy import Column, String, Integer, Float, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import TimestampMixin, generate_uuid


class OPDVisit(Base, TimestampMixin):
    __tablename__ = "opd_visits"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    visit_number = Column(String(50), unique=True, nullable=False, index=True) # e.g. VIS-2026-0001
    patient_id = Column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, index=True)
    doctor_id = Column(String(36), ForeignKey("doctors.id"), nullable=False, index=True)
    department_id = Column(String(36), ForeignKey("departments.id"), nullable=False, index=True)

    visit_date = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    queue_token = Column(Integer, nullable=False, index=True)
    triage_priority = Column(String(20), default="NORMAL", nullable=False) # NORMAL, PRIORITY, EMERGENCY
    status = Column(String(30), default="REGISTERED", nullable=False, index=True) # REGISTERED, TRIAGED, IN_CONSULTATION, COMPLETED, CANCELLED
    consultation_fee = Column(Float, default=500.0, nullable=False)
    payment_status = Column(String(20), default="UNPAID", nullable=False) # UNPAID, PAID
    notes = Column(Text, nullable=True)

    patient = relationship("Patient", back_populates="visits")
    doctor = relationship("Doctor", back_populates="visits")
    department = relationship("Department", back_populates="visits")

    vitals = relationship("VitalSigns", back_populates="visit", uselist=False, cascade="all, delete-orphan")
    clinical_record = relationship("ClinicalRecord", back_populates="visit", uselist=False, cascade="all, delete-orphan")
    prescriptions = relationship("Prescription", back_populates="visit", cascade="all, delete-orphan")
    lab_orders = relationship("LabOrder", back_populates="visit", cascade="all, delete-orphan")
    bills = relationship("Bill", back_populates="visit", cascade="all, delete-orphan")
    documents = relationship("MedicalDocument", back_populates="visit", cascade="all, delete-orphan")


class VitalSigns(Base, TimestampMixin):
    __tablename__ = "vital_signs"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    visit_id = Column(String(36), ForeignKey("opd_visits.id", ondelete="CASCADE"), unique=True, nullable=False, index=True)
    recorded_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)

    systolic_bp = Column(Integer, nullable=True)    # mmHg (e.g. 120)
    diastolic_bp = Column(Integer, nullable=True)   # mmHg (e.g. 80)
    pulse_rate = Column(Integer, nullable=True)     # beats/min (e.g. 72)
    temperature_f = Column(Float, nullable=True)    # Fahrenheit (e.g. 98.6)
    spo2_percent = Column(Float, nullable=True)     # SpO2 % (e.g. 98)
    respiratory_rate = Column(Integer, nullable=True) # breaths/min (e.g. 16)
    weight_kg = Column(Float, nullable=True)        # kg
    height_cm = Column(Float, nullable=True)        # cm
    bmi = Column(Float, nullable=True)              # kg/m2
    blood_glucose_mg_dl = Column(Float, nullable=True) # mg/dL random/fasting blood sugar

    recorded_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    notes = Column(Text, nullable=True)

    visit = relationship("OPDVisit", back_populates="vitals")
    recorded_by = relationship("User", foreign_keys=[recorded_by_user_id])
