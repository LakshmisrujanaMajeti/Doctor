from datetime import datetime, date
import re
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, Body
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.core.database import get_db
from app.core.responses import success_response
from app.core.dependencies import get_current_user, require_roles, verify_patient_access
from app.core.exceptions import NotFoundException, ForbiddenException, BadRequestException
from app.models.patient import Patient
from app.models.visit import OPDVisit
from app.models.clinical import ClinicalRecord
from app.models.prescription import Prescription
from app.models.laboratory import LabOrder
from app.models.billing import Bill
from app.models.document import MedicalDocument
from app.models.support import SupportTicket
from app.models.user import User, Role
from app.schemas.patient import PatientRead
from app.schemas.portal import (
    PatientDependentCreate,
    DependentProfileItem,
    PatientPortalProfileResponse,
    PatientUpcomingAppointmentItem,
    PatientPrescriptionSummaryItem,
    PatientPrescriptionItemDetail,
    PatientLabReportSummaryItem,
    PatientLabResultDetail,
    PatientBillSummaryItem,
    SupportTicketCreate,
    SupportTicketRead,
    PatientQuickAccessRequest,
    PatientQuickAccessResponse,
    PatientActiveVisitSummary,
    AvailableSlotItem,
    BookSlotRequest,
)
from app.services.patient_service import PatientService
from app.services.audit_service import AuditService
from app.services.document_service import DocumentService
from app.core.security import create_access_token
from sqlalchemy import func

router = APIRouter()


def resolve_patient_by_identifier(db: Session, identifier: str):
    raw = (identifier or "").strip()
    if not raw:
        raise BadRequestException("Please enter your OPD Token Number or Patient UHID.")

    clean_token = raw.lstrip("#").strip()
    patient = None
    active_visit = None
    today_start = datetime.combine(date.today(), datetime.min.time())

    # 1. Exact or partial UHID, Hospital Reg Number, or Barcode match (highest priority for identifiers like C407662)
    patient = db.query(Patient).filter(
        or_(
            Patient.uhid.ilike(raw),
            Patient.hospital_reg_num.ilike(raw),
            Patient.barcode_value.ilike(raw),
            Patient.barcode_value.ilike(f"BAR-{raw}"),
        )
    ).first()

    if not patient and "-" in raw:
        patient = db.query(Patient).filter(
            or_(
                Patient.uhid.ilike(f"%{raw}%"),
                Patient.hospital_reg_num.ilike(f"%{raw}%"),
            )
        ).first()

    # Determine if query is specifically a queue token number (e.g. "1", "#1", "Token 1", "Token #3", "tok 5", "T1")
    token_num = None
    m_token = re.match(r'^(?:token|tok|queue|opd|t|#|\s)*[:#-]?\s*(\d{1,4})$', raw, re.IGNORECASE)
    if m_token:
        token_num = int(m_token.group(1))
    elif clean_token.isdigit() and len(clean_token) <= 4:
        token_num = int(clean_token)

    # 2. Queue token match (handles pure tokens like "1", "Token 1", "#1", "T1")
    if not patient and token_num is not None:
        active_visit = (
            db.query(OPDVisit)
            .filter(OPDVisit.queue_token == token_num, OPDVisit.visit_date >= today_start)
            .order_by(OPDVisit.visit_date.desc())
            .first()
        )
        if not active_visit:
            active_visit = (
                db.query(OPDVisit)
                .filter(OPDVisit.queue_token == token_num)
                .order_by(OPDVisit.visit_date.desc())
                .first()
            )
        if active_visit:
            patient = active_visit.patient or db.query(Patient).filter(Patient.id == active_visit.patient_id).first()

    # 3. Visit Number match (e.g. VIS-20261014-0001 or partial)
    if not patient:
        visit_by_num = db.query(OPDVisit).filter(OPDVisit.visit_number.ilike(f"%{clean_token}%")).first()
        if visit_by_num:
            active_visit = visit_by_num
            patient = visit_by_num.patient or db.query(Patient).filter(Patient.id == visit_by_num.patient_id).first()

    # 4. Phone number match
    if not patient:
        patient = db.query(Patient).filter(Patient.phone == raw).first()

    # 5. ABHA Number match (e.g. 78-6882-8324-4837)
    if not patient:
        patient = db.query(Patient).filter(Patient.abha_number.ilike(raw)).first()
        if not patient and "-" in raw:
            patient = db.query(Patient).filter(Patient.abha_number.ilike(f"%{raw}%")).first()

    # 6. Suffix match for UHID (e.g. "1" -> "UHID-2026-00001")
    if not patient and clean_token.isdigit() and len(clean_token) <= 5:
        suffix = f"{int(clean_token):05d}"
        patient = db.query(Patient).filter(Patient.uhid.ilike(f"%{suffix}")).first()

    # 7. Patient Full Name match
    if not patient and len(raw) >= 3:
        patient = db.query(Patient).filter(Patient.full_name.ilike(f"%{raw}%")).first()

    if not patient:
        raise NotFoundException(
            f"No active patient record or queue token found matching '{raw}'. Please verify your Token # or UHID."
        )

    # Resolve active visit if not set yet
    if not active_visit:
        active_visit = (
            db.query(OPDVisit)
            .filter(OPDVisit.patient_id == patient.id, OPDVisit.visit_date >= today_start)
            .order_by(OPDVisit.visit_date.desc())
            .first()
        )
        if not active_visit:
            active_visit = (
                db.query(OPDVisit)
                .filter(OPDVisit.patient_id == patient.id)
                .order_by(OPDVisit.visit_date.desc())
                .first()
            )

    return patient, active_visit


