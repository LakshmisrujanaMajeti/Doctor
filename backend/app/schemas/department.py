from typing import Optional
from app.schemas.common import BaseSchema


class DepartmentBase(BaseSchema):
    name: str
    code: str
    description: Optional[str] = None
    is_active: bool = True


class DepartmentCreate(DepartmentBase):
    pass


class DepartmentRead(DepartmentBase):
    id: str
