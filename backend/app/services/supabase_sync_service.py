import json
import logging
from typing import Dict, Any, Optional
import httpx
from sqlalchemy.orm import Session
from app.core.config import settings

from concurrent.futures import ThreadPoolExecutor

logger = logging.getLogger(__name__)

# Background daemon thread pool for non-blocking real-time cloud sync
_sync_pool = ThreadPoolExecutor(max_workers=4, thread_name_prefix="supabase-sync")


class SupabaseSyncService:
    """
    Automated Real-Time Cloud Synchronization Service.
    Syncs hospital registrations, visits, and billing records
    directly to Supabase PostgreSQL via the REST API with Service Role authority.
    Dispatches HTTP sync in non-blocking background threads to ensure sub-15ms local latency.
    """

    @classmethod
    def is_configured(cls) -> bool:
        return bool(settings.SUPABASE_URL and settings.SUPABASE_SERVICE_ROLE_KEY)

    @classmethod
    def _get_headers(cls) -> Dict[str, str]:
        return {
            "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
            "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=representation",
        }

    @classmethod
    def _postgrest_url(cls, table: str) -> str:
        base = settings.SUPABASE_URL.rstrip("/")
        return f"{base}/rest/v1/{table}"

    @classmethod
    def _do_sync(cls, table: str, sanitized_payload: Dict[str, Any]) -> bool:
        """Internal synchronous worker executing inside the thread pool."""
        url = cls._postgrest_url(table)
        headers = cls._get_headers()
        try:
            with httpx.Client(timeout=2.5) as client:
                resp = client.post(url, headers=headers, json=sanitized_payload)
                if resp.status_code in (200, 201, 204):
                    try:
                        logger.info(f"Successfully synced record to Supabase table '{table}'")
                    except Exception:
                        pass
                    return True
                else:
                    return False
        except Exception:
            return False

    @classmethod
    def sync_record(cls, table: str, payload: Dict[str, Any], synchronous: bool = False) -> bool:
        """Upsert a single record into Supabase PostgreSQL table (asynchronous by default)."""
        if not cls.is_configured():
            logger.debug(f"Supabase sync skipped for {table}: Credentials not configured.")
            return False

        # Sanitize datetimes and dates to ISO strings immediately on caller thread
        sanitized = {}
        for k, v in payload.items():
            if hasattr(v, "isoformat"):
                sanitized[k] = v.isoformat()
            else:
                sanitized[k] = v

        if synchronous:
            return cls._do_sync(table, sanitized)

        # Dispatch non-blockingly so the API returns in < 15ms
        _sync_pool.submit(cls._do_sync, table, sanitized)
        return True

    @classmethod
    def sync_patient(cls, patient) -> bool:
        """Sync a registered patient to Supabase."""
        payload = {
            "id": str(patient.id),
            "uhid": patient.uhid,
            "hospital_reg_num": patient.hospital_reg_num,
            "full_name": patient.full_name,
            "parent_spouse_name": patient.parent_spouse_name,
            "parent_spouse_relation": patient.parent_spouse_relation,
            "date_of_birth": patient.date_of_birth,
            "age_years": patient.age_years,
            "age_months": patient.age_months,
            "gender": patient.gender,
            "phone": patient.phone,
            "email": patient.email,
            "address": patient.address,
            "city": patient.city,
            "state": patient.state,
            "postal_code": patient.postal_code,
            "blood_group": patient.blood_group,
            "barcode_value": patient.barcode_value,
            "qr_code_data": patient.qr_code_data,
            "registered_by_staff_id": getattr(patient, "registered_by_staff_id", None),
            "registered_by_staff_name": getattr(patient, "registered_by_staff_name", None),
            "registered_by_staff_role": getattr(patient, "registered_by_staff_role", None),
            "created_at": patient.created_at,
            "updated_at": patient.updated_at,
        }
        return cls.sync_record("patients", payload)

    @classmethod
    def sync_visit(cls, visit) -> bool:
        """Sync an OPD visit to Supabase."""
        payload = {
            "id": str(visit.id),
            "patient_id": str(visit.patient_id),
            "department_id": str(visit.department_id) if visit.department_id else None,
            "doctor_id": str(visit.doctor_id) if visit.doctor_id else None,
            "visit_number": visit.visit_number,
            "queue_token": visit.queue_token,
            "visit_date": visit.visit_date,
            "status": visit.status,
            "triage_priority": visit.triage_priority,
            "notes": visit.notes,
            "consultation_fee": float(visit.consultation_fee) if visit.consultation_fee is not None else 0.0,
            "payment_status": visit.payment_status,
            "created_at": visit.created_at,
            "updated_at": visit.updated_at,
        }
        return cls.sync_record("opd_visits", payload)

    @classmethod
    def sync_bill(cls, bill) -> bool:
        """Sync an invoice to Supabase."""
        payload = {
            "id": str(bill.id),
            "patient_id": str(bill.patient_id),
            "visit_id": str(bill.visit_id) if bill.visit_id else None,
            "bill_number": bill.bill_number,
            "total_amount": float(bill.total_amount) if bill.total_amount is not None else 0.0,
            "payment_status": bill.payment_status,
            "created_at": bill.created_at,
        }
        return cls.sync_record("bills", payload)

    @classmethod
    def sync_all_database_records(cls, db: Session) -> Dict[str, Any]:
        """Bulk synchronizes all local records to Supabase Cloud."""
        from app.models.patient import Patient
        from app.models.visit import OPDVisit
        from app.models.billing import Bill

        results = {
            "patients_synced": 0,
            "visits_synced": 0,
            "bills_synced": 0,
            "configured": cls.is_configured(),
        }

        if not cls.is_configured():
            return results

        patients = db.query(Patient).all()
        for p in patients:
            if cls.sync_patient(p):
                results["patients_synced"] += 1

        visits = db.query(OPDVisit).all()
        for v in visits:
            if cls.sync_visit(v):
                results["visits_synced"] += 1

        bills = db.query(Bill).all()
        for b in bills:
            if cls.sync_bill(b):
                results["bills_synced"] += 1

        return results