def get_or_create_patient_user(db: Session, patient: Patient) -> User:
    user = db.query(User).filter(User.patient_id == patient.id).first()
    if not user:
        pat_email = f"patient_{patient.uhid.lower().replace('-', '_')}@opdconnect.local"
        user = db.query(User).filter(User.email == pat_email).first()
        if not user:
            role = db.query(Role).filter(Role.name == "patient").first()
            if not role:
                role = Role(name="patient", description="OPD Patient Portal User")
                db.add(role)
                db.flush()
            user = User(
                email=pat_email,
                hashed_password="TOKEN_QUICK_ACCESS",
                full_name=patient.full_name,
                phone=patient.phone,
                role_id=role.id,
                patient_id=patient.id,
                is_active=True,
                is_verified=True,
            )
            db.add(user)
            db.commit()
            db.refresh(user)
        else:
            user.patient_id = patient.id
            db.commit()
            db.refresh(user)
    return user


@router.post("/quick-access", summary="Patient Token & UHID Quick Check-In (No Password Required)")
def patient_quick_access(
    payload: PatientQuickAccessRequest,
    db: Session = Depends(get_db),
):
    patient, active_visit = resolve_patient_by_identifier(db, payload.identifier)
    user = get_or_create_patient_user(db, patient)

    access_token = create_access_token(
        subject=user.id,
        extra_claims={
            "email": user.email,
            "role": "patient",
            "name": user.full_name,
            "patient_id": patient.id,
            "uhid": patient.uhid,
        }
    )

    visit_summary = None
    if active_visit:
        today_start = datetime.combine(date.today(), datetime.min.time())
        ahead_count = 0
        if active_visit.status in ["REGISTERED", "TRIAGED"]:
            ahead_count = (
                db.query(func.count(OPDVisit.id))
                .filter(
                    OPDVisit.doctor_id == active_visit.doctor_id,
                    OPDVisit.visit_date >= today_start,
                    OPDVisit.status.in_(["REGISTERED", "TRIAGED"]),
                    OPDVisit.queue_token < active_visit.queue_token,
                )
                .scalar()
                or 0
            )

        doc_name = "Attending Physician"
        room_num = "Consultation Room"
        if active_visit.doctor:
            if active_visit.doctor.user:
                doc_name = f"Dr. {active_visit.doctor.user.full_name}"
            room_num = active_visit.doctor.room_number or "Room 101"

        dept_name = active_visit.department.name if active_visit.department else "General OPD"

        visit_summary = PatientActiveVisitSummary(
            id=active_visit.id,
            visit_number=active_visit.visit_number,
            queue_token=active_visit.queue_token,
            status=active_visit.status,
            triage_priority=active_visit.triage_priority,
            doctor_name=doc_name,
            department_name=dept_name,
            room_number=room_num,
            patients_ahead=ahead_count,
            visit_date=active_visit.visit_date.isoformat(),
            payment_status=active_visit.payment_status,
            consultation_fee=active_visit.consultation_fee,
        )

    response_data = PatientQuickAccessResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=86400,
        patient=PatientRead.model_validate(patient),
        active_visit=visit_summary,
    )

    return success_response(
        data=response_data.model_dump(),
        message="Patient authenticated successfully via Token/UHID system",
    )


