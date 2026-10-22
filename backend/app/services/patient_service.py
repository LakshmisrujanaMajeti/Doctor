from datetime import datetime
import re
from typing import List, Optional
from sqlalchemy import or_, func
from sqlalchemy.orm import Session
from app.core.exceptions import NotFoundException, ConflictException
from app.models.patient import Patient
from app.models.user import User
from app.models.visit import OPDVisit
from app.schemas.patient import (
    PatientCreate,
    PatientUpdate,
    DuplicateCandidate,
    DuplicateCheckResponse,
)
from app.models.audit import AuditLog


class PatientService:
    @staticmethod
    def generate_uhid(db: Session) -> str:
        current_year = datetime.utcnow().year
        prefix = f"UHID-{current_year}-"
        count = db.query(func.count(Patient.id)).filter(Patient.uhid.like(f"{prefix}%")).scalar() or 0
        return f"{prefix}{str(count + 1).zfill(5)}"

    @staticmethod
    def generate_hospital_reg_num(db: Session) -> str:
        current_year = datetime.utcnow().year
        prefix = f"REG-{current_year}-"
        count = db.query(func.count(Patient.id)).filter(Patient.hospital_reg_num.like(f"{prefix}%")).scalar() or 0
        return f"{prefix}{str(count + 1).zfill(5)}"

    @staticmethod
    def check_duplicates(
        db: Session,
        phone: str,
        full_name: Optional[str] = None,
        hospital_reg_num: Optional[str] = None,
    ) -> DuplicateCheckResponse:
        candidates: List[DuplicateCandidate] = []
        cleaned_phone = phone.strip()

        # 1. Exact hospital registration number check
        if hospital_reg_num:
            cleaned_reg = hospital_reg_num.strip()
            reg_matches = db.query(Patient).filter(Patient.hospital_reg_num == cleaned_reg).all()
            for p in reg_matches:
                candidates.append(
                    DuplicateCandidate(
                        id=p.id,
                        uhid=p.uhid,
                        hospital_reg_num=p.hospital_reg_num,
                        full_name=p.full_name,
                        phone=p.phone,
                        gender=p.gender,
                        age_years=p.age_years,
                        parent_spouse_name=p.parent_spouse_name,
                        match_reason=f"Identical Hospital Reg No '{p.hospital_reg_num}'",
                    )
                )

        # 2. Phone number match (exact and normalized last 10 digits)
        clean_digits = re.sub(r"\D", "", cleaned_phone)
        last10 = clean_digits[-10:] if len(clean_digits) >= 10 else clean_digits
        phone_matches = db.query(Patient).filter(
            or_(
                Patient.phone == cleaned_phone,
                Patient.phone.like(f"%{last10}"),
            )
        ).all()
        for p in phone_matches:
            if not any(c.id == p.id for c in candidates):
                reason = "Identical Contact Phone Number"
                if full_name and p.full_name.lower().strip() == full_name.lower().strip():
                    reason = "Identical Phone Number and Matching Full Name"
                candidates.append(
                    DuplicateCandidate(
                        id=p.id,
                        uhid=p.uhid,
                        hospital_reg_num=p.hospital_reg_num,
                        full_name=p.full_name,
                        phone=p.phone,
                        gender=p.gender,
                        age_years=p.age_years,
                        parent_spouse_name=p.parent_spouse_name,
                        match_reason=reason,
                    )
                )

        # 3. Exact Name match if provided (and different phone)
        if full_name:
            cleaned_name = full_name.strip()
            name_matches = db.query(Patient).filter(Patient.full_name.ilike(cleaned_name)).all()
            for p in name_matches:
                if not any(c.id == p.id for c in candidates):
                    candidates.append(
                        DuplicateCandidate(
                            id=p.id,
                            uhid=p.uhid,
                            hospital_reg_num=p.hospital_reg_num,
                            full_name=p.full_name,
                            phone=p.phone,
                            gender=p.gender,
                            age_years=p.age_years,
                            parent_spouse_name=p.parent_spouse_name,
                            match_reason="Exact Full Name Match",
                        )
                    )

        is_dup = len(candidates) > 0
        message = (
            f"Found {len(candidates)} potential duplicate patient record(s)."
            if is_dup
            else "No existing duplicate records found."
        )
        return DuplicateCheckResponse(is_duplicate=is_dup, candidates=candidates, message=message)

    @staticmethod
    def create_patient(
        db: Session,
        patient_in: PatientCreate,
        current_user_id: Optional[str] = None,
        prevent_duplicates: bool = True,
    ) -> Patient:
        # Check duplicate hospital reg num if supplied
        if patient_in.hospital_reg_num:
            existing_reg = db.query(Patient).filter(
                Patient.hospital_reg_num == patient_in.hospital_reg_num.strip()
            ).first()
            if existing_reg:
                raise ConflictException(
                    f"A patient with Hospital Registration Number '{patient_in.hospital_reg_num}' already exists (UHID: {existing_reg.uhid})."
                )

        # Prevent duplicate phone number
        if patient_in.phone:
            clean_phone = patient_in.phone.strip()
            clean_digits = re.sub(r"\D", "", clean_phone)
            last10 = clean_digits[-10:] if len(clean_digits) >= 10 else clean_digits
            existing_phone = db.query(Patient).filter(
                or_(
                    Patient.phone == clean_phone,
                    Patient.phone.like(f"%{last10}"),
                )
            ).first()
            if existing_phone:
                raise ConflictException(
                    f"A patient with phone number '{patient_in.phone}' already exists (UHID: {existing_phone.uhid}, Name: {existing_phone.full_name}). Duplicate mobile numbers are strictly not allowed."
                )

        if prevent_duplicates:
            if patient_in.email:
                existing_email = db.query(Patient).filter(Patient.email.ilike(patient_in.email.strip())).first()
                if existing_email:
                    raise ConflictException(
                        f"A patient with email '{patient_in.email}' already exists (UHID: {existing_email.uhid}, Name: {existing_email.full_name}). Duplicate emails are not allowed."
                    )

            dup_check = PatientService.check_duplicates(
                db=db,
                phone=patient_in.phone,
                full_name=patient_in.full_name,
                hospital_reg_num=patient_in.hospital_reg_num,
            )
            for c in dup_check.candidates:
                if "Identical Phone Number and Matching Full Name" in c.match_reason:
                    raise ConflictException(
                        f"Accidental duplicate prevented: Patient '{c.full_name}' with phone '{c.phone}' is already registered under UHID '{c.uhid}'."
                    )

        uhid = PatientService.generate_uhid(db)
        while db.query(Patient).filter(Patient.uhid == uhid).first():
            prefix = f"UHID-{datetime.utcnow().year}-"
            count = db.query(func.count(Patient.id)).filter(Patient.uhid.like(f"{prefix}%")).scalar() or 0
            uhid = f"{prefix}{str(count + 2).zfill(5)}"

        reg_num = patient_in.hospital_reg_num or PatientService.generate_hospital_reg_num(db)
        barcode = patient_in.barcode_value or f"BAR-{uhid}"
        qr_code = patient_in.qr_code_data or f"OPDCONNECT+{uhid}+{reg_num}"

        staff_name = None
        staff_role = None
        if current_user_id:
            staff_user = db.query(User).filter(User.id == current_user_id).first()
            if staff_user:
                staff_name = staff_user.full_name
                staff_role = staff_user.role.name if staff_user.role else None

        now = datetime.utcnow()
        patient = Patient(
            uhid=uhid,
            hospital_reg_num=reg_num,
            full_name=patient_in.full_name.strip(),
            parent_spouse_name=patient_in.parent_spouse_name.strip() if patient_in.parent_spouse_name else None,
            parent_spouse_relation=patient_in.parent_spouse_relation,
            date_of_birth=patient_in.date_of_birth,
            age_years=patient_in.age_years,
            age_months=patient_in.age_months,
            gender=patient_in.gender.upper(),
            phone=patient_in.phone.strip(),
            email=patient_in.email.strip() if patient_in.email else None,
            address=patient_in.address,
            city=patient_in.city,
            state=patient_in.state,
            postal_code=patient_in.postal_code,
            blood_group=patient_in.blood_group,
            abha_number=patient_in.abha_number.strip() if patient_in.abha_number else None,
            registration_date=now,
            created_at=now,
            updated_at=now,
            barcode_value=barcode,
            qr_code_data=qr_code,
            emergency_contact_name=patient_in.emergency_contact_name,
            emergency_contact_phone=patient_in.emergency_contact_phone,
            emergency_contact_relation=patient_in.emergency_contact_relation,
            guardian_id=patient_in.guardian_id,
            registered_by_staff_id=current_user_id,
            registered_by_staff_name=staff_name,
            registered_by_staff_role=staff_role,
        )
        db.add(patient)
        db.commit()
        db.refresh(patient)

        # Automatically issue 1 unique sequential OPD token for this registered patient
        from app.models.department import Department
        from app.models.doctor import Doctor
        from app.services.visit_service import VisitService

        dept = db.query(Department).filter(Department.code == "MED").first() or db.query(Department).filter(Department.is_active == True).first()
        doc = db.query(Doctor).filter(Doctor.department_id == dept.id if dept else None, Doctor.is_available == True).first() or db.query(Doctor).first()

        queue_tok = VisitService.get_next_queue_token(db, now.date())
        visit_num = VisitService.generate_visit_number(db, queue_tok)

        visit = OPDVisit(
            patient_id=patient.id,
            doctor_id=doc.id if doc else "default",
            department_id=dept.id if dept else "default",
            visit_date=now,
            queue_token=queue_tok,
            visit_number=visit_num,
            triage_priority="NORMAL",
            status="WAITING",
            consultation_fee=500.0,
            payment_status="PENDING",
            notes="Initial OPD Registration Visit",
            created_at=now,
            updated_at=now,
        )
        db.add(visit)
        db.commit()
        db.refresh(visit)

        setattr(patient, "current_token", queue_tok)
        setattr(patient, "current_visit_number", visit_num)

        # Audit
        db.add(
            AuditLog(
                user_id=current_user_id,
                action="CREATE_PATIENT",
                entity_type="Patient",
                entity_id=patient.id,
                details_json=f'{{"uhid": "{patient.uhid}", "reg_num": "{patient.hospital_reg_num}", "name": "{patient.full_name}", "token": {queue_tok}}}',
            )
        )
        db.commit()

        # Real-time Cloud Sync to Supabase
        try:
            from app.services.supabase_sync_service import SupabaseSyncService
            SupabaseSyncService.sync_patient(patient)
            SupabaseSyncService.sync_visit(visit)
        except Exception as se:
            logger.debug(f"Supabase sync notice: {se}")

        return patient

    @staticmethod
    def attach_patient_tokens(db: Session, patients: List[Patient]) -> List[Patient]:
        if not patients:
            return patients
        pids = [p.id for p in patients]
        visits = db.query(OPDVisit).filter(OPDVisit.patient_id.in_(pids)).order_by(OPDVisit.visit_date.desc()).all()
        visit_map = {}
        for v in visits:
            if v.patient_id not in visit_map:
                visit_map[v.patient_id] = v
        for p in patients:
            if p.id in visit_map:
                setattr(p, "current_token", visit_map[p.id].queue_token)
                setattr(p, "current_visit_number", visit_map[p.id].visit_number)
        return patients

    @staticmethod
    def get_patient_by_id(db: Session, patient_id: str) -> Patient:
        patient = db.query(Patient).filter(Patient.id == patient_id).first()
        if not patient:
            raise NotFoundException(f"Patient with ID '{patient_id}' not found")
        PatientService.attach_patient_tokens(db, [patient])
        return patient

    @staticmethod
    def get_patient_by_uhid(db: Session, uhid: str) -> Patient:
        patient = db.query(Patient).filter(Patient.uhid == uhid.strip()).first()
        if not patient:
            raise NotFoundException(f"Patient with UHID '{uhid}' not found")
        PatientService.attach_patient_tokens(db, [patient])
        return patient

    @staticmethod
    def get_patient_by_reg_num(db: Session, reg_num: str) -> Patient:
        patient = db.query(Patient).filter(Patient.hospital_reg_num == reg_num.strip()).first()
        if not patient:
            raise NotFoundException(f"Patient with Hospital Registration Number '{reg_num}' not found")
        PatientService.attach_patient_tokens(db, [patient])
        return patient

    @staticmethod
    def get_patient_by_barcode(db: Session, barcode: str) -> Patient:
        patient = db.query(Patient).filter(Patient.barcode_value == barcode.strip()).first()
        if not patient:
            raise NotFoundException(f"Patient with Barcode/QR '{barcode}' not found")
        PatientService.attach_patient_tokens(db, [patient])
        return patient

    @staticmethod
    def list_patients(
        db: Session,
        query: Optional[str] = None,
        skip: int = 0,
        limit: int = 50,
    ) -> List[Patient]:
        stmt = db.query(Patient)
        if query:
            clean = query.strip()
            pattern = f"%{clean}%"
            conditions = [
                Patient.full_name.ilike(pattern),
                Patient.uhid.ilike(pattern),
                Patient.hospital_reg_num.ilike(pattern),
                Patient.barcode_value.ilike(pattern),
                Patient.abha_number.ilike(pattern),
            ]

            # Only match phone substring if query is at least 4 digits (avoids matching all phones when typing token "1")
            if len(clean) >= 4:
                conditions.append(Patient.phone.ilike(pattern))

            # Check if query represents a token number (e.g. "1", "#1", "token 1", "tok 2", "T-3")
            token_num = None
            m_token = re.match(r'^(?:token|tok|queue|opd|t|#|\s)*[:#-]?\s*(\d{1,4})$', clean, re.IGNORECASE)
            if m_token:
                token_num = int(m_token.group(1))
            elif clean.isdigit() and len(clean) <= 4:
                token_num = int(clean)

            if token_num is not None:
                visit_patient_ids = [
                    r[0] for r in db.query(OPDVisit.patient_id)
                    .filter(OPDVisit.queue_token == token_num)
                    .distinct().all()
                ]
                if visit_patient_ids:
                    conditions.append(Patient.id.in_(visit_patient_ids))

            # Also check if query matches visit number (e.g. "VIS-20261014-0001" or "0001")
            visit_by_num_ids = [
                r[0] for r in db.query(OPDVisit.patient_id)
                .filter(OPDVisit.visit_number.ilike(pattern))
                .distinct().all()
            ]
            if visit_by_num_ids:
                conditions.append(Patient.id.in_(visit_by_num_ids))

            stmt = stmt.filter(or_(*conditions))
        results = stmt.order_by(Patient.registration_date.desc()).offset(skip).limit(limit).all()
        return PatientService.attach_patient_tokens(db, results)


    @staticmethod
    def update_patient(
        db: Session,
        patient_id: str,
        update_in: PatientUpdate,
        current_user_id: Optional[str] = None,
    ) -> Patient:
        patient = PatientService.get_patient_by_id(db, patient_id)
        update_data = update_in.model_dump(exclude_unset=True)

        for key, value in update_data.items():
            setattr(patient, key, value)

        db.commit()
        db.refresh(patient)

        db.add(
            AuditLog(
                user_id=current_user_id,
                action="UPDATE_PATIENT",
                entity_type="Patient",
                entity_id=patient.id,
            )
        )
        db.commit()
        return patient

    @staticmethod
    def delete_patient(
        db: Session,
        patient_id: str,
        current_user_id: Optional[str] = None,
    ) -> bool:
        patient = PatientService.get_patient_by_id(db, patient_id)
        from app.models.billing import Bill
        from app.models.clinical import ClinicalRecord
        from app.models.visit import OPDVisit

        db.query(ClinicalRecord).filter(ClinicalRecord.patient_id == patient_id).delete(synchronize_session=False)
        db.query(Bill).filter(Bill.patient_id == patient_id).delete(synchronize_session=False)
        db.query(OPDVisit).filter(OPDVisit.patient_id == patient_id).delete(synchronize_session=False)

        db.delete(patient)
        db.commit()

        if current_user_id:
            db.add(
                AuditLog(
                    user_id=current_user_id,
                    action="DELETE_PATIENT",
                    entity_type="Patient",
                    entity_id=patient_id,
                )
            )
            db.commit()
        return True
