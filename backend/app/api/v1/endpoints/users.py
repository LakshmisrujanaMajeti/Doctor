from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.responses import success_response
from app.core.dependencies import get_current_user
from app.models.user import User, Role
from app.schemas.user import UserRead, RoleRead

router = APIRouter()


@router.get("", summary="List System Users")
def list_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    users = db.query(User).all()
    return success_response(
        data=[UserRead.model_validate(u).model_dump() for u in users],
        message="Users retrieved successfully"
    )


@router.get("/roles", summary="List System Roles")
def list_roles(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    roles = db.query(Role).all()
    return success_response(
        data=[RoleRead.model_validate(r).model_dump() for r in roles],
        message="Roles retrieved successfully"
    )
