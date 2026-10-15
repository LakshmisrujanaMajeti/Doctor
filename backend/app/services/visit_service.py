from datetime import datetime, date
import re
from typing import List, Optional
from sqlalchemy import func, or_
from sqlalchemy.orm import Session
from app.core.exceptions import NotFoundException, BadRequestException
from app.models.visit import OPDVisit, VitalSigns
from app.models.patient import Patient
from app.models.doctor import Doctor
from app.models.department import Department
from app.schemas.visit import OPDVisitCreate, OPDVisitUpdate, VitalSignsCreate
from app.models.audit import AuditLog


class VisitService:
    @staticmethod
    def generate_visit_number(db: Session) -> str:
        today_str = datetime.utcnow().strftime("%d%m%y")
        prefix = f"SMVMCH{today_str}"
        count = db.query(func.count(OPDVisit.id)).filter(OPDVisit.visit_number.like(f"{prefix}%")).scalar() or 0
        return f"{prefix}{str(count + 1).zfill(4)}"

    @staticmethod
    def get_next_queue_token(db: Session, doctor_id: str, visit_date: date) -> int:
        start_of_day = datetime.combine(visit_date, datetime.min.time())
        end_of_day = datetime.combine(visit_date, datetime.max.time())
        max_token = db.query(func.max(OPDVisit.queue_token)).filter(
            OPDVisit.doctor_id == doctor_id,
            OPDVisit.visit_date >= start_of_day,
            OPDVisit.visit_date <= end_of_day
        ).scalar()
        return (max_token or 0) + 1

    @staticmethod
    def create_visit(db: Session, visit_in: OPDVisitCreate, current_user_id: Optional[str] = None) -> OPDVisit:
        # Validate patient, doctor, and department
        patient = db.query(Patient).filter(Patient.id == visit_in.patient_id).first()
        if not patient:
            raise NotFoundException(f"Patient with ID '{visit_in.patient_id}' not found")

        dept = db.query(Department).filter(Department.id == visit_in.department_id).first()
        if not dept:
            dept = db.query(Department).filter(
                (Department.code == visit_in.department_id) |
                (Department.name.ilike(f"%{visit_in.department_id}%"))
            ).first()
        if not dept:
            dept = db.query(Department).filter(Department.is_active == True).first()
        if not dept:
            raise NotFoundException(f"Department with ID '{visit_in.department_id}' not found")

        doctor = db.query(Doctor).filter(Doctor.id == visit_in.doctor_id).first()
        if not doctor:
            doctor = db.query(Doctor).filter(Doctor.department_id == dept.id, Doctor.is_available == True).first()
        if not doctor:
            doctor = db.query(Doctor).filter(Doctor.is_available == True).first()
        if not doctor:
            doctor = db.query(Doctor).first()
        if not doctor:
            raise NotFoundException(f"Doctor with ID '{visit_in.doctor_id}' not found")

        visit_num = VisitService.generate_visit_number(db)
        queue_tok = VisitService.get_next_queue_token(db, doctor.id, datetime.utcnow().date())

        visit = OPDVisit(
            visit_number=visit_num,
            patient_id=visit_in.patient_id,
            doctor_id=doctor.id,
            department_id=dept.id,
            queue_token=queue_tok,
            triage_priority=visit_in.triage_priority,
            consultation_fee=visit_in.consultation_fee,
            status="REGISTERED",
            notes=visit_in.notes,
        )
        db.add(visit)
        db.commit()
        db.refresh(visit)

        db.add(AuditLog(
            user_id=current_user_id,
            action="CREATE_OPD_VISIT",
            entity_type="OPDVisit",
            entity_id=visit.id,
            details_json=f'{{"visit_number": "{visit.visit_number}", "token": {visit.queue_token}}}'
        ))
        db.commit()

        # Real-time Cloud Sync to Supabase
        try:
            from app.services.supabase_sync_service import SupabaseSyncService
            SupabaseSyncService.sync_visit(visit)
        except Exception as se:
            logger.debug(f"Supabase visit sync notice: {se}")

        return visit

    @staticmethod
    def record_vitals(db: Session, vitals_in: VitalSignsCreate, current_user_id: Optional[str] = None) -> VitalSigns:
        visit = db.query(OPDVisit).filter(OPDVisit.id == vitals_in.visit_id).first()
        if not visit:
            raise NotFoundException(f"Visit with ID '{vitals_in.visit_id}' not found")

        # Compute BMI if height and weight present
        bmi_val = None
        if vitals_in.height_cm and vitals_in.weight_kg and vitals_in.height_cm > 0:
            height_m = vitals_in.height_cm / 100.0
            bmi_val = round(vitals_in.weight_kg / (height_m * height_m), 1)

        vitals = db.query(VitalSigns).filter(VitalSigns.visit_id == vitals_in.visit_id).first()
        if vitals:
            # update
            vitals.systolic_bp = vitals_in.systolic_bp
            vitals.diastolic_bp = vitals_in.diastolic_bp
            vitals.pulse_rate = vitals_in.pulse_rate
            vitals.temperature_f = vitals_in.temperature_f
            vitals.spo2_percent = vitals_in.spo2_percent
            vitals.respiratory_rate = vitals_in.respiratory_rate
            vitals.height_cm = vitals_in.height_cm
            vitals.weight_kg = vitals_in.weight_kg
            vitals.bmi = bmi_val or vitals_in.bmi
            vitals.blood_glucose_mg_dl = vitals_in.blood_glucose_mg_dl
            vitals.notes = vitals_in.notes
            vitals.recorded_by_user_id = current_user_id
            vitals.recorded_at = datetime.utcnow()
        else:
            vitals = VitalSigns(
                visit_id=vitals_in.visit_id,
                recorded_by_user_id=current_user_id,
                systolic_bp=vitals_in.systolic_bp,
                diastolic_bp=vitals_in.diastolic_bp,
                pulse_rate=vitals_in.pulse_rate,
                temperature_f=vitals_in.temperature_f,
                spo2_percent=vitals_in.spo2_percent,
                respiratory_rate=vitals_in.respiratory_rate,
                height_cm=vitals_in.height_cm,
                weight_kg=vitals_in.weight_kg,
                bmi=bmi_val or vitals_in.bmi,
                blood_glucose_mg_dl=vitals_in.blood_glucose_mg_dl,
                notes=vitals_in.notes,
            )
            db.add(vitals)

        # Update visit status to TRIAGED if it was REGISTERED
        if visit.status == "REGISTERED":
            visit.status = "TRIAGED"

        db.commit()
        db.refresh(vitals)
        return vitals

    @staticmethod
    def get_visit_by_id(db: Session, visit_id: str) -> OPDVisit:
        visit = db.query(OPDVisit).filter(OPDVisit.id == visit_id).first()
        if not visit:
            raise NotFoundException(f"OPD visit '{visit_id}' not found")
        return visit

    @staticmethod
    def list_visits(
        db: Session,
        doctor_id: Optional[str] = None,
        department_id: Optional[str] = None,
        status: Optional[str] = None,
        patient_id: Optional[str] = None,
        query: Optional[str] = None,
        skip: int = 0,
        limit: int = 50,
    ) -> List[OPDVisit]:
        stmt = db.query(OPDVisit)
        if doctor_id:
            stmt = stmt.filter(OPDVisit.doctor_id == doctor_id)
        if department_id:
            stmt = stmt.filter(OPDVisit.department_id == department_id)
        if status:
            stmt = stmt.filter(OPDVisit.status == status)
        if patient_id:
            stmt = stmt.filter(OPDVisit.patient_id == patient_id)
        if query:
            clean = query.strip()
            pattern = f"%{clean}%"
            conditions = [
                OPDVisit.visit_number.ilike(pattern),
            ]

            # Check if query contains token number (e.g. "1", "#1", "token 1", "tok 2")
            token_num = None
            if clean.lstrip('#').isdigit():
                token_num = int(clean.lstrip('#'))
            else:
                m = re.search(r'\b(?:token|tok|queue)?\s*[:#-]?\s*(\d+)\b', clean, re.IGNORECASE)
                if m:
                    token_num = int(m.group(1))

            if token_num is not None:
                conditions.append(OPDVisit.queue_token == token_num)

            # Match on patient name, UHID, or phone
            matching_patient_ids = [
                p[0] for p in db.query(Patient.id).filter(
                    or_(
                        Patient.full_name.ilike(pattern),
                        Patient.uhid.ilike(pattern),
                        Patient.phone.ilike(pattern),
                        Patient.hospital_reg_num.ilike(pattern),
                    )
                ).all()
            ]
            if matching_patient_ids:
                conditions.append(OPDVisit.patient_id.in_(matching_patient_ids))

            stmt = stmt.filter(or_(*conditions))

        return stmt.order_by(OPDVisit.visit_date.desc(), OPDVisit.queue_token.asc()).offset(skip).limit(limit).all()

    @staticmethod
    def update_visit(
        db: Session,
        visit_id: str,
        update_in: OPDVisitUpdate,
        current_user_id: Optional[str] = None,
    ) -> OPDVisit:
        visit = VisitService.get_visit_by_id(db, visit_id)
        data = update_in.model_dump(exclude_unset=True)
        for k, v in data.items():
            setattr(visit, k, v)
        db.commit()
        db.refresh(visit)
        return visit
