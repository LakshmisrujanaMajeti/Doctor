from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.responses import success_response
from app.core.dependencies import get_current_user, require_roles
from app.core.exceptions import NotFoundException, ForbiddenException
from app.models.doctor import Doctor
from app.models.visit import OPDVisit
from app.models.clinical import ClinicalRecord
from app.models.laboratory import LabOrder
from app.models.patient import Patient
from app.schemas.doctor import DoctorCreate, DoctorRead, DoctorDashboardStats, FollowUpItem, RecentAuthorizedPatientItem
from app.schemas.visit import OPDVisitRead, DoctorDashboardResponse
from app.models.user import User

router = APIRouter()


def build_doctor_dashboard_data(doctor: Doctor, db: Session) -> dict:
    """Build comprehensive dashboard metrics and queues for a doctor."""
    all_doctor_visits = (
        db.query(OPDVisit)
        .filter(OPDVisit.doctor_id == doctor.id)
        .order_by(OPDVisit.queue_token.asc(), OPDVisit.visit_date.desc())
        .all()
    )

    waiting_patients = [v for v in all_doctor_visits if v.status in ["REGISTERED", "TRIAGED"]]
    under_consultation = [v for v in all_doctor_visits if v.status == "IN_CONSULTATION"]
    completed_consultations = [v for v in all_doctor_visits if v.status == "COMPLETED"]

    # Pending investigations for this doctor's visits or patients
    visit_ids = [v.id for v in all_doctor_visits]
    pending_labs_query = (
        db.query(LabOrder)
        .filter(
            (LabOrder.ordered_by_doctor_id == doctor.id)
            | (LabOrder.visit_id.in_(visit_ids) if visit_ids else False)
        )
        .filter(LabOrder.status != "COMPLETED")
        .order_by(LabOrder.created_at.desc())
    )
    pending_labs = pending_labs_query.all()

    pending_investigations_data = []
    for lab in pending_labs:
        pat = getattr(lab, "patient", None) or db.query(Patient).filter(Patient.id == lab.patient_id).first()
        v = lab.visit
        pending_investigations_data.append({
            "id": lab.id,
            "test_name": lab.test_name,
            "test_category": lab.test_category,
            "status": lab.status,
            "patient_id": lab.patient_id,
            "patient_name": pat.full_name if pat else "Unknown",
            "uhid": pat.uhid if pat else "",
            "visit_id": lab.visit_id,
            "visit_number": v.visit_number if v else "",
            "created_at": lab.created_at.isoformat() if lab.created_at else None,
            "clinical_indication": lab.clinical_indication,
        })

    # Follow-up appointments: Clinical records with follow_up_date
    clinical_followups = (
        db.query(ClinicalRecord)
        .filter(ClinicalRecord.doctor_id == doctor.id)
        .filter(ClinicalRecord.follow_up_date.isnot(None))
        .order_by(ClinicalRecord.follow_up_date.asc())
        .all()
    )

    follow_up_list = []
    for cr in clinical_followups:
        pat = cr.patient
        follow_up_list.append(
            FollowUpItem(
                patient_id=cr.patient_id,
                patient_name=pat.full_name if pat else "Patient",
                uhid=pat.uhid if pat else "",
                visit_id=cr.visit_id,
                follow_up_date=str(cr.follow_up_date),
                final_diagnosis=cr.final_diagnosis or cr.provisional_diagnosis,
                care_plan=cr.care_plan,
            ).model_dump()
        )

    # Recent authorized patient records: Unique patients seen by this doctor
    seen_patient_ids = set()
    recent_patients_data = []
    for v in all_doctor_visits:
        if v.patient_id not in seen_patient_ids and v.patient:
            seen_patient_ids.add(v.patient_id)
            p = v.patient
            age_str = f"{p.age_years} Y" if p.age_years else (f"{p.age_months} M" if p.age_months else "N/A")
            last_cr = (
                db.query(ClinicalRecord)
                .filter(ClinicalRecord.visit_id == v.id)
                .first()
            )
            diag = (last_cr.final_diagnosis or last_cr.provisional_diagnosis) if last_cr else None
            recent_patients_data.append(
                RecentAuthorizedPatientItem(
                    patient_id=p.id,
                    uhid=p.uhid,
                    full_name=p.full_name,
                    age_display=age_str,
                    gender=p.gender or "UNKNOWN",
                    phone_number=p.phone or "",
                    last_visit_date=v.visit_date.strftime("%Y-%m-%d %H:%M") if v.visit_date else None,
                    last_diagnosis=diag,
                ).model_dump()
            )
            if len(recent_patients_data) >= 15:
                break

    stats = DoctorDashboardStats(
        today_appointments=len(all_doctor_visits),
        waiting_patients=len(waiting_patients),
        under_consultation=len(under_consultation),
        completed_consultations=len(completed_consultations),
        pending_investigations=len(pending_investigations_data),
        follow_up_appointments=len(follow_up_list),
    )

    return {
        "doctor": DoctorRead.model_validate(doctor).model_dump(),
        "stats": stats.model_dump(),
        "today_appointments": [OPDVisitRead.model_validate(v).model_dump() for v in all_doctor_visits],
        "waiting_patients": [OPDVisitRead.model_validate(v).model_dump() for v in waiting_patients],
        "under_consultation": [OPDVisitRead.model_validate(v).model_dump() for v in under_consultation],
        "completed_consultations": [OPDVisitRead.model_validate(v).model_dump() for v in completed_consultations],
        "pending_investigations": pending_investigations_data,
        "follow_up_appointments": follow_up_list,
        "recent_authorized_patients": recent_patients_data,
    }


