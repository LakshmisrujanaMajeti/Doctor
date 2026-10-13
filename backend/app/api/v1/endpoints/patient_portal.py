from datetime import datetime, date
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
from app.models.user import User
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
)
from app.services.patient_service import PatientService
from app.services.audit_service import AuditService
from app.services.document_service import DocumentService

router = APIRouter()


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

    resp = PatientPortalProfileResponse(
        patient=PatientRead.model_validate(patient),
        dependents=dependents,
        has_active_token=active_visit is not None and active_visit.status not in ["COMPLETED", "CANCELLED"],
        active_token_number=f"#{active_visit.queue_token}" if active_visit else None,
        active_token_queue_status=active_visit.status if active_visit else None,
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
