from datetime import date, datetime
from typing import Optional, List
from pydantic import model_validator
from app.schemas.common import BaseSchema


class ClinicalAmendmentRead(BaseSchema):
    id: str
    clinical_record_id: str
    amended_by_user_id: str
    amended_at: datetime
    reason: str
    previous_snapshot_json: str


class ClinicalRecordBase(BaseSchema):
    # Initial Assessment
    presenting_complaint: Optional[str] = None
    chief_complaint: Optional[str] = None  # alias for backward compatibility
    history_of_present_illness: Optional[str] = None
    allergies: Optional[str] = None
    past_medical_history: Optional[str] = None
    past_history: Optional[str] = None  # alias for backward compatibility
    prior_hospitalization: Optional[str] = None
    hypertension_history: Optional[str] = None
    diabetes_history: Optional[str] = None
    asthma_history: Optional[str] = None
    tuberculosis_history: Optional[str] = None
    smoking_history: Optional[str] = None
    alcohol_history: Optional[str] = None
    family_history: Optional[str] = None

    # Examination Findings
    general_examination: Optional[str] = None
    respiratory_examination: Optional[str] = None
    cardiovascular_examination: Optional[str] = None
    gastrointestinal_examination: Optional[str] = None
    cns_examination: Optional[str] = None
    other_examination_findings: Optional[str] = None
    physical_examination: Optional[str] = None  # alias for backward compatibility

    # Clinical Plan & Diagnoses
    provisional_diagnosis: Optional[str] = None
    final_diagnosis: Optional[str] = None
    icd10_code: Optional[str] = None
    care_plan: Optional[str] = None
    clinical_notes: Optional[str] = None  # alias for backward compatibility
    investigations_requested: Optional[str] = None
    dietary_advice: Optional[str] = None
    follow_up_date: Optional[date] = None
    referral_department: Optional[str] = None

    @model_validator(mode="after")
    def sync_aliases(self):
        if not self.presenting_complaint and self.chief_complaint:
            self.presenting_complaint = self.chief_complaint
        elif not self.chief_complaint and self.presenting_complaint:
            self.chief_complaint = self.presenting_complaint

        if not self.past_medical_history and self.past_history:
            self.past_medical_history = self.past_history
        elif not self.past_history and self.past_medical_history:
            self.past_history = self.past_medical_history

        if not self.other_examination_findings and self.physical_examination:
            self.other_examination_findings = self.physical_examination
        elif not self.physical_examination and self.other_examination_findings:
            self.physical_examination = self.other_examination_findings

        if not self.care_plan and self.clinical_notes:
            self.care_plan = self.clinical_notes
        elif not self.clinical_notes and self.care_plan:
            self.clinical_notes = self.care_plan

        return self


class ClinicalRecordCreate(ClinicalRecordBase):
    visit_id: str
    status: Optional[str] = "FINALIZED"  # FINALIZED (default submission) or DRAFT (autosave/draft)


class ClinicalRecordUpdate(ClinicalRecordBase):
    status: Optional[str] = None


class ClinicalRecordSignRequest(BaseSchema):
    pass


class ClinicalRecordAmendRequest(ClinicalRecordBase):
    amendment_reason: str


class ClinicalRecordRead(ClinicalRecordBase):
    id: str
    visit_id: str
    patient_id: str
    doctor_id: str
    status: str
    version: int
    created_by_user_id: Optional[str] = None
    updated_by_user_id: Optional[str] = None
    signed_by_user_id: Optional[str] = None
    signed_at: Optional[datetime] = None
    amendment_reason: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    amendments: List[ClinicalAmendmentRead] = []
