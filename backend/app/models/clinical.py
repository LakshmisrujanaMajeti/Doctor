from datetime import datetime
from sqlalchemy import Column, String, ForeignKey, Text, Date, DateTime, Integer
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import TimestampMixin, generate_uuid


class ClinicalRecord(Base, TimestampMixin):
    """
    OPD Medical Booklet Consultation Sheet.
    Includes initial assessment, system-by-system examinations,
    diagnoses, care plans, investigations, draft controls, and authorship audit.
    """
    __tablename__ = "clinical_records"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    visit_id = Column(String(36), ForeignKey("opd_visits.id", ondelete="CASCADE"), unique=True, nullable=False, index=True)
    patient_id = Column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, index=True)
    doctor_id = Column(String(36), ForeignKey("doctors.id"), nullable=False, index=True)

    # 1. Initial Assessment
    presenting_complaint = Column(Text, nullable=False) # Chief complaint & onset/duration
    history_of_present_illness = Column(Text, nullable=True) # HPI
    allergies = Column(Text, nullable=True) # Drug, food, environmental, NKDA
    past_medical_history = Column(Text, nullable=True) # Past chronic diseases & surgical history
    prior_hospitalization = Column(Text, nullable=True) # Prior admissions, dates, reasons
    hypertension_history = Column(Text, nullable=True) # HTN status, duration, therapy
    diabetes_history = Column(Text, nullable=True) # DM status, type, duration, therapy
    asthma_history = Column(Text, nullable=True) # Asthma/reactive airway status, inhalers
    tuberculosis_history = Column(Text, nullable=True) # TB history, ATT status
    smoking_history = Column(String(100), nullable=True) # Non-smoker, Ex-smoker, Current smoker, packs/day
    alcohol_history = Column(String(100), nullable=True) # None, Occasional, Regular, units/week
    family_history = Column(Text, nullable=True) # CAD, HTN, Diabetes, Asthma, Genetic

    # 2. Examination Findings
    general_examination = Column(Text, nullable=True) # Pallor, Icterus, Cyanosis, Clubbing, Lymphadenopathy, Edema
    respiratory_examination = Column(Text, nullable=True) # Breath sounds, wheezing, crepitations, air entry
    cardiovascular_examination = Column(Text, nullable=True) # S1/S2 heart sounds, murmurs, rhythm
    gastrointestinal_examination = Column(Text, nullable=True) # Abdomen soft/tender, organomegaly, bowel sounds
    cns_examination = Column(Text, nullable=True) # Consciousness, orientation, motor, sensory, reflexes
    other_examination_findings = Column(Text, nullable=True) # Local exam, ENT, skin, etc.

    # 3. Clinical Plan & Diagnoses
    provisional_diagnosis = Column(String(255), nullable=True, index=True)
    final_diagnosis = Column(String(255), nullable=True, index=True)
    icd10_code = Column(String(50), nullable=True, index=True)
    care_plan = Column(Text, nullable=True) # Management plan, medication guidance, lifestyle advice
    investigations_requested = Column(Text, nullable=True) # Lab orders, radiology, ECG, imaging requested
    dietary_advice = Column(Text, nullable=True)
    follow_up_date = Column(Date, nullable=True)
    referral_department = Column(String(100), nullable=True)

    # 4. Data Integrity & Authorship Audit
    status = Column(String(20), default="DRAFT", nullable=False, index=True) # DRAFT, FINALIZED, AMENDED
    version = Column(Integer, default=1, nullable=False)
    created_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    updated_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    signed_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    signed_at = Column(DateTime, nullable=True)
    amendment_reason = Column(Text, nullable=True)

    visit = relationship("OPDVisit", back_populates="clinical_record")
    patient = relationship("Patient", back_populates="clinical_records")
    doctor = relationship("Doctor", back_populates="clinical_records")
    amendments = relationship("ClinicalAmendment", back_populates="clinical_record", cascade="all, delete-orphan", order_by="desc(ClinicalAmendment.amended_at)")


class ClinicalAmendment(Base, TimestampMixin):
    """
    Non-repudiation audit trail for amendments to finalized OPD clinical sheets.
    Ensures signed medical records cannot be silently overwritten.
    """
    __tablename__ = "clinical_amendments"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    clinical_record_id = Column(String(36), ForeignKey("clinical_records.id", ondelete="CASCADE"), nullable=False, index=True)
    amended_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    amended_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    reason = Column(Text, nullable=False)
    previous_snapshot_json = Column(Text, nullable=False)

    clinical_record = relationship("ClinicalRecord", back_populates="amendments")
    amended_by = relationship("User")
