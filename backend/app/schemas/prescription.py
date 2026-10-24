from datetime import datetime
from typing import List, Optional
from pydantic import Field
from app.schemas.common import BaseSchema
from app.schemas.doctor import DoctorRead


class PrescriptionItemBase(BaseSchema):
    medicine_name: str
    form: str = "Tablet" # Tablet, Capsule, Syrup, Injection, Ointment, Inhaler, Drops
    dosage: str          # 650mg, 500mg, 10mg, 5ml, 2 puffs
    route: str = "Oral"  # Oral, Topical, IV, IM, Inhalation, Sublingual
    frequency: str = "OD"# OD, BD, TID, QID, SOS
    duration_days: int = Field(default=5, ge=1, le=365)
    quantity: Optional[int] = Field(default=None, ge=1, le=1000)
    timing: str = "After Food" # After food, Before food, Bedtime, Empty stomach
    instructions: Optional[str] = None


class PrescriptionItemCreate(PrescriptionItemBase):
    pass


class PrescriptionItemRead(PrescriptionItemBase):
    id: str
    is_dispensed: bool


class PrescriptionAmendmentRead(BaseSchema):
    id: str
    prescription_id: str
    amended_by_user_id: str
    amended_at: datetime
    reason: str
    previous_snapshot_json: str


class PrescriptionCreate(BaseSchema):
    visit_id: str
    status: Optional[str] = "SIGNED" # DRAFT or SIGNED
    notes: Optional[str] = None
    is_ocr_extracted: Optional[bool] = False
    is_verified_by_clinician: Optional[bool] = True
    allergy_warning_acknowledged: Optional[bool] = False
    items: List[PrescriptionItemCreate] = []


class PrescriptionAmendRequest(BaseSchema):
    amendment_reason: str
    notes: Optional[str] = None
    items: List[PrescriptionItemCreate] = []


class PrescriptionRead(BaseSchema):
    id: str
    visit_id: str
    patient_id: str
    doctor_id: str
    status: str
    version: int = 1
    notes: Optional[str] = None
    signed_by_user_id: Optional[str] = None
    signed_at: Optional[datetime] = None
    amendment_reason: Optional[str] = None
    is_ocr_extracted: bool = False
    is_verified_by_clinician: bool = True
    allergy_warning_acknowledged: bool = False
    created_at: Optional[datetime] = None
    doctor: Optional[DoctorRead] = None
    items: List[PrescriptionItemRead] = []
    amendments: List[PrescriptionAmendmentRead] = []


class AllergyCheckRequest(BaseSchema):
    patient_id: str
    medicines: List[str]


class AllergyWarning(BaseSchema):
    medicine_name: str
    allergen: str
    severity: str # HIGH, MODERATE
    warning_message: str


class AllergyCheckResponse(BaseSchema):
    has_warnings: bool
    warnings: List[AllergyWarning] = []


class MedicineCatalogItem(BaseSchema):
    name: str
    category: str
    common_forms: List[str]
    common_dosages: List[str]
    default_route: str
    allergy_class: Optional[str] = None
