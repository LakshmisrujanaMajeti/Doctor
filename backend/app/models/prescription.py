from datetime import datetime
from sqlalchemy import Column, String, Integer, Boolean, ForeignKey, Text, DateTime
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import TimestampMixin, generate_uuid


class Prescription(Base, TimestampMixin):
    __tablename__ = "prescriptions"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    visit_id = Column(String(36), ForeignKey("opd_visits.id", ondelete="CASCADE"), nullable=False, index=True)
    patient_id = Column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, index=True)
    doctor_id = Column(String(36), ForeignKey("doctors.id"), nullable=False, index=True)

    status = Column(String(20), default="SIGNED", nullable=False) # DRAFT, SIGNED, AMENDED, CANCELLED, DISPENSED, ACTIVE
    version = Column(Integer, default=1, nullable=False)
    notes = Column(Text, nullable=True)

    # Authorship & Safety Audit
    signed_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    signed_at = Column(DateTime, nullable=True)
    amendment_reason = Column(Text, nullable=True)
    is_ocr_extracted = Column(Boolean, default=False, nullable=False)
    is_verified_by_clinician = Column(Boolean, default=True, nullable=False)
    allergy_warning_acknowledged = Column(Boolean, default=False, nullable=False)

    visit = relationship("OPDVisit", back_populates="prescriptions")
    patient = relationship("Patient", foreign_keys=[patient_id])
    doctor = relationship("Doctor")
    signed_by = relationship("User", foreign_keys=[signed_by_user_id])
    items = relationship("PrescriptionItem", back_populates="prescription", cascade="all, delete-orphan")
    pharmacy_orders = relationship("PharmacyOrder", back_populates="prescription", cascade="all, delete-orphan")
    amendments = relationship("PrescriptionAmendment", back_populates="prescription", cascade="all, delete-orphan", order_by="desc(PrescriptionAmendment.amended_at)")


class PrescriptionItem(Base, TimestampMixin):
    __tablename__ = "prescription_items"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    prescription_id = Column(String(36), ForeignKey("prescriptions.id", ondelete="CASCADE"), nullable=False, index=True)

    medicine_name = Column(String(150), nullable=False, index=True)
    form = Column(String(50), default="Tablet", nullable=False) # Tablet, Capsule, Syrup, Injection, Ointment, Inhaler, Drops
    dosage = Column(String(50), nullable=False) # e.g. 650mg, 5ml, 2 puffs
    route = Column(String(50), default="Oral", nullable=False) # Oral, Topical, IV, IM, Inhalation, Sublingual
    frequency = Column(String(30), nullable=False) # OD, BD, TID, QID, SOS, Q4H, Q6H
    duration_days = Column(Integer, default=5, nullable=False)
    quantity = Column(Integer, nullable=True) # e.g. 10 tablets, 1 bottle
    timing = Column(String(50), default="After Food", nullable=False) # After food, Before food, Bedtime, Empty stomach
    instructions = Column(Text, nullable=True)
    is_dispensed = Column(Boolean, default=False, nullable=False)

    prescription = relationship("Prescription", back_populates="items")


class PrescriptionAmendment(Base, TimestampMixin):
    __tablename__ = "prescription_amendments"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    prescription_id = Column(String(36), ForeignKey("prescriptions.id", ondelete="CASCADE"), nullable=False, index=True)
    amended_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    amended_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    reason = Column(Text, nullable=False)
    previous_snapshot_json = Column(Text, nullable=False)

    prescription = relationship("Prescription", back_populates="amendments")
    amended_by = relationship("User")