@router.get("", summary="List Doctors")
def list_doctors(
    department_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    stmt = db.query(Doctor).filter(Doctor.is_available == True)
    if department_id:
        stmt = stmt.filter(Doctor.department_id == department_id)
    doctors = stmt.all()
    return success_response(
        data=[DoctorRead.model_validate(d).model_dump() for d in doctors],
        message="Doctors retrieved successfully"
    )


@router.get("/me/dashboard", summary="Get Current Doctor Dashboard")
def get_my_dashboard(
    doctor_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["doctor", "admin"])),
):
    user_role = (current_user.role.name if current_user.role else "").lower()
    doc = None
    if user_role == "doctor":
        doc = db.query(Doctor).filter(Doctor.user_id == current_user.id).first()
    elif user_role == "admin":
        if doctor_id:
            doc = db.query(Doctor).filter(Doctor.id == doctor_id).first()
        else:
            doc = db.query(Doctor).first()

    if not doc:
        raise NotFoundException("Doctor profile not found for user")

    dashboard_data = build_doctor_dashboard_data(doc, db)
    return success_response(
        data=dashboard_data,
        message="Doctor dashboard data retrieved successfully"
    )


@router.get("/{doctor_id}/dashboard", summary="Get Specific Doctor Dashboard")
def get_doctor_dashboard(
    doctor_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["doctor", "admin", "receptionist"])),
):
    doc = db.query(Doctor).filter(Doctor.id == doctor_id).first()
    if not doc:
        raise NotFoundException(f"Doctor '{doctor_id}' not found")

    dashboard_data = build_doctor_dashboard_data(doc, db)
    return success_response(
        data=dashboard_data,
        message="Doctor dashboard data retrieved successfully"
    )


@router.post("", summary="Create Doctor Profile")
def create_doctor(
    doc_in: DoctorCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    existing_doctor = db.query(Doctor).filter(Doctor.user_id == doc_in.user_id).first()
    if existing_doctor:
        if doc_in.department_id:
            existing_doctor.department_id = doc_in.department_id
        if doc_in.qualification:
            existing_doctor.qualification = doc_in.qualification
        if doc_in.specialization:
            existing_doctor.specialization = doc_in.specialization
        if doc_in.registration_number:
            existing_doctor.registration_number = doc_in.registration_number
        if doc_in.room_number:
            existing_doctor.room_number = doc_in.room_number
        if doc_in.consultation_fee is not None:
            existing_doctor.consultation_fee = doc_in.consultation_fee
        if doc_in.is_available is not None:
            existing_doctor.is_available = doc_in.is_available
        db.commit()
        db.refresh(existing_doctor)
        return success_response(
            data=DoctorRead.model_validate(existing_doctor).model_dump(),
            message="Doctor profile updated successfully",
            status_code=200
        )

    doctor = Doctor(
        user_id=doc_in.user_id,
        department_id=doc_in.department_id,
        qualification=doc_in.qualification,
        specialization=doc_in.specialization,
        registration_number=doc_in.registration_number,
        room_number=doc_in.room_number,
        consultation_fee=doc_in.consultation_fee,
        is_available=doc_in.is_available,
    )
    db.add(doctor)
    db.commit()
    db.refresh(doctor)
    return success_response(
        data=DoctorRead.model_validate(doctor).model_dump(),
        message="Doctor profile created successfully",
        status_code=201
    )


@router.get("/{doctor_id}", summary="Get Doctor Profile")
def get_doctor(doctor_id: str, db: Session = Depends(get_db)):
    doc = db.query(Doctor).filter(Doctor.id == doctor_id).first()
    if not doc:
        raise NotFoundException(f"Doctor '{doctor_id}' not found")
    return success_response(
        data=DoctorRead.model_validate(doc).model_dump(),
        message="Doctor profile retrieved"
    )
