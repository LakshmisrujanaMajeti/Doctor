from datetime import date, datetime
from typing import Optional, List
from app.schemas.common import BaseSchema


class PatientBase(BaseSchema):
    full_name: str
    parent_spouse_name: Optional[str] = None
    parent_spouse_relation: Optional[str] = None # S/o, D/o, W/o, H/o, Care of
    date_of_birth: Optional[date] = None
    age_years: Optional[int] = None
    age_months: Optional[int] = None
    gender: str # MALE, FEMALE, OTHER, PREFER_NOT_TO_SAY
    phone: str
    email: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    postal_code: Optional[str] = None
    blood_group: Optional[str] = None # A+, B+, O+, AB+, etc.
    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None
    emergency_contact_relation: Optional[str] = None
    barcode_value: Optional[str] = None
    qr_code_data: Optional[str] = None
    guardian_id: Optional[str] = None


class PatientCreate(PatientBase):
    hospital_reg_num: Optional[str] = None


class PatientUpdate(BaseSchema):
    full_name: Optional[str] = None
    parent_spouse_name: Optional[str] = None
    parent_spouse_relation: Optional[str] = None
    date_of_birth: Optional[date] = None
    age_years: Optional[int] = None
    age_months: Optional[int] = None
    gender: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    postal_code: Optional[str] = None
    blood_group: Optional[str] = None
    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None
    emergency_contact_relation: Optional[str] = None
    barcode_value: Optional[str] = None
    qr_code_data: Optional[str] = None
    guardian_id: Optional[str] = None


class PatientRead(PatientBase):
    id: str
    uhid: str
    hospital_reg_num: Optional[str] = None
    registration_date: datetime


class DuplicateCandidate(BaseSchema):
    id: str
    uhid: str
    hospital_reg_num: Optional[str] = None
    full_name: str
    phone: str
    gender: str
    age_years: Optional[int] = None
    parent_spouse_name: Optional[str] = None
    match_reason: str


class DuplicateCheckRequest(BaseSchema):
    phone: str
    full_name: Optional[str] = None
    hospital_reg_num: Optional[str] = None


class DuplicateCheckResponse(BaseSchema):
    is_duplicate: bool
    candidates: List[DuplicateCandidate] = []
    message: str
