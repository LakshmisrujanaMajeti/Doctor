from typing import Optional
from pydantic import BaseModel, EmailStr, Field
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


class ForgotPasswordRequest(BaseModel):
    identifier: str  # email or phone


class ForgotPasswordResponse(BaseSchema):
    message: str
    dev_mock_token: Optional[str] = None


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str = Field(min_length=6)


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
    password: str = Field(min_length=6)
    role_name: str
    phone: Optional[str] = None


class AdminUpdateUserStatusRequest(BaseModel):
    is_active: Optional[bool] = None
    unlock: Optional[bool] = None


from app.schemas.user import UserRead
TokenData.model_rebuild()
