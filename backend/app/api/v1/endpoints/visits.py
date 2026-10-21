from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.responses import success_response
from app.core.dependencies import get_current_user, require_roles, verify_patient_access
from app.core.exceptions import ForbiddenException
from app.schemas.visit import (
    OPDVisitCreate,
    OPDVisitUpdate,
    OPDVisitRead,
    VitalSignsCreate,
    VitalSignsRead,
)
from app.services.visit_service import VisitService
from app.models.visit import OPDVisit, VitalSigns
from app.models.user import User

router = APIRouter()


@router.get("", summary="List OPD Visits / Daily Queue")
def list_visits(
    doctor_id: Optional[str] = Query(None),
    department_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    patient_id: Optional[str] = Query(None),
    query: Optional[str] = Query(None, description="Search by Token #, UHID, Patient Name, Phone, or Visit #"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user_role = (current_user.role.name if current_user.role else "").lower()

    if user_role == "patient":
        # Force filter to only own visits or linked dependents
        if not current_user.patient_id:
            return success_response(data=[], message="No visits found for user")
        patient_id = current_user.patient_id
    elif user_role == "doctor":
        from app.models.doctor import Doctor
        doctor = db.query(Doctor).filter(Doctor.user_id == current_user.id).first()
        if doctor:
            doctor_id = doctor.id

    visits = VisitService.list_visits(
        db=db,
        doctor_id=doctor_id,
        department_id=department_id,
        status=status,
        patient_id=patient_id,
        query=query,
        skip=skip,
        limit=limit,
    )
    return success_response(
        data=[OPDVisitRead.model_validate(v).model_dump() for v in visits],
        message="OPD visits retrieved successfully"
    )


@router.post("", summary="Create OPD Visit & Issue Token (Receptionist/Doctor/Admin/Patient)")
def create_visit(
    visit_in: OPDVisitCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user_role = (current_user.role.name if current_user.role else "").lower()
    if user_role == "patient":
        # Patient can only book for self or dependent
        verify_patient_access(patient_id=visit_in.patient_id, current_user=current_user, db=db)
    elif user_role not in ["receptionist", "doctor", "admin"]:
        require_roles(["receptionist", "doctor", "admin"])(current_user)

    visit = VisitService.create_visit(db=db, visit_in=visit_in, current_user_id=current_user.id)
    return success_response(
        data=OPDVisitRead.model_validate(visit).model_dump(),
        message="OPD visit booked and token generated",
        status_code=201
    )


@router.get("/{visit_id}", summary="Get Visit Details")
def get_visit(
    visit_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    visit = VisitService.get_visit_by_id(db, visit_id)
    user_role = (current_user.role.name if current_user.role else "").lower()
    if user_role == "patient":
        verify_patient_access(patient_id=visit.patient_id, current_user=current_user, db=db)
    elif user_role == "doctor":
        from app.models.doctor import Doctor
        doctor = db.query(Doctor).filter(Doctor.user_id == current_user.id).first()
        if doctor and visit.doctor_id and visit.doctor_id != doctor.id and visit.department_id != doctor.department_id:
            raise ForbiddenException("Access restricted. This patient is assigned to a different consulting doctor/department.")

    return success_response(
        data=OPDVisitRead.model_validate(visit).model_dump(),
        message="Visit details retrieved"
    )


@router.patch("/{visit_id}", summary="Update Visit Status or Priority (Staff Only)")
def update_visit(
    visit_id: str,
    update_in: OPDVisitUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["receptionist", "nurse", "doctor", "admin"])),
):
    visit = VisitService.update_visit(db, visit_id, update_in, current_user_id=current_user.id)
    return success_response(
        data=OPDVisitRead.model_validate(visit).model_dump(),
        message="Visit updated successfully"
    )


@router.post("/{visit_id}/vitals", summary="Record Visit Vital Signs & Triage (Nurse/Doctor/Admin)")
def record_vitals(
    visit_id: str,
    vitals_in: VitalSignsCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["nurse", "doctor", "admin"])),
):
    vitals_in.visit_id = visit_id
    vitals = VisitService.record_vitals(db, vitals_in, current_user_id=current_user.id)
    return success_response(
        data=VitalSignsRead.model_validate(vitals).model_dump(),
        message="Vitals saved successfully and visit triaged"
    )


