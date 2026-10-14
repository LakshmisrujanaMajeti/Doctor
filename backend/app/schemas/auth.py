from typing import Optional
import re
from pydantic import BaseModel, EmailStr, Field, field_validator
from app.schemas.common import BaseSchema


class LoginRequest(BaseModel):
    # Support email or phone as identifier
    identifier: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    password: str


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class TokenData(BaseSchema):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: "UserRead"


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    phone: Optional[str] = None
    role_name: Optional[str] = "receptionist"

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v.strip():
            digits = re.sub(r"\D", "", v)
            if len(digits) == 12 and digits.startswith("91"):
                digits = digits[2:]
            elif len(digits) == 11 and (digits.startswith("0") or digits.startswith("1")):
                digits = digits[1:]
            if len(digits) != 10 and not v.startswith("+1555"):
                raise ValueError("Phone number must be exactly 10 digits")
            return v.strip()
        return None

    @field_validator("password")
    @classmethod
    def validate_strong_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter (A-Z)")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter (a-z)")
        if not re.search(r"[0-9]", v):
            raise ValueError("Password must contain at least one number (0-9)")
        if not re.search(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;~`]', v):
            raise ValueError("Password must contain at least one special character (!@#$%^&*)")
        return v

    # Doctor-specific
    qualification: Optional[str] = None
    specialization: Optional[str] = None
    registration_number: Optional[str] = None
    department_id: Optional[str] = None
    department_name: Optional[str] = None
    room_number: Optional[str] = None
    consultation_fee: Optional[str] = "500.00"

    # Nurse-specific
    nursing_council_reg: Optional[str] = None
    ward_assigned: Optional[str] = None

    # Pharmacist-specific
    pharmacy_license_number: Optional[str] = None
    dispensing_unit: Optional[str] = None

    # Laboratory-specific
    lab_council_reg: Optional[str] = None
    lab_section: Optional[str] = None

    # Reception / Billing / Admin
    counter_number: Optional[str] = None
    employee_id: Optional[str] = None

    # Patient-specific
    gender: Optional[str] = "MALE"
    date_of_birth: Optional[str] = None
    age_years: Optional[int] = None
    blood_group: Optional[str] = None
    address: Optional[str] = None
    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None
    emergency_contact_relation: Optional[str] = None


class PatientRegisterRequest(BaseModel):
    full_name: str
    phone: str
    email: Optional[EmailStr] = None
    password: str
    gender: str = "MALE"
    date_of_birth: Optional[str] = None
    age_years: Optional[int] = None
    blood_group: Optional[str] = None
    address: Optional[str] = None
    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None
    emergency_contact_relation: Optional[str] = None

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Phone number is required")
        digits = re.sub(r"\D", "", v)
        if len(digits) == 12 and digits.startswith("91"):
            digits = digits[2:]
        elif len(digits) == 11 and (digits.startswith("0") or digits.startswith("1")):
            digits = digits[1:]
        if len(digits) != 10 and not v.startswith("+1555"):
            raise ValueError("Phone number must be exactly 10 digits")
        return v.strip()

    @field_validator("password")
    @classmethod
    def validate_strong_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter (A-Z)")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter (a-z)")
        if not re.search(r"[0-9]", v):
            raise ValueError("Password must contain at least one number (0-9)")
        if not re.search(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;~`]', v):
            raise ValueError("Password must contain at least one special character (!@#$%^&*)")
        return v


class ForgotPasswordRequest(BaseModel):
    identifier: str  # email or phone


class ForgotPasswordResponse(BaseSchema):
    message: str
    dev_mock_token: Optional[str] = None


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_strong_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter (A-Z)")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter (a-z)")
        if not re.search(r"[0-9]", v):
            raise ValueError("Password must contain at least one number (0-9)")
        if not re.search(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;~`]', v):
            raise ValueError("Password must contain at least one special character (!@#$%^&*)")
        return v


class SendOTPRequest(BaseModel):
    identifier: str  # phone or email
    purpose: str = "login"  # "login", "register", "reset_password"


class SendOTPResponse(BaseSchema):
    message: str
    dev_mock_otp: Optional[str] = None


class VerifyOTPRequest(BaseModel):
    identifier: str
    otp: str
    purpose: str = "login"


class AdminCreateUserRequest(BaseModel):
    email: EmailStr
    full_name: str
    password: str
    role_name: str
    phone: Optional[str] = None

    @field_validator("password")
    @classmethod
    def validate_strong_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter (A-Z)")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter (a-z)")
        if not re.search(r"[0-9]", v):
            raise ValueError("Password must contain at least one number (0-9)")
        if not re.search(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;~`]', v):
            raise ValueError("Password must contain at least one special character (!@#$%^&*)")
        return v

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v.strip():
            digits = re.sub(r"\D", "", v)
            if len(digits) == 12 and digits.startswith("91"):
                digits = digits[2:]
            elif len(digits) == 11 and (digits.startswith("0") or digits.startswith("1")):
                digits = digits[1:]
            if len(digits) != 10 and not v.startswith("+1555"):
                raise ValueError("Phone number must be exactly 10 digits")
            return digits
        return None


class AdminUpdateUserStatusRequest(BaseModel):
    is_active: Optional[bool] = None
    unlock: Optional[bool] = None


from app.schemas.user import UserRead
TokenData.model_rebuild()
