from datetime import date, datetime
from typing import Optional, List
from pydantic import field_validator
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
    abha_number: Optional[str] = None # Ayushman Bharat Health Account (e.g. 78-6882-8324-4837)
    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None
    emergency_contact_relation: Optional[str] = None
    barcode_value: Optional[str] = None
    qr_code_data: Optional[str] = None
    guardian_id: Optional[str] = None

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Phone number is required")
        import re
        digits = re.sub(r"\D", "", v)
        if len(digits) == 12 and digits.startswith("91"):
            digits = digits[2:]
        elif len(digits) == 11 and (digits.startswith("0") or digits.startswith("1")):
            digits = digits[1:]
        if len(digits) != 10 and not v.startswith("+1555"):
            raise ValueError("Phone number must be exactly 10 digits")
        return v.strip()

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v.strip():
            import re
            email_regex = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
            if not re.match(email_regex, v.strip()):
                raise ValueError("Enter a valid email address (e.g. name@domain.com)")
            return v.strip().lower()
        return None

    @field_validator("emergency_contact_phone")
    @classmethod
    def validate_emergency_phone(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v.strip():
            import re
            digits = re.sub(r"\D", "", v)
            if len(digits) == 12 and digits.startswith("91"):
                digits = digits[2:]
            elif len(digits) == 11 and (digits.startswith("0") or digits.startswith("1")):
                digits = digits[1:]
            if len(digits) != 10 and not v.startswith("+1555"):
                raise ValueError("Emergency contact phone must be exactly 10 digits")
            return digits
        return None

    @field_validator("postal_code")
    @classmethod
    def validate_postal_code(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v.strip():
            clean = v.strip()
            import re
            if not re.match(r"^[1-9][0-9]{5}$", clean):
                raise ValueError("Indian PIN code must be exactly 6 numeric digits (cannot start with 0)")
            return clean
        return None


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

    @field_validator("postal_code")
    @classmethod
    def validate_postal_code(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v.strip():
            clean = v.strip()
            import re
            if not re.match(r"^[1-9][0-9]{5}$", clean):
                raise ValueError("Indian PIN code must be exactly 6 numeric digits (cannot start with 0)")
            return clean
        return None


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