@router.get("/{visit_id}/consultation-context", summary="Get Authorized Patient Consultation Context (Doctor/Admin)")
def get_consultation_context(
    visit_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from app.models.clinical import ClinicalRecord
    from app.models.laboratory import LabOrder
    from app.models.prescription import Prescription
    from app.schemas.clinical import ClinicalRecordRead
    from app.schemas.visit import (
        ConsultationContextRead,
        PreviousVisitSummary,
        PatientMedicalHistorySummary,
    )

    visit = VisitService.get_visit_by_id(db, visit_id)
    user_role = (current_user.role.name if current_user.role else "").lower()

    if user_role == "patient":
        verify_patient_access(patient_id=visit.patient_id, current_user=current_user, db=db)
    elif user_role == "doctor":
        from app.models.doctor import Doctor
        doctor = db.query(Doctor).filter(Doctor.user_id == current_user.id).first()
        if doctor and visit.doctor_id and visit.doctor_id != doctor.id and visit.department_id != doctor.department_id:
            raise ForbiddenException("Access restricted. This patient is assigned to a different consulting doctor/department.")
    elif user_role not in ["doctor", "admin", "nurse"]:
        raise ForbiddenException("Access to consultation clinical records is restricted to doctors and clinical staff")

    # If doctor opens a visit in queue, transition status to IN_CONSULTATION if currently REGISTERED or TRIAGED
    if user_role in ["doctor", "admin"] and visit.status in ["REGISTERED", "TRIAGED"]:
        visit.status = "IN_CONSULTATION"
        db.commit()
        db.refresh(visit)

    patient = visit.patient

    # Previous visits
    past_visits = (
        db.query(OPDVisit)
        .filter(OPDVisit.patient_id == patient.id, OPDVisit.id != visit.id)
        .order_by(OPDVisit.visit_date.desc())
        .limit(10)
        .all()
    )

    prev_visit_summaries = []
    for pv in past_visits:
        cr = db.query(ClinicalRecord).filter(ClinicalRecord.visit_id == pv.id).first()
        prev_visit_summaries.append(
            PreviousVisitSummary(
                id=pv.id,
                visit_number=pv.visit_number,
                visit_date=pv.visit_date,
                doctor_name=pv.doctor.user.full_name if (pv.doctor and pv.doctor.user) else "Doctor",
                department_name=pv.department.name if pv.department else None,
                provisional_diagnosis=cr.provisional_diagnosis if cr else None,
                final_diagnosis=cr.final_diagnosis if cr else None,
                chief_complaint=cr.presenting_complaint if cr else None,
                status=pv.status,
            )
        )

    # Aggregate Medical History from recent records or patient profile
    recent_crs = (
        db.query(ClinicalRecord)
        .filter(ClinicalRecord.patient_id == patient.id)
        .order_by(ClinicalRecord.created_at.desc())
        .all()
    )

    med_hist = PatientMedicalHistorySummary()
    for cr in recent_crs:
        if not med_hist.allergies and cr.allergies:
            med_hist.allergies = cr.allergies
        if not med_hist.past_medical_history and cr.past_medical_history:
            med_hist.past_medical_history = cr.past_medical_history
        if not med_hist.prior_hospitalization and cr.prior_hospitalization:
            med_hist.prior_hospitalization = cr.prior_hospitalization
        if not med_hist.hypertension_history and cr.hypertension_history:
            med_hist.hypertension_history = cr.hypertension_history
        if not med_hist.diabetes_history and cr.diabetes_history:
            med_hist.diabetes_history = cr.diabetes_history
        if not med_hist.asthma_history and cr.asthma_history:
            med_hist.asthma_history = cr.asthma_history
        if not med_hist.tuberculosis_history and cr.tuberculosis_history:
            med_hist.tuberculosis_history = cr.tuberculosis_history
        if not med_hist.smoking_history and cr.smoking_history:
            med_hist.smoking_history = cr.smoking_history
        if not med_hist.alcohol_history and cr.alcohol_history:
            med_hist.alcohol_history = cr.alcohol_history
        if not med_hist.family_history and cr.family_history:
            med_hist.family_history = cr.family_history

    # Available investigation results (lab orders + lab results)
    patient_labs = (
        db.query(LabOrder)
        .filter(LabOrder.patient_id == patient.id)
        .order_by(LabOrder.created_at.desc())
        .limit(20)
        .all()
    )

    available_investigations = []
    for lo in patient_labs:
        results_data = []
        for res in lo.results:
            results_data.append({
                "id": res.id,
                "parameter_name": res.parameter_name,
                "result_value": res.result_value,
                "unit": res.unit,
                "reference_range": res.reference_range,
                "is_abnormal": res.is_abnormal,
                "notes": res.notes,
                "reported_at": res.reported_at.isoformat() if res.reported_at else None,
            })
        available_investigations.append({
            "id": lo.id,
            "test_name": lo.test_name,
            "test_category": lo.test_category,
            "status": lo.status,
            "clinical_indication": lo.clinical_indication,
            "created_at": lo.created_at.isoformat() if lo.created_at else None,
            "visit_id": lo.visit_id,
            "results": results_data,
        })

    # Active / previous prescriptions
    patient_rxs = (
        db.query(Prescription)
        .filter(Prescription.patient_id == patient.id)
        .order_by(Prescription.created_at.desc())
        .limit(10)
        .all()
    )

    active_prescriptions = []
    for rx in patient_rxs:
        items_data = []
        for item in rx.items:
            items_data.append({
                "id": item.id,
                "medicine_name": item.medicine_name,
                "form": item.form,
                "dosage": item.dosage,
                "route": item.route,
                "frequency": item.frequency,
                "duration_days": item.duration_days,
                "quantity": item.quantity,
                "timing": item.timing,
                "instructions": item.instructions,
            })
        active_prescriptions.append({
            "id": rx.id,
            "status": rx.status,
            "version": rx.version,
            "notes": rx.notes,
            "signed_at": rx.signed_at.isoformat() if rx.signed_at else None,
            "doctor_name": rx.doctor.user.full_name if (rx.doctor and rx.doctor.user) else "Doctor",
            "is_ocr_extracted": rx.is_ocr_extracted,
            "is_verified_by_clinician": rx.is_verified_by_clinician,
            "items": items_data,
        })

    # Current consultation clinical record if exists
    current_cr = db.query(ClinicalRecord).filter(ClinicalRecord.visit_id == visit.id).first()
    cr_data = ClinicalRecordRead.model_validate(current_cr).model_dump() if current_cr else None

    context = ConsultationContextRead(
        visit=OPDVisitRead.model_validate(visit),
        patient=patient,
        medical_history=med_hist,
        previous_visits=prev_visit_summaries,
        available_investigations=available_investigations,
        active_prescriptions=active_prescriptions,
        clinical_record=cr_data,
    )

    return success_response(
        data=context.model_dump(),
        message="Patient consultation context loaded successfully"
    )
