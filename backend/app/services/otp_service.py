import secrets
from datetime import datetime, timedelta
from typing import Optional, Tuple
from sqlalchemy.orm import Session
from app.core.config import settings
from app.core.security import hash_token
from app.core.exceptions import BadRequestException
from app.models.user import OTPVerification
from app.models.audit import AuditLog


class OTPService:
    @staticmethod
    def send_otp(
        db: Session,
        identifier: str,
        purpose: str = "login"
    ) -> Tuple[str, Optional[str]]:
        clean_identifier = identifier.strip().lower()

        # In production, require real OTP provider
        if settings.ENVIRONMENT == "production" and settings.OTP_PROVIDER == "none":
            raise BadRequestException(
                "SMS/OTP delivery provider is not configured in production. "
                "Contact hospital IT administrator to configure Twilio/MSG91."
            )

        if not settings.ENABLE_DEV_MOCK_OTP and settings.OTP_PROVIDER == "none":
            raise BadRequestException("OTP verification service is currently disabled.")

        # Generate a 6-digit OTP
        if settings.ENVIRONMENT != "production" and settings.ENABLE_DEV_MOCK_OTP:
            # Deterministic test code for easy verification, or cryptographically random
            raw_otp = "123456"
        else:
            raw_otp = str(secrets.randbelow(900000) + 100000)

        otp_hash = hash_token(raw_otp)
        expires_at = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)

        otp_entry = OTPVerification(
            identifier=clean_identifier,
            otp_hash=otp_hash,
            expires_at=expires_at,
            is_verified=False,
            attempts=0,
            purpose=purpose,
        )
        db.add(otp_entry)

        # Audit log (NEVER log the raw OTP digits)
        db.add(AuditLog(
            action="OTP_DISPATCHED",
            entity_type="OTPVerification",
            entity_id=clean_identifier,
            details_json=f'{{"purpose": "{purpose}", "delivery": "{settings.OTP_PROVIDER}"}}'
        ))
        db.commit()

        if settings.ENVIRONMENT != "production" and settings.ENABLE_DEV_MOCK_OTP:
            dev_mock_otp = f"[DEV_MOCK_OTP_ONLY] {raw_otp}"
            message = "Development mock OTP dispatched successfully. Disabled in production."
            return message, dev_mock_otp

        return f"OTP has been dispatched to {clean_identifier}", None

    @staticmethod
    def verify_otp(
        db: Session,
        identifier: str,
        otp: str,
        purpose: str = "login"
    ) -> bool:
        clean_identifier = identifier.strip().lower()
        now = datetime.utcnow()

        record = (
            db.query(OTPVerification)
            .filter(
                OTPVerification.identifier == clean_identifier,
                OTPVerification.purpose == purpose,
                OTPVerification.is_verified == False,
                OTPVerification.expires_at > now,
            )
            .order_by(OTPVerification.created_at.desc())
            .first()
        )

        if not record:
            raise BadRequestException("Invalid or expired OTP. Please request a new code.")

        if record.attempts >= 3:
            raise BadRequestException("Maximum OTP verification attempts exceeded. Please request a new code.")

        entered_hash = hash_token(otp.strip())
        if entered_hash != record.otp_hash:
            record.attempts += 1
            db.commit()
            raise BadRequestException("Incorrect OTP. Please check the code and try again.")

        record.is_verified = True
        db.add(AuditLog(
            action="OTP_VERIFIED",
            entity_type="OTPVerification",
            entity_id=clean_identifier,
            details_json=f'{{"purpose": "{purpose}"}}'
        ))
        db.commit()
        return True
