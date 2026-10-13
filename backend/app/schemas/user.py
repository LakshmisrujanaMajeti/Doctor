from typing import Optional, List
from pydantic import EmailStr
from app.schemas.common import BaseSchema


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


class UserCreate(UserBase):
    password: str
    role_id: Optional[str] = None


class UserRead(UserBase):
    id: str
    role: Optional[RoleRead] = None
