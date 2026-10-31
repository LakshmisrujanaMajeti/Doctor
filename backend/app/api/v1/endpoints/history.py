import json
from datetime import datetime, date, timedelta
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func, or_, and_

from app.core.database import get_db
from app.core.responses import success_response
from app.core.dependencies import get_current_user
from app.models.user import User
from app.models.patient import Patient
from app.models.visit import OPDVisit, VitalSigns
from app.models.doctor import Doctor
from app.models.department import Department
from app.models.clinical import ClinicalRecord
from app.models.billing import Bill, PaymentTransaction
from app.models.laboratory import LabOrder
from app.models.prescription import Prescription, PrescriptionItem
from app.models.audit import AuditLog

router = APIRouter()


def _build_search_and_patient_filter(search: Optional[str] = None, patient_id: Optional[str] = None):
    """
    Constructs reusable SQLAlchemy filter expressions for searching by Patient ID,
    UHID, Hospital Registration Number, Phone, Name, or Queue Token.
    """
    conditions = []
    if patient_id and patient_id.strip():
        pid = patient_id.strip()
        conditions.append(
            or_(
                OPDVisit.patient_id == pid,
                Patient.id == pid,
                Patient.uhid.ilike(f"%{pid}%"),
                Patient.hospital_reg_num.ilike(f"%{pid}%"),
                Patient.phone.ilike(f"%{pid}%"),
            )
        )

    if search and search.strip():
        term = f"%{search.strip()}%"
        raw_term = search.strip()
        clean_num = raw_term.lstrip("#").strip()
        token_num = int(clean_num) if clean_num.isdigit() else None

        or_terms = [
            Patient.full_name.ilike(term),
            Patient.uhid.ilike(term),
            Patient.hospital_reg_num.ilike(term),
            Patient.id.ilike(term),
            OPDVisit.patient_id.ilike(term),
            Patient.phone.ilike(term),
            OPDVisit.visit_number.ilike(term),
            OPDVisit.notes.ilike(term),
        ]
        if token_num is not None:
            or_terms.append(OPDVisit.queue_token == token_num)

        conditions.append(or_(*or_terms))

    return conditions


def _serialize_visit_item(v: OPDVisit, db: Session, pat: Optional[Patient] = None) -> Dict[str, Any]:
    """Helper to convert an OPDVisit into a rich, structured appointment history object."""
    if not pat:
        pat = v.patient

    cr = db.query(ClinicalRecord).filter(ClinicalRecord.visit_id == v.id).first()
    bill = db.query(Bill).filter(Bill.visit_id == v.id).first()
    vit = db.query(VitalSigns).filter(VitalSigns.visit_id == v.id).first()
    pr = db.query(Prescription).filter(Prescription.visit_id == v.id).first()

    # Prescriptions list
    prescriptions_list = []
    if pr and pr.items:
        for item in pr.items:
            prescriptions_list.append({
                "id": item.id,
                "medicine_name": item.medicine_name,
                "dosage": item.dosage,
                "form": item.form,
                "timing": item.timing,
                "frequency": item.frequency,
                "duration_days": item.duration_days,
                "instructions": item.instructions,
            })

    doc_user = v.doctor.user if (v.doctor and v.doctor.user) else None
    doctor_name = doc_user.full_name if doc_user else "Consulting Physician"
    doc_spec = v.doctor.specialization if v.doctor else "General Medicine"
    dept_name = v.department.name if v.department else "General Medicine"

    vitals_summary = (
        f"BP: {vit.systolic_bp}/{vit.diastolic_bp} mmHg • Pulse: {vit.pulse_rate} • SpO2: {vit.spo2_percent}%"
        if (vit and vit.systolic_bp)
        else ("Vitals recorded" if vit else "Vitals pending triage")
    )

    return {
        "id": v.id,
        "visit_id": v.id,
        "type": "CONSULTATION" if v.status == "COMPLETED" else "APPOINTMENT",
        "title": f"Visit {v.visit_number} • Token #{v.queue_token} - {dept_name}",
        "patient_id": v.patient_id,
        "patient_name": pat.full_name if pat else "Patient",
        "patient_uhid": pat.uhid if pat else "UHID",
        "patient_reg_num": pat.hospital_reg_num if pat else "REG-N/A",
        "patient_phone": pat.phone if pat else "",
        "patient_gender": pat.gender if pat else "N/A",
        "patient_age": f"{pat.age_years} Y" if pat and pat.age_years else "N/A",
        "patient_blood_group": pat.blood_group if pat else "N/A",
        "patient_address": pat.address if pat else "",
        "visit_number": v.visit_number,
        "queue_token": v.queue_token,
        "department_id": v.department_id,
        "department_name": dept_name,
        "doctor_id": v.doctor_id,
        "doctor_name": doctor_name,
        "doctor_specialization": doc_spec,
        "status": v.status,
        "triage_priority": v.triage_priority,
        "consultation_fee": float(v.consultation_fee or 500.0),
        "payment_status": v.payment_status or (bill.payment_status if bill else "PAID"),
        "payment_method": bill.payment_method if bill else "CASH",
        "bill_number": bill.invoice_number if bill else f"INV-{v.queue_token:04d}",
        "bill_amount": float(bill.paid_amount) if (bill and bill.paid_amount) else float(v.consultation_fee or 500.0),
        "diagnosis": (cr.final_diagnosis or cr.provisional_diagnosis) if cr else ("Consultation Note" if v.notes else "General Checkup"),
        "icd10_code": cr.icd10_code if cr else None,
        "chief_complaint": cr.presenting_complaint if cr else v.notes,
        "care_plan": cr.care_plan if cr else None,
        "notes": v.notes,
        "vitals_summary": vitals_summary,
        "systolic_bp": vit.systolic_bp if vit else None,
        "diastolic_bp": vit.diastolic_bp if vit else None,
        "pulse_rate": vit.pulse_rate if vit else None,
        "temperature_f": vit.temperature_f if vit else None,
        "spo2_percent": vit.spo2_percent if vit else None,
        "respiratory_rate": vit.respiratory_rate if vit else None,
        "blood_glucose": vit.blood_glucose_mg_dl if vit else None,
        "bmi": vit.bmi if vit else None,
        "prescriptions": prescriptions_list,
        "timestamp": v.visit_date.isoformat() if v.visit_date else None,
        "action_badge": "Completed" if v.status == "COMPLETED" else ("In Progress" if v.status == "IN_CONSULTATION" else v.status),
    }


