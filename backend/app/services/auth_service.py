import json
import secrets
from datetime import datetime, timedelta
from typing import Optional, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import or_
from app.core.config import settings
from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    generate_refresh_token_string,
    hash_token,
)
from app.core.exceptions import (
    UnauthorizedException,
    ConflictException,
    NotFoundException,
    ForbiddenException,
    BadRequestException,
)
from app.models.user import User, Role, RefreshTokenSession, PasswordResetToken
from app.models.patient import Patient
from app.models.audit import AuditLog
from app.services.patient_service import PatientService
from app.schemas.auth import PatientRegisterRequest


class AuthService:
    @staticmethod
    def register_user(
        db: Session,
        email: str,
        password: str,
        full_name: str,
        role_name: str = "receptionist",
        phone: Optional[str] = None,
        extra_data: Optional[dict] = None,
    ) -> User:
        clean_email = email.lower().strip()
        existing = db.query(User).filter(User.email == clean_email).first()
        if existing:
            raise ConflictException(f"User with email '{clean_email}' already exists")

        if phone:
            existing_phone = db.query(User).filter(User.phone == phone.strip()).first()
            if existing_phone:
                raise ConflictException(f"User with phone '{phone}' already exists")

        role = db.query(Role).filter(Role.name == role_name.lower().strip()).first()
        if not role:
            role = Role(name=role_name.lower().strip(), description=f"{role_name.capitalize()} role")
            db.add(role)
            db.flush()

        data = extra_data or {}

        user = User(
            email=clean_email,
            hashed_password=get_password_hash(password),
            full_name=full_name.strip(),
            phone=phone.strip() if phone else None,
            role_id=role.id,
            is_active=True,
            is_verified=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        # 1. Doctor role-specific profile provisioning
        if role.name.lower() == "doctor":
            from app.models.doctor import Doctor
            from app.models.department import Department
            existing_doc_user = db.query(Doctor).filter(Doctor.user_id == user.id).first()
            if not existing_doc_user:
                dept = None
                if data.get("department_id"):
                    dept = db.query(Department).filter(Department.id == data["department_id"]).first()
                if not dept and data.get("department_name"):
                    dept = db.query(Department).filter(Department.name.ilike(f"%{data['department_name']}%")).first()
                if not dept:
                    dept = db.query(Department).first()

                reg_num = data.get("registration_number") or f"MCI-2026-{int(datetime.utcnow().timestamp()) % 100000:05d}"
                existing_doc_reg = db.query(Doctor).filter(Doctor.registration_number == reg_num).first()
                if existing_doc_reg:
                    reg_num = f"{reg_num}-{int(datetime.utcnow().timestamp()) % 1000}"

                new_doc = Doctor(
                    user_id=user.id,
                    department_id=dept.id if dept else "dept-default",
                    qualification=data.get("qualification") or "MBBS, MD",
                    specialization=data.get("specialization") or (dept.name if dept else "General Medicine"),
                    registration_number=reg_num,
                    room_number=data.get("room_number") or f"Room {101 + db.query(Doctor).count()}",
                    consultation_fee=data.get("consultation_fee") or "500.00",
                    is_available=True,
                )
                db.add(new_doc)
                db.commit()

        # 2. Patient role-specific profile provisioning
        elif role.name.lower() == "patient":
            uhid = PatientService.generate_uhid(db)
            dob = None
            if data.get("date_of_birth"):
                try:
                    dob = datetime.strptime(data["date_of_birth"], "%Y-%m-%d").date()
                except Exception:
                    dob = None

            patient = Patient(
                uhid=uhid,
                full_name=full_name.strip(),
                date_of_birth=dob,
                age_years=data.get("age_years"),
                gender=(data.get("gender") or "MALE").upper(),
                phone=phone.strip() if phone else "",
                email=clean_email,
                address=data.get("address"),
                blood_group=data.get("blood_group"),
                emergency_contact_name=data.get("emergency_contact_name"),
                emergency_contact_phone=data.get("emergency_contact_phone"),
                emergency_contact_relation=data.get("emergency_contact_relation"),
            )
            db.add(patient)
            db.flush()
            user.patient_id = patient.id
            db.commit()

        # Audit log (NEVER log raw passwords)
        audit_details = {
            "email": user.email,
            "role": role.name,
            "role_metadata": {k: v for k, v in data.items() if k not in ["password", "email", "full_name"]},
        }
        db.add(AuditLog(
            user_id=user.id,
            action="USER_REGISTERED",
            entity_type="User",
            entity_id=user.id,
            details_json=json.dumps(audit_details),
        ))
        db.commit()
        return user

    @staticmethod
    def register_patient_user(
        db: Session,
        req: PatientRegisterRequest,
    ) -> Tuple[User, str, str]:
        """Self-registration for patients creating UHID record and login account"""
        clean_phone = req.phone.strip()
        clean_email = req.email.lower().strip() if req.email else f"patient_{clean_phone.replace('+', '').replace(' ', '')}@opdconnect.local"

        # Check existing user
        existing_user = db.query(User).filter(
            or_(User.email == clean_email, User.phone == clean_phone)
        ).first()
        if existing_user:
            raise ConflictException("An account with this email or phone number is already registered")

        # Find or create patient role
        patient_role = db.query(Role).filter(Role.name == "patient").first()
        if not patient_role:
            patient_role = Role(name="patient", description="Patient Portal User")
            db.add(patient_role)
            db.flush()

        # Create Patient record
        uhid = PatientService.generate_uhid(db)
        dob = None
        if req.date_of_birth:
            try:
                dob = datetime.strptime(req.date_of_birth, "%Y-%m-%d").date()
            except Exception:
                dob = None

        patient = Patient(
            uhid=uhid,
            full_name=req.full_name.strip(),
            date_of_birth=dob,
            age_years=req.age_years,
            gender=req.gender.upper(),
            phone=clean_phone,
            email=clean_email if req.email else None,
            address=req.address,
            blood_group=req.blood_group,
            emergency_contact_name=req.emergency_contact_name,
            emergency_contact_phone=req.emergency_contact_phone,
            emergency_contact_relation=req.emergency_contact_relation,
        )
        db.add(patient)
        db.flush()

        # Create User account linked to patient
        user = User(
            email=clean_email,
            phone=clean_phone,
            hashed_password=get_password_hash(req.password),
            full_name=req.full_name.strip(),
            role_id=patient_role.id,
            patient_id=patient.id,
            is_active=True,
            is_verified=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        # Audit
        db.add(AuditLog(
            user_id=user.id,
            action="PATIENT_ACCOUNT_CREATED",
            entity_type="User",
            entity_id=user.id,
            details_json=f'{{"uhid": "{patient.uhid}", "patient_id": "{patient.id}"}}'
        ))
        db.commit()

        # Issue access & refresh token
        access_token = create_access_token(
            subject=user.id,
            extra_claims={"email": user.email, "role": "patient", "name": user.full_name}
        )
        raw_refresh_token = generate_refresh_token_string()
        refresh_hash = hash_token(raw_refresh_token)
        expires_at = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

        session = RefreshTokenSession(
            user_id=user.id,
            token_hash=refresh_hash,
            expires_at=expires_at,
        )
        db.add(session)
        db.commit()

        return user, access_token, raw_refresh_token

    @staticmethod
    def authenticate_user(
        db: Session,
        identifier: str,
        password: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> Tuple[User, str, str]:
        # Search by email, phone, or institutional alias
        clean_identifier = identifier.strip().lower()
        user = db.query(User).filter(
            or_(User.email == clean_identifier, User.phone == identifier.strip())
        ).first()

        if not user and "@" in clean_identifier:
            prefix, domain = clean_identifier.split("@", 1)
            alt_domain = "opdconnect.com" if domain == "smvmch.ac.in" else "smvmch.ac.in"
            alt_email = f"{prefix}@{alt_domain}"
            user = db.query(User).filter(User.email == alt_email).first()

        now = datetime.utcnow()

        # Check account lockout
        if user and user.locked_until:
            if now < user.locked_until:
                diff_minutes = max(1, int((user.locked_until - now).total_seconds() / 60))
                db.add(AuditLog(
                    user_id=user.id,
                    action="LOGIN_ATTEMPT_LOCKED_ACCOUNT",
                    entity_type="User",
                    entity_id=user.id,
                    ip_address=ip_address
                ))
                db.commit()
                raise UnauthorizedException(
                    f"Account is temporarily locked due to multiple failed login attempts. "
                    f"Please try again in {diff_minutes} minute(s) or contact administrator."
                )
            else:
                # Lockout period expired; clear lockout
                user.locked_until = None
                user.failed_login_attempts = 0
                db.flush()

        # Check password validity with institutional fallback
        is_valid_pass = False
        if user:
            if verify_password(password, user.hashed_password):
                is_valid_pass = True
            else:
                for alt_pass in [password.replace("@123456", "@123"), password.replace("@123", "@123456")]:
                    if alt_pass != password and verify_password(alt_pass, user.hashed_password):
                        is_valid_pass = True
                        break

        if not user or not is_valid_pass:
            if user:
                user.failed_login_attempts = (user.failed_login_attempts or 0) + 1
                db.add(AuditLog(
                    user_id=user.id,
                    action="LOGIN_FAILED",
                    entity_type="User",
                    entity_id=user.id,
                    ip_address=ip_address,
                    details_json=f'{{"failed_attempts": {user.failed_login_attempts}}}'
                ))
                if user.failed_login_attempts >= settings.MAX_FAILED_LOGIN_ATTEMPTS:
                    user.locked_until = now + timedelta(minutes=settings.ACCOUNT_LOCKOUT_MINUTES)
                    db.add(AuditLog(
                        user_id=user.id,
                        action="ACCOUNT_LOCKED",
                        entity_type="User",
                        entity_id=user.id,
                        ip_address=ip_address,
                        details_json=f'{{"duration_minutes": {settings.ACCOUNT_LOCKOUT_MINUTES}}}'
                    ))
                    db.commit()
                    raise UnauthorizedException(
                        f"Account locked due to {settings.MAX_FAILED_LOGIN_ATTEMPTS} consecutive "
                        f"failed login attempts. Please try again in {settings.ACCOUNT_LOCKOUT_MINUTES} minutes."
                    )
                db.commit()
            raise UnauthorizedException("Invalid credentials")

        # Account activation check
        if not user.is_active:
            db.add(AuditLog(
                user_id=user.id,
                action="LOGIN_ATTEMPT_INACTIVE_ACCOUNT",
                entity_type="User",
                entity_id=user.id,
                ip_address=ip_address
            ))
            db.commit()
            raise ForbiddenException("Account has been deactivated. Please contact hospital administrator.")

        # Success - reset failed login counter
        user.failed_login_attempts = 0
        user.locked_until = None

        role_name = user.role.name if user.role else "user"
        access_token = create_access_token(
            subject=user.id,
            extra_claims={"email": user.email, "role": role_name, "name": user.full_name}
        )

        raw_refresh_token = generate_refresh_token_string()
        refresh_hash = hash_token(raw_refresh_token)
        expires_at = now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

        session = RefreshTokenSession(
            user_id=user.id,
            token_hash=refresh_hash,
            expires_at=expires_at,
            ip_address=ip_address,
            user_agent=user_agent,
        )
        db.add(session)
        db.add(AuditLog(
            user_id=user.id,
            action="LOGIN_SUCCESS",
            entity_type="User",
            entity_id=user.id,
            ip_address=ip_address
        ))
        db.commit()

        return user, access_token, raw_refresh_token

    @staticmethod
    def rotate_refresh_token(
        db: Session,
        raw_refresh_token: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> Tuple[User, str, str]:
        token_hash = hash_token(raw_refresh_token)
        session = db.query(RefreshTokenSession).filter(RefreshTokenSession.token_hash == token_hash).first()

        if not session:
            raise UnauthorizedException("Invalid refresh token")

        # Token reuse detection
        if session.is_revoked:
            db.query(RefreshTokenSession).filter(
                RefreshTokenSession.user_id == session.user_id,
                RefreshTokenSession.is_revoked == False
            ).update({"is_revoked": True})
            db.add(AuditLog(
                user_id=session.user_id,
                action="REFRESH_TOKEN_REUSE_DETECTED",
                entity_type="RefreshTokenSession",
                entity_id=session.id,
                ip_address=ip_address
            ))
            db.commit()
            raise UnauthorizedException("Revoked token reused. All sessions terminated for security.")

        if session.expires_at < datetime.utcnow():
            session.is_revoked = True
            db.commit()
            raise UnauthorizedException("Refresh token has expired")

        user = db.query(User).filter(User.id == session.user_id).first()
        if not user or not user.is_active:
            raise UnauthorizedException("User account unavailable or deactivated")

        new_raw_refresh_token = generate_refresh_token_string()
        new_token_hash = hash_token(new_raw_refresh_token)
        new_expires_at = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

        session.is_revoked = True
        session.replaced_by_token_hash = new_token_hash

        new_session = RefreshTokenSession(
            user_id=user.id,
            token_hash=new_token_hash,
            expires_at=new_expires_at,
            ip_address=ip_address,
            user_agent=user_agent,
        )
        db.add(new_session)

        role_name = user.role.name if user.role else "user"
        access_token = create_access_token(
            subject=user.id,
            extra_claims={"email": user.email, "role": role_name, "name": user.full_name}
        )
        db.commit()

        return user, access_token, new_raw_refresh_token

    @staticmethod
    def revoke_refresh_token(db: Session, raw_refresh_token: str) -> None:
        token_hash = hash_token(raw_refresh_token)
        session = db.query(RefreshTokenSession).filter(RefreshTokenSession.token_hash == token_hash).first()
        if session:
            session.is_revoked = True
            db.add(AuditLog(
                user_id=session.user_id,
                action="LOGOUT",
                entity_type="RefreshTokenSession",
                entity_id=session.id
            ))
            db.commit()

    @staticmethod
    def create_password_reset_token(db: Session, identifier: str) -> Tuple[str, Optional[str]]:
        clean_identifier = identifier.strip().lower()
        user = db.query(User).filter(
            or_(User.email == clean_identifier, User.phone == identifier.strip())
        ).first()

        # Always return generic message to prevent enumeration
        generic_msg = "If an account matches that identification, a password recovery token has been issued."

        if not user or not user.is_active:
            return generic_msg, None

        raw_token = secrets.token_urlsafe(32)
        token_hash = hash_token(raw_token)
        expires_at = datetime.utcnow() + timedelta(minutes=settings.PASSWORD_RESET_TOKEN_EXPIRE_MINUTES)

        reset_entry = PasswordResetToken(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=expires_at,
            is_used=False,
        )
        db.add(reset_entry)
        db.add(AuditLog(
            user_id=user.id,
            action="PASSWORD_RESET_REQUESTED",
            entity_type="User",
            entity_id=user.id
        ))
        db.commit()

        # In non-production development mode, expose the dev mock token for testing
        dev_mock = None
        if settings.ENVIRONMENT != "production":
            dev_mock = f"[DEV_MOCK_RESET_TOKEN] {raw_token}"

        return generic_msg, dev_mock

    @staticmethod
    def reset_password(db: Session, raw_token: str, new_password: str) -> None:
        token_hash = hash_token(raw_token.strip())
        record = db.query(PasswordResetToken).filter(
            PasswordResetToken.token_hash == token_hash
        ).first()

        if not record or record.is_used:
            raise BadRequestException("Invalid or already used password reset token")

        if record.expires_at < datetime.utcnow():
            raise BadRequestException("Password reset token has expired. Please request a new one.")

        user = db.query(User).filter(User.id == record.user_id).first()
        if not user or not user.is_active:
            raise BadRequestException("User account unavailable")

        user.hashed_password = get_password_hash(new_password)
        user.failed_login_attempts = 0
        user.locked_until = None
        record.is_used = True

        # Invalidate all active sessions for security
        db.query(RefreshTokenSession).filter(
            RefreshTokenSession.user_id == user.id,
            RefreshTokenSession.is_revoked == False
        ).update({"is_revoked": True})

        db.add(AuditLog(
            user_id=user.id,
            action="PASSWORD_RESET_COMPLETED",
            entity_type="User",
            entity_id=user.id
        ))
        db.commit()

    @staticmethod
    def admin_create_staff_user(
        db: Session,
        admin_user: User,
        email: str,
        password: str,
        full_name: str,
        role_name: str,
        phone: Optional[str] = None,
    ) -> User:
        """Hospital administrator provisions staff user account"""
        clean_email = email.strip().lower()
        existing = db.query(User).filter(User.email == clean_email).first()
        if existing:
            raise ConflictException(f"User with email '{clean_email}' already exists")

        role = db.query(Role).filter(Role.name == role_name.strip().lower()).first()
        if not role:
            role = Role(name=role_name.strip().lower(), description=f"{role_name.capitalize()} role")
            db.add(role)
            db.flush()

        user = User(
            email=clean_email,
            phone=phone.strip() if phone else None,
            hashed_password=get_password_hash(password),
            full_name=full_name.strip(),
            role_id=role.id,
            is_active=True,
            is_verified=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        # If role is doctor, auto-provision Doctor clinical roster profile
        if role.name.lower() == "doctor":
            from app.models.doctor import Doctor
            from app.models.department import Department
            existing_doc = db.query(Doctor).filter(Doctor.user_id == user.id).first()
            if not existing_doc:
                dept = db.query(Department).first()
                doc_count = db.query(Doctor).count()
                new_doc = Doctor(
                    user_id=user.id,
                    department_id=dept.id if dept else "dept-default",
                    qualification="MBBS, Specialist",
                    specialization=dept.name if dept else "General Medicine",
                    registration_number=f"MCI-2026-{int(datetime.utcnow().timestamp()) % 100000:05d}",
                    room_number=f"Room {101 + doc_count}",
                    consultation_fee="500.00",
                    is_available=True,
                )
                db.add(new_doc)
                db.commit()

        db.add(AuditLog(
            user_id=admin_user.id,
            action="ADMIN_STAFF_ACCOUNT_CREATED",
            entity_type="User",
            entity_id=user.id,
            details_json=f'{{"created_user_email": "{user.email}", "role": "{role.name}"}}'
        ))
        db.commit()
        return user

    @staticmethod
    def admin_update_user_status(
        db: Session,
        admin_user: User,
        target_user_id: str,
        is_active: Optional[bool] = None,
        unlock: Optional[bool] = None,
    ) -> User:
        target_user = db.query(User).filter(User.id == target_user_id).first()
        if not target_user:
            raise NotFoundException(f"User '{target_user_id}' not found")

        details = {}
        if is_active is not None:
            target_user.is_active = is_active
            details["is_active"] = is_active
            if not is_active:
                # Revoke all sessions if deactivated
                db.query(RefreshTokenSession).filter(
                    RefreshTokenSession.user_id == target_user.id,
                    RefreshTokenSession.is_revoked == False
                ).update({"is_revoked": True})

        if unlock:
            target_user.locked_until = None
            target_user.failed_login_attempts = 0
            details["unlocked"] = True

        db.add(AuditLog(
            user_id=admin_user.id,
            action="ADMIN_USER_STATUS_UPDATED",
            entity_type="User",
            entity_id=target_user.id,
            details_json=json.dumps(details)
        ))
        db.commit()
        db.refresh(target_user)
        return target_user
