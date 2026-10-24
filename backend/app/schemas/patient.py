from datetime import date, datetime
from typing import Optional, List
from pydantic import field_validator
from app.schemas.common import BaseSchema


from app.core.validators import (
    validate_person_name,
    validate_indian_phone,
    validate_pin_code,
    validate_email_address,
    validate_age_years,
    validate_date_of_birth,
    validate_address_text,
)


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
    abha_number: Optional[str] = None # Ayushman Bharat Health Account (e.g. 78-6882-8324-4837)
    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None
    emergency_contact_relation: Optional[str] = None
    barcode_value: Optional[str] = None
    qr_code_data: Optional[str] = None
    guardian_id: Optional[str] = None

    @field_validator("full_name")
    @classmethod
    def validate_full_name(cls, v: str) -> str:
        res = validate_person_name(v, "Patient Full Name", is_required=True)
        return res or v

    @field_validator("parent_spouse_name")
    @classmethod
    def validate_parent_spouse_name(cls, v: Optional[str]) -> Optional[str]:
        return validate_person_name(v, "Parent / Spouse Name", is_required=False)

    @field_validator("emergency_contact_name")
    @classmethod
    def validate_emergency_contact_name(cls, v: Optional[str]) -> Optional[str]:
        return validate_person_name(v, "Emergency Contact Name", is_required=False)

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        res = validate_indian_phone(v, "Contact Phone", is_required=True)
        return res or v

    @field_validator("emergency_contact_phone")
    @classmethod
    def validate_emergency_phone(cls, v: Optional[str]) -> Optional[str]:
        return validate_indian_phone(v, "Emergency Contact Phone", is_required=False)

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: Optional[str]) -> Optional[str]:
        return validate_email_address(v, "Email Address", is_required=False)

    @field_validator("postal_code")
    @classmethod
    def validate_postal_code(cls, v: Optional[str]) -> Optional[str]:
        return validate_pin_code(v, "PIN Code", is_required=False)

    @field_validator("age_years")
    @classmethod
    def validate_age(cls, v: Optional[int]) -> Optional[int]:
        return validate_age_years(v, "Age", is_required=False)

    @field_validator("date_of_birth")
    @classmethod
    def validate_dob(cls, v: Optional[date]) -> Optional[date]:
        return validate_date_of_birth(v, "Date of Birth", is_required=False)

    @field_validator("address")
    @classmethod
    def validate_address(cls, v: Optional[str]) -> Optional[str]:
        return validate_address_text(v, "Residential Address", is_required=False)


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
    abha_number: Optional[str] = None
    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None
    emergency_contact_relation: Optional[str] = None
    barcode_value: Optional[str] = None
    qr_code_data: Optional[str] = None
    guardian_id: Optional[str] = None

    @field_validator("full_name")
    @classmethod
    def validate_full_name(cls, v: Optional[str]) -> Optional[str]:
        return validate_person_name(v, "Patient Full Name", is_required=False)

    @field_validator("parent_spouse_name")
    @classmethod
    def validate_parent_spouse_name(cls, v: Optional[str]) -> Optional[str]:
        return validate_person_name(v, "Parent / Spouse Name", is_required=False)

    @field_validator("emergency_contact_name")
    @classmethod
    def validate_emergency_contact_name(cls, v: Optional[str]) -> Optional[str]:
        return validate_person_name(v, "Emergency Contact Name", is_required=False)

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: Optional[str]) -> Optional[str]:
        return validate_indian_phone(v, "Contact Phone", is_required=False)

    @field_validator("emergency_contact_phone")
    @classmethod
    def validate_emergency_phone(cls, v: Optional[str]) -> Optional[str]:
        return validate_indian_phone(v, "Emergency Contact Phone", is_required=False)

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: Optional[str]) -> Optional[str]:
        return validate_email_address(v, "Email Address", is_required=False)

    @field_validator("postal_code")
    @classmethod
    def validate_postal_code(cls, v: Optional[str]) -> Optional[str]:
        return validate_pin_code(v, "PIN Code", is_required=False)

    @field_validator("age_years")
    @classmethod
    def validate_age(cls, v: Optional[int]) -> Optional[int]:
        return validate_age_years(v, "Age", is_required=False)

    @field_validator("date_of_birth")
    @classmethod
    def validate_dob(cls, v: Optional[date]) -> Optional[date]:
        return validate_date_of_birth(v, "Date of Birth", is_required=False)

    @field_validator("address")
    @classmethod
    def validate_address(cls, v: Optional[str]) -> Optional[str]:
        return validate_address_text(v, "Residential Address", is_required=False)


class PatientRead(PatientBase):
    id: str
    uhid: str
    hospital_reg_num: Optional[str] = None
    registration_date: datetime
    created_at: Optional[datetime] = None
    registered_by_staff_id: Optional[str] = None
    registered_by_staff_name: Optional[str] = None
    registered_by_staff_role: Optional[str] = None
    current_token: Optional[int] = None
    current_visit_number: Optional[str] = None



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