def _get_authorized_patient_ids(current_user: User, db: Session, target_patient_id: Optional[str] = None) -> List[str]:
    """Resolve authorized patient IDs for the current user.
    If patient role, only their own ID and authorized linked dependents are returned.
    """
    user_role = (current_user.role.name if current_user.role else "").lower()

    if user_role == "patient":
        if not current_user.patient_id:
            raise ForbiddenException("User has no linked patient profile")

        primary_id = current_user.patient_id
        dependents = db.query(Patient.id).filter(Patient.guardian_id == primary_id).all()
        allowed_ids = {primary_id}.union({d[0] for d in dependents})

        if target_patient_id:
            if target_patient_id not in allowed_ids:
                raise ForbiddenException("Access to another patient's medical records is forbidden")
            return [target_patient_id]

        return list(allowed_ids)

    # Clinicians / Staff
    if target_patient_id:
        return [target_patient_id]
    return []


@router.get("/profile", summary="Patient Profile & Permitted Dependents")
def get_patient_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user_role = (current_user.role.name if current_user.role else "").lower()
    if user_role == "patient" and not current_user.patient_id:
        raise NotFoundException("No patient profile linked to this user account")

    patient = current_user.patient or (
        db.query(Patient).filter(Patient.id == current_user.patient_id).first()
        if current_user.patient_id else None
    )
    if not patient:
        raise NotFoundException("Patient record not found")

    # Fetch authorized dependents
    dependents_records = db.query(Patient).filter(Patient.guardian_id == patient.id).all()
    dependents = []
    for dep in dependents_records:
        age_display = f"{dep.age_years} Y" if dep.age_years else (f"{dep.age_months} M" if dep.age_months else "N/A")
        relation = dep.parent_spouse_relation or "Dependent"
        dependents.append(
            DependentProfileItem(
                id=dep.id,
                uhid=dep.uhid,
                full_name=dep.full_name,
                relation=relation,
                gender=dep.gender,
                age_display=age_display,
                blood_group=dep.blood_group,
                registration_date=dep.registration_date,
            )
        )

    # Check for active OPD visit today
    today_start = datetime.combine(date.today(), datetime.min.time())
    active_visit = (
        db.query(OPDVisit)
        .filter(OPDVisit.patient_id == patient.id, OPDVisit.visit_date >= today_start)
        .order_by(OPDVisit.visit_date.desc())
        .first()
    )

    active_token_status_str = None
    if active_visit:
        if active_visit.status in ["COMPLETED", "CANCELLED"]:
            active_token_status_str = "Completed"
        else:
            ahead_count = db.query(func.count(OPDVisit.id)).filter(
                OPDVisit.department_id == active_visit.department_id,
                OPDVisit.visit_date >= today_start,
                OPDVisit.queue_token < active_visit.queue_token,
                OPDVisit.status.in_(["REGISTERED", "TRIAGED", "IN_CONSULTATION"]),
            ).scalar() or 0

            serving_visit = (
                db.query(OPDVisit)
                .filter(
                    OPDVisit.department_id == active_visit.department_id,
                    OPDVisit.visit_date >= today_start,
                    OPDVisit.status.in_(["REGISTERED", "TRIAGED", "IN_CONSULTATION"]),
                )
                .order_by(OPDVisit.queue_token.asc())
                .first()
            )
            serving_token = serving_visit.queue_token if serving_visit else active_visit.queue_token
            if ahead_count == 0:
                active_token_status_str = f"Now Serving #{serving_token} (Your Turn!)"
            else:
                active_token_status_str = f"Serving #{serving_token} • {ahead_count} patient{'s' if ahead_count > 1 else ''} ahead (~{ahead_count * 10} mins)"

    resp = PatientPortalProfileResponse(
        patient=PatientRead.model_validate(patient),
        dependents=dependents,
        has_active_token=active_visit is not None and active_visit.status not in ["COMPLETED", "CANCELLED"],
        active_token_number=f"#{active_visit.queue_token}" if active_visit else None,
        active_token_queue_status=active_token_status_str or (active_visit.status if active_visit else None),
    )
    return success_response(data=resp.model_dump(), message="Patient profile retrieved")


