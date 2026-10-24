from typing import Optional, List
from pydantic import EmailStr, field_validator
from app.schemas.common import BaseSchema
from app.core.validators import validate_person_name, validate_indian_phone


class PermissionRead(BaseSchema):
    id: str
    name: str
    code: str
    description: Optional[str] = None


class RoleRead(BaseSchema):
    id: str
    name: str
    description: Optional[str] = None
    permissions: List[PermissionRead] = []


class UserBase(BaseSchema):
    email: EmailStr
    full_name: str
    phone: Optional[str] = None
    is_active: bool = True
    is_verified: bool = False

    @field_validator("full_name")
    def validate_name(cls, v: str) -> str:
        return validate_person_name(v, "User Name", required=True)

    @field_validator("phone")
    def validate_phone(cls, v: Optional[str]) -> Optional[str]:
        return validate_indian_phone(v, "Phone Number", required=False)


class UserCreate(UserBase):
    password: str
    role_id: Optional[str] = None


class UserRead(UserBase):
    id: str
    patient_id: Optional[str] = None
    role: Optional[RoleRead] = None
