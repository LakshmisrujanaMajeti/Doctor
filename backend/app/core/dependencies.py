from typing import Optional, List, Callable
from fastapi import Depends, Header
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import decode_token
from app.core.exceptions import UnauthorizedException, ForbiddenException
from app.models.user import User
from app.models.patient import Patient

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login", auto_error=False)


def get_current_user(
    token: Optional[str] = Depends(oauth2_scheme),
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db),
) -> User:
    # Support bearer token from either oauth2_scheme or raw Authorization header
    raw_token = token
    if not raw_token and authorization:
        parts = authorization.split()
        if len(parts) == 2 and parts[0].lower() == "bearer":
            raw_token = parts[1]

    if not raw_token:
        raise UnauthorizedException("Authentication token missing")

    try:
        payload = decode_token(raw_token)
        user_id: str = payload.get("sub")
        token_type: str = payload.get("type")
        if not user_id or token_type != "access":
            raise UnauthorizedException("Invalid token payload")
    except JWTError:
        raise UnauthorizedException("Could not validate credentials or token expired")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise UnauthorizedException("User not found")
    if not user.is_active:
        raise ForbiddenException("User account is inactive")

    return user


def require_roles(allowed_roles: List[str]) -> Callable:
    """Enforce Role-Based Access Control (RBAC). Denies access by default."""
    def role_checker(current_user: User = Depends(get_current_user)) -> User:
        user_role = (current_user.role.name if current_user.role else "").lower()

        # Normalize role aliases (e.g. lab_tech <-> laboratory)
        user_roles_set = {user_role}
        if user_role == "lab_tech":
            user_roles_set.add("laboratory")
        elif user_role == "laboratory":
            user_roles_set.add("lab_tech")

        allowed_set = {r.lower() for r in allowed_roles}

        # Check if user has an authorized role
        # Admin is permitted only if 'admin' is explicitly allowed or for general staff operations
        is_allowed = bool(user_roles_set.intersection(allowed_set)) or ("admin" in user_roles_set and "admin" in allowed_set)

        if not is_allowed:
            raise ForbiddenException(
                f"Access denied. Required role in: {', '.join(allowed_roles)}. Current role: '{user_role}'"
            )
        return current_user

    return role_checker


def verify_patient_access(patient_id: str, current_user: User, db: Session) -> None:
    """Enforce patient privacy: patients may access only their own records and authorized linked dependents."""
    user_role = (current_user.role.name if current_user.role else "").lower()
    if user_role == "patient":
        if current_user.patient_id != patient_id:
            # Check if target patient is a dependent of current user
            is_dependent = (
                db.query(Patient)
                .filter(Patient.id == patient_id, Patient.guardian_id == current_user.patient_id)
                .first()
            )
            if not is_dependent:
                raise ForbiddenException("Access to another patient's medical records is forbidden")


def require_permissions(required_permissions: List[str]) -> Callable:
    """Enforce explicit permission codes.
    Prevents administrators from having unlimited clinical access unless explicitly granted.
    """
    def permission_checker(current_user: User = Depends(get_current_user)) -> User:
        user_role = current_user.role
        if not user_role:
            raise ForbiddenException("User has no assigned role")

        user_perm_codes = {p.code for p in user_role.permissions}
        req_set = set(required_permissions)
        if not user_perm_codes.intersection(req_set):
            raise ForbiddenException(
                f"Access denied. Requires explicit permission in: {', '.join(required_permissions)}"
            )
        return current_user

    return permission_checker