@router.post("/dependents", status_code=201, summary="Register and Link Authorized Dependent Profile")
def add_dependent_profile(
    payload: PatientDependentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user_role = (current_user.role.name if current_user.role else "").lower()
    if user_role == "patient" and not current_user.patient_id:
        raise BadRequestException("User must have an active patient record before adding dependents")

    guardian = current_user.patient
    if not guardian:
        raise NotFoundException("Guardian patient record not found")

    # Generate UHID for dependent
    year = datetime.utcnow().year
    count = db.query(Patient).count() + 1
    dep_uhid = f"UHID-{year}-{count:05d}"
    dep_reg_num = f"REG-{year}-{count:05d}"

    dependent = Patient(
        uhid=dep_uhid,
        hospital_reg_num=dep_reg_num,
        full_name=payload.full_name.strip(),
        parent_spouse_name=guardian.full_name,
        parent_spouse_relation=payload.relation.strip(),
        date_of_birth=payload.date_of_birth,
        age_years=payload.age_years,
        age_months=payload.age_months,
        gender=payload.gender.strip().upper(),
        phone=guardian.phone,  # Inherit guardian phone
        email=guardian.email,
        address=guardian.address,
        city=guardian.city,
        state=guardian.state,
        postal_code=guardian.postal_code,
        blood_group=payload.blood_group,
        emergency_contact_name=guardian.full_name,
        emergency_contact_phone=payload.emergency_contact_phone or guardian.phone,
        emergency_contact_relation=payload.relation.strip(),
        guardian_id=guardian.id,
    )
    db.add(dependent)
    db.commit()
    db.refresh(dependent)

    AuditService.log_event(
        db=db,
        action="DEPENDENT_LINKED",
        entity_type="Patient",
        actor_user_id=current_user.id,
        entity_id=dependent.id,
        details={
            "guardian_uhid": guardian.uhid,
            "dependent_uhid": dependent.uhid,
            "relation": payload.relation,
        },
    )

    age_display = f"{dependent.age_years} Y" if dependent.age_years else "N/A"
    item = DependentProfileItem(
        id=dependent.id,
        uhid=dependent.uhid,
        full_name=dependent.full_name,
        relation=payload.relation,
        gender=dependent.gender,
        age_display=age_display,
        blood_group=dependent.blood_group,
        registration_date=dependent.registration_date,
    )
    return success_response(
        data=item.model_dump(),
        message="Dependent profile registered and linked successfully",
        status_code=201,
    )


@router.get("/dependents", summary="List Permitted Dependent Profiles")
def list_dependent_profiles(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not current_user.patient_id:
        return success_response(data=[], message="No dependents")

    dependents_records = db.query(Patient).filter(Patient.guardian_id == current_user.patient_id).all()
    results = []
    for dep in dependents_records:
        age_display = f"{dep.age_years} Y" if dep.age_years else "N/A"
        results.append(
            DependentProfileItem(
                id=dep.id,
                uhid=dep.uhid,
                full_name=dep.full_name,
                relation=dep.parent_spouse_relation or "Dependent",
                gender=dep.gender,
                age_display=age_display,
                blood_group=dep.blood_group,
                registration_date=dep.registration_date,
            ).model_dump()
        )
    return success_response(data=results, message="Dependents retrieved")


@router.get("/visits", summary="OPD Visit History for Patient or Permitted Dependent")
def get_patient_visits(
    patient_id: Optional[str] = Query(None, description="Optional target patient ID (must be self or dependent)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    auth_patient_ids = _get_authorized_patient_ids(current_user, db, patient_id)
    if not auth_patient_ids:
        return success_response(data=[], message="No authorized visits")

    visits = (
        db.query(OPDVisit)
        .filter(OPDVisit.patient_id.in_(auth_patient_ids))
        .order_by(OPDVisit.visit_date.desc())
        .all()
    )

    data = []
    for v in visits:
        p = v.patient
        d = v.doctor
        dept = v.department
        cr = v.clinical_record
        data.append({
            "id": v.id,
            "visit_number": v.visit_number,
            "patient_id": v.patient_id,
            "patient_name": p.full_name if p else "Patient",
            "patient_uhid": p.uhid if p else "",
            "doctor_name": d.full_name if d else "General Clinician",
            "department_name": dept.name if dept else "General OPD",
            "visit_date": v.visit_date.isoformat(),
            "queue_token": v.queue_token,
            "status": v.status,
            "payment_status": v.payment_status,
            "consultation_fee": v.consultation_fee,
            "diagnosis": cr.final_diagnosis or cr.provisional_diagnosis if cr else None,
            "vitals": {
                "bp": f"{v.vitals.systolic_bp}/{v.vitals.diastolic_bp}" if v.vitals and v.vitals.systolic_bp else None,
                "pulse": v.vitals.pulse_rate if v.vitals else None,
                "temp": v.vitals.temperature_f if v.vitals else None,
                "spo2": v.vitals.spo2_percent if v.vitals else None,
            } if v.vitals else None,
        })
    return success_response(data=data, message="Visit history retrieved")


@router.get("/appointments", summary="Upcoming Appointments & Follow-up Reminders")
def get_patient_appointments(
    patient_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    auth_patient_ids = _get_authorized_patient_ids(current_user, db, patient_id)
    if not auth_patient_ids:
        return success_response(data=[], message="No appointments")

    records = (
        db.query(ClinicalRecord)
        .filter(
            ClinicalRecord.patient_id.in_(auth_patient_ids),
            ClinicalRecord.follow_up_date.isnot(None),
        )
        .order_by(ClinicalRecord.follow_up_date.asc())
        .all()
    )

    appointments = []
    for cr in records:
        v = cr.visit
        doc = cr.doctor
        dept = doc.department if doc else None
        p = cr.patient
        appointments.append(
            PatientUpcomingAppointmentItem(
                visit_id=cr.visit_id,
                visit_number=v.visit_number if v else "",
                doctor_name=doc.full_name if doc else "Attending Clinician",
                department_name=dept.name if dept else "OPD Clinic",
                scheduled_date=str(cr.follow_up_date),
                follow_up_reason=cr.final_diagnosis or cr.provisional_diagnosis or "Review Follow-up",
                care_plan=cr.care_plan,
                is_completed=v.status == "COMPLETED" if v else False,
            ).model_dump()
        )
    return success_response(data=appointments, message="Appointments & reminders retrieved")


@router.get("/prescriptions", summary="Released Prescriptions & Treatment Instructions")
def get_patient_prescriptions(
    patient_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    auth_patient_ids = _get_authorized_patient_ids(current_user, db, patient_id)
    if not auth_patient_ids:
        return success_response(data=[], message="No prescriptions")

    visits = db.query(OPDVisit.id).filter(OPDVisit.patient_id.in_(auth_patient_ids)).all()
    visit_ids = [v[0] for v in visits]

    # Only show authorized prescriptions to patients (hide internal DRAFTs)
    prescriptions = (
        db.query(Prescription)
        .filter(
            Prescription.visit_id.in_(visit_ids),
            Prescription.status.in_(["SIGNED", "AMENDED", "DISPENSED", "PARTIAL"]),
        )
        .order_by(Prescription.signed_at.desc(), Prescription.created_at.desc())
        .all()
    )

    results = []
    for rx in prescriptions:
        v = rx.visit
        doc = rx.signed_by or (rx.doctor.user if (rx.doctor and rx.doctor.user) else None)
        items = [
            PatientPrescriptionItemDetail(
                medicine_name=it.medicine_name,
                form=it.form,
                dosage=it.dosage,
                route=it.route,
                frequency=it.frequency,
                duration_days=it.duration_days,
                quantity=it.quantity,
                timing=it.timing,
                instructions=it.instructions,
                is_dispensed=it.is_dispensed,
            )
            for it in rx.items
        ]
        results.append(
            PatientPrescriptionSummaryItem(
                id=rx.id,
                visit_id=rx.visit_id,
                doctor_name=doc.full_name if doc else "Physician",
                department_name=v.department.name if v and v.department else "Outpatient Clinic",
                status=rx.status,
                signed_at=rx.signed_at,
                notes=rx.notes,
                items=items,
            ).model_dump()
        )
    return success_response(data=results, message="Prescriptions retrieved")


@router.get("/lab-reports", summary="Laboratory Reports Released to Patient")
def get_patient_lab_reports(
    patient_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    auth_patient_ids = _get_authorized_patient_ids(current_user, db, patient_id)
    if not auth_patient_ids:
        return success_response(data=[], message="No lab reports")

    # Only completed and published orders are released to patient portal
    orders = (
        db.query(LabOrder)
        .filter(
            LabOrder.patient_id.in_(auth_patient_ids),
            LabOrder.status == "COMPLETED",
            LabOrder.published_to_visit == True,
        )
        .order_by(LabOrder.completed_at.desc(), LabOrder.ordered_at.desc())
        .all()
    )

    reports = []
    for ord in orders:
        results = [
            PatientLabResultDetail(
                parameter_name=res.parameter_name,
                result_value=res.result_value,
                unit=res.unit,
                reference_range=res.reference_range,
                is_abnormal=res.is_abnormal,
            )
            for res in ord.results
        ]
        reports.append(
            PatientLabReportSummaryItem(
                id=ord.id,
                order_number=ord.order_number,
                test_name=ord.test_name,
                test_category=ord.test_category,
                status=ord.status,
                ordered_at=ord.ordered_at,
                completed_at=ord.completed_at,
                specimen_type=ord.specimen_type,
                is_sensitive=ord.is_sensitive,
                results=results,
            ).model_dump()
        )
    return success_response(data=reports, message="Released lab reports retrieved")


@router.get("/documents", summary="Medical Documents & Downloadable Records")
def get_patient_documents(
    patient_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    auth_patient_ids = _get_authorized_patient_ids(current_user, db, patient_id)
    if not auth_patient_ids:
        return success_response(data=[], message="No documents")

    docs = (
        db.query(MedicalDocument)
        .filter(
            MedicalDocument.patient_id.in_(auth_patient_ids),
            MedicalDocument.is_deleted == False,
        )
        .order_by(MedicalDocument.created_at.desc())
        .all()
    )

    results = []
    for doc in docs:
        signed_token = DocumentService.generate_short_lived_token(doc.id, validity_minutes=15)
        results.append({
            "id": doc.id,
            "patient_id": doc.patient_id,
            "visit_id": doc.visit_id,
            "document_type": doc.document_type,
            "file_name": doc.file_name,
            "file_size_bytes": doc.file_size_bytes,
            "mime_type": doc.mime_type,
            "page_count": doc.page_count,
            "is_verified": doc.is_verified,
            "verification_status": doc.verification_status,
            "preview_url": f"/api/v1/documents/preview/{signed_token}",
            "download_url": f"/api/v1/documents/{doc.id}/download",
            "created_at": doc.created_at.isoformat() if doc.created_at else None,
        })
    return success_response(data=results, message="Medical documents retrieved")


@router.get("/bills", summary="Itemized Bills, Receipts & Payment History")
def get_patient_bills(
    patient_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    auth_patient_ids = _get_authorized_patient_ids(current_user, db, patient_id)
    if not auth_patient_ids:
        return success_response(data=[], message="No bills")

    bills = (
        db.query(Bill)
        .filter(Bill.patient_id.in_(auth_patient_ids))
        .order_by(Bill.billed_at.desc())
        .all()
    )

    results = []
    for b in bills:
        paid_amt = float(b.paid_amount) if b.paid_amount is not None else sum(float(p.amount) for p in b.payments if p.payment_status in ["COMPLETED", "SUCCESS"])
        receipt_num = b.payments[0].receipt_number if b.payments else None
        results.append(
            PatientBillSummaryItem(
                id=b.id,
                invoice_number=b.invoice_number,
                visit_id=b.visit_id,
                total_amount=float(b.total_amount),
                paid_amount=paid_amt,
                discount_amount=float(b.discount_amount),
                payment_status=b.payment_status,
                billed_at=b.billed_at,
                receipt_number=receipt_num,
                items_count=len(b.items),
            ).model_dump()
        )
    return success_response(data=results, message="Bills and payment receipts retrieved")


# ==========================================
# Patient Support & Inquiries Workflow
# ==========================================

@router.post("/support", status_code=201, summary="Submit Support Inquiry or Feedback")
def create_support_ticket(
    payload: SupportTicketCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_pid = payload.dependent_patient_id or current_user.patient_id
    if not target_pid:
        raise BadRequestException("A valid patient profile is required to submit support requests")

    # Verify authorization
    verify_patient_access(patient_id=target_pid, current_user=current_user, db=db)
    patient = db.query(Patient).filter(Patient.id == target_pid).first()
    if not patient:
        raise NotFoundException("Patient record not found")

    ticket = SupportTicket(
        patient_id=target_pid,
        user_id=current_user.id,
        subject=payload.subject.strip(),
        category=payload.category.strip().upper(),
        priority=payload.priority.strip().upper(),
        message=payload.message.strip(),
        status="OPEN",
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)

    AuditService.log_event(
        db=db,
        action="SUPPORT_TICKET_CREATED",
        entity_type="SupportTicket",
        actor_user_id=current_user.id,
        entity_id=ticket.id,
        details={"category": payload.category, "subject": payload.subject},
    )

    read_model = SupportTicketRead(
        id=ticket.id,
        patient_id=ticket.patient_id,
        patient_name=patient.full_name,
        patient_uhid=patient.uhid,
        subject=ticket.subject,
        category=ticket.category,
        priority=ticket.priority,
        message=ticket.message,
        status=ticket.status,
        admin_response=ticket.admin_response,
        resolved_at=ticket.resolved_at,
        created_at=ticket.created_at,
    )
    return success_response(
        data=read_model.model_dump(),
        message="Support inquiry submitted successfully. The hospital desk will review your query.",
        status_code=201,
    )


@router.get("/support", summary="List Support Inquiries for Patient")
def list_patient_support_tickets(
    patient_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    auth_patient_ids = _get_authorized_patient_ids(current_user, db, patient_id)
    if not auth_patient_ids:
        return success_response(data=[], message="No support tickets")

    tickets = (
        db.query(SupportTicket)
        .filter(SupportTicket.patient_id.in_(auth_patient_ids))
        .order_by(SupportTicket.created_at.desc())
        .all()
    )

    results = []
    for t in tickets:
        p = t.patient
        results.append(
            SupportTicketRead(
                id=t.id,
                patient_id=t.patient_id,
                patient_name=p.full_name if p else "Patient",
                patient_uhid=p.uhid if p else "",
                subject=t.subject,
                category=t.category,
                priority=t.priority,
                message=t.message,
                status=t.status,
                admin_response=t.admin_response,
                resolved_at=t.resolved_at,
                created_at=t.created_at,
            ).model_dump()
        )
    return success_response(data=results, message="Support inquiries retrieved")


@router.get("/available-slots", summary="Get Available Appointment Slots for Date")
def get_available_slots(
    department_id: Optional[str] = Query(None),
    doctor_id: Optional[str] = Query(None),
    slot_date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_date = date.today()
    if slot_date:
        try:
            target_date = datetime.strptime(slot_date.strip(), "%Y-%m-%d").date()
        except Exception:
            pass

    standard_slots = [
        "09:00 AM - 09:30 AM",
        "09:30 AM - 10:00 AM",
        "10:00 AM - 10:30 AM",
        "10:30 AM - 11:00 AM",
        "11:00 AM - 11:30 AM",
        "11:30 AM - 12:00 PM",
        "02:00 PM - 02:30 PM",
        "02:30 PM - 03:00 PM",
        "03:00 PM - 03:30 PM",
        "03:30 PM - 04:00 PM",
        "04:00 PM - 04:30 PM",
    ]

    start_of_day = datetime.combine(target_date, datetime.min.time())
    end_of_day = datetime.combine(target_date, datetime.max.time())

    q = db.query(OPDVisit).filter(OPDVisit.visit_date >= start_of_day, OPDVisit.visit_date <= end_of_day)
    if department_id:
        q = q.filter(OPDVisit.department_id == department_id)
    if doctor_id:
        q = q.filter(OPDVisit.doctor_id == doctor_id)
    total_booked = q.count()

    slots = []
    max_cap = 5
    for i, s in enumerate(standard_slots):
        booked = min(max_cap, max(0, total_booked - (i * 2)))
        slots.append(AvailableSlotItem(
            slot_time=s,
            is_available=booked < max_cap,
            booked_count=booked,
            max_capacity=max_cap,
        ))

    return success_response(
        data=[s.model_dump() for s in slots],
        message="Available slots retrieved",
    )


@router.post("/book-slot", status_code=201, summary="Book OPD Appointment Slot by Calendar Selection")
def book_appointment_slot(
    payload: BookSlotRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from app.models.department import Department
    from app.models.doctor import Doctor
    from app.services.visit_service import VisitService

    user_role = (current_user.role.name if current_user.role else "").lower()
    patient_id = payload.patient_id or current_user.patient_id
    if not patient_id:
        raise BadRequestException("Patient profile required to book an appointment")

    if user_role == "patient":
        verify_patient_access(patient_id=patient_id, current_user=current_user, db=db)

    patient = db.query(Patient).filter(Patient.id == patient_id).first()
    if not patient:
        raise NotFoundException(f"Patient with ID '{patient_id}' not found")

    dept = db.query(Department).filter(
        or_(
            Department.id == payload.department_id,
            Department.code == payload.department_id,
            Department.name.ilike(f"%{payload.department_id}%")
        )
    ).first()
    if not dept:
        dept = db.query(Department).filter(Department.is_active == True).first()
    if not dept:
        raise NotFoundException("Department not found")

    doctor = None
    if payload.doctor_id:
        doctor = db.query(Doctor).filter(Doctor.id == payload.doctor_id).first()
    if not doctor:
        doctor = db.query(Doctor).filter(Doctor.department_id == dept.id, Doctor.is_available == True).first()
    if not doctor:
        doctor = db.query(Doctor).first()
    if not doctor:
        raise NotFoundException("No available doctor for consultation")

    try:
        slot_d = datetime.strptime(payload.slot_date.strip(), "%Y-%m-%d").date()
    except Exception:
        slot_d = date.today()

    visit_num = VisitService.generate_visit_number(db)
    queue_tok = VisitService.get_next_queue_token(db, doctor.id, slot_d)

    visit_datetime = datetime.combine(slot_d, datetime.utcnow().time())

    visit = OPDVisit(
        visit_number=visit_num,
        patient_id=patient.id,
        doctor_id=doctor.id,
        department_id=dept.id,
        visit_date=visit_datetime,
        queue_token=queue_tok,
        triage_priority="NORMAL",
        status="REGISTERED",
        consultation_fee=doctor.consultation_fee or 500.0,
        payment_status="UNPAID",
        notes=f"Slot: {payload.slot_time} • Complaint: {payload.chief_complaint or 'OPD Consultation'}",
    )
    db.add(visit)
    db.commit()
    db.refresh(visit)

    AuditService.log_event(
        db=db,
        action="BOOK_APPOINTMENT_SLOT",
        entity_type="OPDVisit",
        actor_user_id=current_user.id,
        entity_id=visit.id,
        details={
            "visit_number": visit.visit_number,
            "slot_time": payload.slot_time,
            "slot_date": payload.slot_date,
            "queue_token": visit.queue_token,
            "department": dept.name,
        },
    )

    return success_response(
        data={
            "visit_id": visit.id,
            "visit_number": visit.visit_number,
            "queue_token": visit.queue_token,
            "department_name": dept.name,
            "doctor_name": doctor.user.full_name if doctor.user else "Consultant",
            "slot_date": payload.slot_date,
            "slot_time": payload.slot_time,
            "status": visit.status,
            "token_display": f"#{visit.queue_token}",
        },
        message="Appointment slot booked successfully and department token generated!",
        status_code=201,
    )