@router.get("/my-history", summary="Role-Based Activity & Records History From Start to Now")
def get_role_history(
    date_filter: Optional[str] = Query("all", description="all, today, yesterday, week, month"),
    search: Optional[str] = Query(None, description="Search by Patient ID, UHID, Reg No, Name, Phone, Token, Visit #"),
    patient_id: Optional[str] = Query(None, description="Filter specifically by Patient UUID, UHID, or Reg Number"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Returns complete, personalized activity and operational history tailored to the logged-in user's role.
    Shows records from starting till now with search, patient ID filter, date filters, and aggregated summary counters.
    """
    user_role = (current_user.role.name if current_user.role else "patient").lower()
    today_start = datetime.combine(date.today(), datetime.min.time())
    yesterday_start = today_start - timedelta(days=1)
    yesterday_end = today_start
    week_start = today_start - timedelta(days=7)
    month_start = datetime.combine(date.today().replace(day=1), datetime.min.time())

    # Date filter boundary
    start_dt = None
    end_dt = None
    if date_filter == "today":
        start_dt = today_start
    elif date_filter == "yesterday":
        start_dt = yesterday_start
        end_dt = yesterday_end
    elif date_filter == "week":
        start_dt = week_start
    elif date_filter == "month":
        start_dt = month_start

    search_filters = _build_search_and_patient_filter(search=search, patient_id=patient_id)

    # ==========================================
    # 1. DOCTOR HISTORY
    # ==========================================
    if user_role == "doctor":
        doc = db.query(Doctor).filter(Doctor.user_id == current_user.id).first()
        if not doc:
            doc = db.query(Doctor).join(User, Doctor.user_id == User.id).filter(User.email == current_user.email).first()
        if not doc and current_user.email:
            prefix = current_user.email.split("@")[0].lower()
            doc = db.query(Doctor).join(User, Doctor.user_id == User.id).filter(
                or_(User.email.ilike(f"%{prefix}%"), Doctor.specialization.ilike(f"%{prefix}%"))
            ).first()

        q = db.query(OPDVisit).join(Patient, OPDVisit.patient_id == Patient.id, isouter=True)
        if doc:
            q = q.filter(
                or_(
                    OPDVisit.doctor_id == doc.id,
                    OPDVisit.doctor_id == doc.user_id,
                    OPDVisit.department_id == doc.department_id,
                )
            )

        if start_dt:
            q = q.filter(OPDVisit.visit_date >= start_dt)
        if end_dt:
            q = q.filter(OPDVisit.visit_date < end_dt)

        for f in search_filters:
            q = q.filter(f)

        total_records = q.count()
        visits = q.order_by(OPDVisit.visit_date.desc(), OPDVisit.queue_token.desc()).offset(skip).limit(limit).all()

        history_items = [_serialize_visit_item(v, db) for v in visits]

        # Aggregated stats
        base_doc_q = db.query(OPDVisit)
        if doc:
            base_doc_q = base_doc_q.filter(
                or_(
                    OPDVisit.doctor_id == doc.id,
                    OPDVisit.doctor_id == doc.user_id,
                    OPDVisit.department_id == doc.department_id,
                )
            )
        total_seen = base_doc_q.filter(OPDVisit.status == "COMPLETED").count()
        today_seen = base_doc_q.filter(OPDVisit.status == "COMPLETED", OPDVisit.visit_date >= today_start).count()
        waiting_now = base_doc_q.filter(OPDVisit.status.in_(["REGISTERED", "TRIAGED"])).count()
        all_time_total = base_doc_q.count()

        return success_response(
            data={
                "role": "doctor",
                "role_display": f"Doctor Consultation History ({doc.specialization if doc else 'General Medicine'})",
                "doctor_name": current_user.full_name,
                "summary": {
                    "all_time_total": all_time_total,
                    "completed_consultations": total_seen,
                    "today_completed": today_seen,
                    "waiting_patients": waiting_now,
                    "filtered_count": total_records,
                },
                "items": history_items,
            },
            message="Doctor consultation history retrieved"
        )

    # ==========================================
    # 2. RECEPTIONIST HISTORY
    # ==========================================
    elif user_role == "receptionist":
        q = db.query(OPDVisit).join(Patient, OPDVisit.patient_id == Patient.id, isouter=True)
        if start_dt:
            q = q.filter(OPDVisit.visit_date >= start_dt)
        if end_dt:
            q = q.filter(OPDVisit.visit_date < end_dt)

        for f in search_filters:
            q = q.filter(f)

        total_records = q.count()
        visits = q.order_by(OPDVisit.visit_date.desc(), OPDVisit.queue_token.desc()).offset(skip).limit(limit).all()

        history_items = [_serialize_visit_item(v, db) for v in visits]

        # Also include patient registrations for front desk intake history
        pat_query = db.query(Patient)
        if start_dt:
            pat_query = pat_query.filter(Patient.created_at >= start_dt)
        if end_dt:
            pat_query = pat_query.filter(Patient.created_at < end_dt)
        for f in search_filters:
            pat_query = pat_query.filter(f)
        patients_list = pat_query.order_by(Patient.created_at.desc()).offset(skip).limit(limit).all()
        for p in patients_list:
            history_items.append({
                "id": f"reg-{p.id}",
                "visit_id": None,
                "visit_number": p.hospital_reg_num or p.uhid,
                "token_number": 0,
                "appointment_date": p.created_at.isoformat() if p.created_at else None,
                "doctor_name": "Front Desk Registration",
                "department_name": "Registration Counter",
                "status": "REGISTERED",
                "triage_priority": "NORMAL",
                "consultation_fee": 0.0,
                "payment_status": "PAID",
                "patient": {
                    "id": p.id,
                    "uhid": p.uhid,
                    "hospital_reg_num": p.hospital_reg_num,
                    "full_name": p.full_name,
                    "phone": p.phone,
                    "gender": p.gender,
                    "age_years": p.age_years,
                },
                "chief_complaint": f"New UHID Registration: {p.uhid}",
                "vitals_summary": "Registration Completed",
            })

        history_items.sort(key=lambda x: x.get("appointment_date") or "", reverse=True)

        total_patients = db.query(Patient).count()
        today_patients = db.query(Patient).filter(Patient.created_at >= today_start).count()
        total_tokens = db.query(OPDVisit).count()
        today_tokens = db.query(OPDVisit).filter(OPDVisit.visit_date >= today_start).count()

        return success_response(
            data={
                "role": "receptionist",
                "role_display": "Front Desk Registration & Token Issuance History",
                "user_name": current_user.full_name,
                "summary": {
                    "total_registered_patients": total_patients,
                    "today_registered_patients": today_patients,
                    "total_tokens_issued": total_tokens,
                    "today_tokens_issued": today_tokens,
                    "filtered_count": total_records,
                },
                "items": history_items,
            },
            message="Receptionist intake history retrieved"
        )

    # ==========================================
    # 3. NURSE / TRIAGE HISTORY
    # ==========================================
    elif user_role == "nurse":
        q = (
            db.query(VitalSigns)
            .join(OPDVisit, VitalSigns.visit_id == OPDVisit.id, isouter=True)
            .join(Patient, OPDVisit.patient_id == Patient.id, isouter=True)
        )
        if start_dt:
            q = q.filter(VitalSigns.recorded_at >= start_dt)
        if end_dt:
            q = q.filter(VitalSigns.recorded_at < end_dt)

        for f in search_filters:
            q = q.filter(f)

        total_records = q.count()
        vitals_list = q.order_by(VitalSigns.recorded_at.desc()).offset(skip).limit(limit).all()

        history_items = []
        for vit in vitals_list:
            v = vit.visit
            if v:
                history_items.append(_serialize_visit_item(v, db, pat=v.patient))

        total_triaged = db.query(VitalSigns).count()
        today_triaged = db.query(VitalSigns).filter(VitalSigns.recorded_at >= today_start).count()
        emergency_count = db.query(OPDVisit).filter(OPDVisit.triage_priority == "EMERGENCY").count()
        priority_count = db.query(OPDVisit).filter(OPDVisit.triage_priority == "PRIORITY").count()

        return success_response(
            data={
                "role": "nurse",
                "role_display": "Nursing Triage & Vitals Assessment History",
                "user_name": current_user.full_name,
                "summary": {
                    "total_triaged_patients": total_triaged,
                    "today_triaged_patients": today_triaged,
                    "emergency_cases": emergency_count,
                    "priority_cases": priority_count,
                    "filtered_count": total_records,
                },
                "items": history_items,
            },
            message="Nursing triage history retrieved"
        )

    # ==========================================
    # 4. BILLING / CASHIER HISTORY
    # ==========================================
    elif user_role == "billing":
        q = db.query(Bill).join(Patient, Bill.patient_id == Patient.id, isouter=True).join(OPDVisit, Bill.visit_id == OPDVisit.id, isouter=True)
        if start_dt:
            q = q.filter(Bill.billed_at >= start_dt)
        if end_dt:
            q = q.filter(Bill.billed_at < end_dt)

        for f in search_filters:
            q = q.filter(f)

        total_records = q.count()
        bills = q.order_by(Bill.billed_at.desc()).offset(skip).limit(limit).all()

        history_items = []
        for b in bills:
            if b.visit:
                history_items.append(_serialize_visit_item(b.visit, db, pat=b.patient))
            else:
                pat = b.patient
                history_items.append({
                    "id": b.id,
                    "type": "BILLING_RECEIPT",
                    "title": f"Invoice #{b.invoice_number} - ₹{float(b.paid_amount or 0.0):.2f} ({b.payment_status})",
                    "bill_number": b.invoice_number,
                    "patient_id": b.patient_id,
                    "patient_name": pat.full_name if pat else "Patient",
                    "patient_uhid": pat.uhid if pat else "UHID",
                    "visit_number": "N/A",
                    "total_amount": float(b.total_amount or 0.0),
                    "paid_amount": float(b.paid_amount or 0.0),
                    "pending_amount": float(b.outstanding_balance or 0.0),
                    "payment_status": b.payment_status,
                    "payment_method": b.payment_method or "CASH",
                    "timestamp": b.billed_at.isoformat() if b.billed_at else None,
                    "action_badge": b.payment_status,
                })

        # Financial summaries
        all_bills_paid = db.query(func.sum(Bill.paid_amount)).filter(Bill.paid_amount > 0).scalar() or 0.0
        all_tx_paid = db.query(func.sum(PaymentTransaction.amount)).filter(PaymentTransaction.payment_status == "COMPLETED").scalar() or 0.0
        grand_total = float(max(all_bills_paid, all_tx_paid))

        bills_today = db.query(func.sum(Bill.paid_amount)).filter(Bill.payment_status.in_(["PAID", "PARTIAL"]), Bill.billed_at >= today_start).scalar() or 0.0
        bills_yesterday = db.query(func.sum(Bill.paid_amount)).filter(Bill.payment_status.in_(["PAID", "PARTIAL"]), Bill.billed_at >= yesterday_start, Bill.billed_at < yesterday_end).scalar() or 0.0

        return success_response(
            data={
                "role": "billing",
                "role_display": "Cashier Billing & Collections History",
                "user_name": current_user.full_name,
                "summary": {
                    "grand_total_revenue": grand_total,
                    "today_revenue": float(bills_today),
                    "yesterday_revenue": float(bills_yesterday),
                    "total_bills_issued": db.query(Bill).count(),
                    "filtered_count": total_records,
                },
                "items": history_items,
            },
            message="Billing counter history retrieved"
        )

    # ==========================================
    # 5. PATIENT VISIT & HEALTHCARE HISTORY (PAST & PRESENT)
    # ==========================================
    elif user_role == "patient":
        patient = None
        if current_user.patient_id:
            patient = db.query(Patient).filter(Patient.id == current_user.patient_id).first()
        if not patient:
            patient = db.query(Patient).filter(Patient.user_id == current_user.id).first()
        if not patient and current_user.email:
            patient = db.query(Patient).filter(Patient.email == current_user.email).first()
        if not patient and current_user.phone:
            patient = db.query(Patient).filter(Patient.phone == current_user.phone).first()

        q = db.query(OPDVisit).filter(OPDVisit.patient_id == patient.id) if patient else db.query(OPDVisit).filter(False)
        if start_dt:
            q = q.filter(OPDVisit.visit_date >= start_dt)
        if end_dt:
            q = q.filter(OPDVisit.visit_date < end_dt)

        for f in search_filters:
            q = q.filter(f)

        total_records = q.count()
        visits = q.order_by(OPDVisit.visit_date.desc(), OPDVisit.queue_token.desc()).offset(skip).limit(limit).all()

        history_items = [_serialize_visit_item(v, db, pat=patient) for v in visits]

        completed_count = db.query(OPDVisit).filter(OPDVisit.patient_id == patient.id, OPDVisit.status == "COMPLETED").count() if patient else 0
        active_count = db.query(OPDVisit).filter(OPDVisit.patient_id == patient.id, OPDVisit.status.in_(["REGISTERED", "TRIAGED", "IN_CONSULTATION"])).count() if patient else 0
        total_spent = db.query(func.sum(Bill.paid_amount)).filter(Bill.patient_id == patient.id).scalar() or 0.0 if patient else 0.0

        return success_response(
            data={
                "role": "patient",
                "role_display": "Personal Patient Hospital Visit History (Past & Present)",
                "user_name": current_user.full_name,
                "summary": {
                    "total_hospital_visits": total_records,
                    "past_completed_visits": completed_count,
                    "active_ongoing_visits": active_count,
                    "total_billing_paid": float(total_spent),
                    "filtered_count": total_records,
                },
                "items": history_items,
            },
            message="Patient hospital visit history retrieved"
        )

    # ==========================================
    # 6. ADMIN / MASTER COMPREHENSIVE HISTORY
    # ==========================================
    else:
        q = db.query(OPDVisit).join(Patient, OPDVisit.patient_id == Patient.id, isouter=True)
        if start_dt:
            q = q.filter(OPDVisit.visit_date >= start_dt)
        if end_dt:
            q = q.filter(OPDVisit.visit_date < end_dt)

        for f in search_filters:
            q = q.filter(f)

        total_records = q.count()
        visits = q.order_by(OPDVisit.visit_date.desc(), OPDVisit.queue_token.desc()).offset(skip).limit(limit).all()

        history_items = [_serialize_visit_item(v, db) for v in visits]

        all_bills_paid = db.query(func.sum(Bill.paid_amount)).filter(Bill.paid_amount > 0).scalar() or 0.0
        all_tx_paid = db.query(func.sum(PaymentTransaction.amount)).filter(PaymentTransaction.payment_status == "COMPLETED").scalar() or 0.0
        grand_total = float(max(all_bills_paid, all_tx_paid))

        bills_today = db.query(func.sum(Bill.paid_amount)).filter(Bill.payment_status.in_(["PAID", "PARTIAL"]), Bill.billed_at >= today_start).scalar() or 0.0
        bills_yesterday = db.query(func.sum(Bill.paid_amount)).filter(Bill.payment_status.in_(["PAID", "PARTIAL"]), Bill.billed_at >= yesterday_start, Bill.billed_at < yesterday_end).scalar() or 0.0

        return success_response(
            data={
                "role": user_role,
                "role_display": "Master Hospital Operations & Clinical History",
                "user_name": current_user.full_name,
                "summary": {
                    "grand_total_revenue": grand_total,
                    "today_revenue": float(bills_today),
                    "yesterday_revenue": float(bills_yesterday),
                    "total_registered_patients": db.query(Patient).count(),
                    "total_visits_created": db.query(OPDVisit).count(),
                    "filtered_count": total_records,
                },
                "items": history_items,
            },
            message="Master hospital history retrieved"
        )


@router.get("/patient/{patient_identifier}", summary="Get Full Appointment and Medical History by Patient ID/UHID/Phone")
def get_patient_appointment_history(
    patient_identifier: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Lookup a patient by Patient UUID, UHID, Hospital Registration Number, or Phone,
    and return their complete historical appointments, clinical diagnoses, vitals,
    prescriptions, and billing transactions.
    """
    clean_id = (patient_identifier or "").strip()
    if not clean_id:
        raise HTTPException(status_code=400, detail="Patient identifier is required")

    # Find the patient
    patient = db.query(Patient).filter(
        or_(
            Patient.id == clean_id,
            Patient.uhid == clean_id,
            Patient.uhid.ilike(f"%{clean_id}%"),
            Patient.hospital_reg_num == clean_id,
            Patient.hospital_reg_num.ilike(f"%{clean_id}%"),
            Patient.phone == clean_id,
            Patient.barcode_value == clean_id,
        )
    ).first()

    if not patient:
        # Try numeric matching
        clean_digits = "".join(filter(str.isdigit, clean_id))
        if len(clean_digits) >= 10:
            patient = db.query(Patient).filter(Patient.phone.ilike(f"%{clean_digits[-10:]}%")).first()

    if not patient:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Patient with identifier '{patient_identifier}' not found in hospital registry",
        )

    # Fetch all appointments/visits for this patient
    visits = (
        db.query(OPDVisit)
        .filter(OPDVisit.patient_id == patient.id)
        .order_by(OPDVisit.visit_date.desc(), OPDVisit.created_at.desc())
        .all()
    )

    appointment_items = [_serialize_visit_item(v, db, pat=patient) for v in visits]

    total_visits = len(visits)
    completed_visits = sum(1 for v in visits if v.status == "COMPLETED")
    ongoing_visits = sum(1 for v in visits if v.status in ["REGISTERED", "TRIAGED", "IN_CONSULTATION"])
    total_spent = sum(float(v.consultation_fee or 500.0) for v in visits if v.status == "COMPLETED")

    return success_response(
        data={
            "patient": {
                "id": patient.id,
                "uhid": patient.uhid,
                "hospital_reg_num": patient.hospital_reg_num,
                "full_name": patient.full_name,
                "gender": patient.gender,
                "age_years": patient.age_years,
                "phone": patient.phone,
                "email": patient.email,
                "blood_group": patient.blood_group,
                "address": patient.address,
                "city": patient.city,
                "state": patient.state,
                "postal_code": patient.postal_code,
                "registration_date": patient.registration_date.isoformat() if patient.registration_date else None,
            },
            "summary": {
                "total_appointments": total_visits,
                "completed_appointments": completed_visits,
                "ongoing_appointments": ongoing_visits,
                "total_fees_paid": total_spent,
            },
            "appointments": appointment_items,
        },
        message=f"Appointment and clinical history for {patient.full_name} ({patient.uhid}) retrieved successfully",
    )


@router.get("/appointments", summary="List All Patient Appointments and Visits")
def list_appointments_history(
    patient_id: Optional[str] = Query(None, description="Patient UUID, UHID, or Reg Number"),
    doctor_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Search and retrieve appointment history across all registered hospital visits.
    """
    q = db.query(OPDVisit).join(Patient, OPDVisit.patient_id == Patient.id, isouter=True)

    if doctor_id:
        q = q.filter(OPDVisit.doctor_id == doctor_id)
    if status:
        q = q.filter(OPDVisit.status == status.upper())

    search_filters = _build_search_and_patient_filter(search=search, patient_id=patient_id)
    for f in search_filters:
        q = q.filter(f)

    total_records = q.count()
    visits = q.order_by(OPDVisit.visit_date.desc(), OPDVisit.queue_token.desc()).offset(skip).limit(limit).all()

    items = [_serialize_visit_item(v, db) for v in visits]

    return success_response(
        data={
            "total": total_records,
            "items": items,
        },
        message="Appointments history retrieved successfully",
    )
