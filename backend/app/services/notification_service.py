from datetime import datetime
from typing import Optional
import logging
from sqlalchemy.orm import Session
from app.models.notification import Notification
from app.models.visit import OPDVisit
from app.models.user import User
from app.models.doctor import Doctor
from app.models.patient import Patient

logger = logging.getLogger(__name__)


class NotificationService:
    @staticmethod
    def notify_consultation_completed(
        db: Session,
        visit: OPDVisit,
        doctor_name: Optional[str] = None,
    ) -> Optional[Notification]:
        """
        Creates an in-app patient notification when a doctor completes a consultation.
        Idempotent: prevents duplicate notifications for the same visit completion.
        """
        try:
            # Check if notification already exists for this visit completion
            existing = db.query(Notification).filter(
                Notification.entity_id == visit.id,
                Notification.category == "consultation",
                Notification.title == "Consultation Completed",
            ).first()
            if existing:
                return existing

            # Resolve doctor name if not provided
            doc_display = doctor_name
            if not doc_display and visit.doctor_id:
                doc = db.query(Doctor).filter(Doctor.id == visit.doctor_id).first()
                if doc:
                    doc_user = db.query(User).filter(User.id == doc.user_id).first()
                    doc_display = doc_user.full_name if doc_user else doc.specialization
            if not doc_display:
                doc_display = "your consulting doctor"

            # Find user linked to the patient
            patient_user = db.query(User).filter(User.patient_id == visit.patient_id).first()
            user_id = patient_user.id if patient_user else None

            notif = Notification(
                user_id=user_id,
                target_role="patient",
                title="Consultation Completed",
                message=f"Your OPD consultation with {doc_display} has concluded. Your prescriptions and digital health booklet are available in your portal.",
                category="consultation",
                priority="NORMAL",
                is_read=False,
                target_route="/patient/portal",
                entity_type="OPDVisit",
                entity_id=visit.id,
            )
            db.add(notif)
            db.commit()
            db.refresh(notif)

            # Sync to Supabase Cloud
            try:
                from app.services.supabase_sync_service import SupabaseSyncService
                SupabaseSyncService.sync_visit(visit)
            except Exception as se:
                logger.debug(f"Cloud sync notice on consultation completion: {se}")

            return notif
        except Exception as e:
            logger.error(f"Error creating consultation completed notification: {e}")
            return None
