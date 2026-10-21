import json
from datetime import datetime
from typing import Optional, Dict, Any, List
from sqlalchemy.orm import Session
from sqlalchemy import or_
from app.models.audit import AuditLog

# Keys to sanitize from audit log payloads to prevent recording secrets or confidential narratives
SENSITIVE_KEYS = {
    "password", "hashed_password", "current_password", "new_password",
    "token", "access_token", "refresh_token", "secret", "authorization",
    "otp", "pin", "verification_code",
    "chief_complaint", "clinical_notes", "history_of_present_illness",
    "examination_findings", "provisional_diagnosis", "final_diagnosis",
}


def sanitize_audit_metadata(data: Any) -> Any:
    """Recursively strip passwords, tokens, and clinical narratives from audit payloads."""
    if isinstance(data, dict):
        sanitized = {}
        for k, v in data.items():
            if k.lower() in SENSITIVE_KEYS:
                sanitized[k] = "[REDACTED_FOR_SECURITY]"
            else:
                sanitized[k] = sanitize_audit_metadata(v)
        return sanitized
    elif isinstance(data, list):
        return [sanitize_audit_metadata(item) for item in data]
    else:
        return data


class AuditService:
    @staticmethod
    def log_event(
        db: Session,
        action: str,
        entity_type: str,
        actor_user_id: Optional[str] = None,
        entity_id: Optional[str] = None,
        ip_address: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None,
    ) -> AuditLog:
        """Create a sanitized audit log record."""
        clean_details_json = None
        if details:
            clean_details = sanitize_audit_metadata(details)
            clean_details_json = json.dumps(clean_details)

        log = AuditLog(
            user_id=actor_user_id,
            action=action.upper(),
            entity_type=entity_type,
            entity_id=entity_id,
            ip_address=ip_address,
            details_json=clean_details_json,
        )
        db.add(log)
        db.commit()
        db.refresh(log)
        return log

    @staticmethod
    def search_logs(
        db: Session,
        action: Optional[str] = None,
        entity_type: Optional[str] = None,
        actor_user_id: Optional[str] = None,
        date_from: Optional[str] = None,
        date_to: Optional[str] = None,
        query: Optional[str] = None,
        skip: int = 0,
        limit: int = 50,
    ) -> List[AuditLog]:
        """Search audit records with filters."""
        q = db.query(AuditLog)

        if action and action.strip():
            q = q.filter(AuditLog.action == action.strip().upper())

        if entity_type and entity_type.strip():
            q = q.filter(AuditLog.entity_type == entity_type.strip())

        if actor_user_id and actor_user_id.strip():
            q = q.filter(AuditLog.user_id == actor_user_id.strip())

        if date_from and date_from.strip():
            try:
                dt_from = datetime.strptime(date_from.strip(), "%Y-%m-%d")
                q = q.filter(AuditLog.created_at >= dt_from)
            except ValueError:
                pass

        if date_to and date_to.strip():
            try:
                dt_to = datetime.strptime(date_to.strip(), "%Y-%m-%d")
                dt_to_end = datetime.combine(dt_to.date(), datetime.max.time())
                q = q.filter(AuditLog.created_at <= dt_to_end)
            except ValueError:
                pass

        if query and query.strip():
            term = f"%{query.strip()}%"
            q = q.filter(
                or_(
                    AuditLog.action.ilike(term),
                    AuditLog.entity_type.ilike(term),
                    AuditLog.entity_id.ilike(term),
                    AuditLog.ip_address.ilike(term),
                    AuditLog.details_json.ilike(term),
                )
            )

        return q.order_by(AuditLog.created_at.desc()).offset(skip).limit(limit).all()
