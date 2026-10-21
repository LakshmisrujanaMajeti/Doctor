from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.responses import success_response
from app.core.dependencies import get_current_user
from app.models.department import Department
from app.schemas.department import DepartmentCreate, DepartmentRead
from app.models.user import User

router = APIRouter()


@router.get("", summary="List Departments")
def list_departments(db: Session = Depends(get_db)):
    departments = db.query(Department).filter(Department.is_active == True).all()
    return success_response(
        data=[DepartmentRead.model_validate(d).model_dump() for d in departments],
        message="Departments retrieved successfully"
    )


@router.post("", summary="Create Department")
def create_department(
    dept_in: DepartmentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    dept = Department(
        name=dept_in.name,
        code=dept_in.code.upper(),
        description=dept_in.description,
        is_active=dept_in.is_active,
    )
    db.add(dept)
    db.commit()
    db.refresh(dept)
    return success_response(
        data=DepartmentRead.model_validate(dept).model_dump(),
        message="Department created successfully",
        status_code=201
    )
