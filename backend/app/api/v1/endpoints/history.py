import json
from datetime import datetime, date, timedelta
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, Query
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
from app.models.prescription import Prescription
from app.models.audit import AuditLog

router = APIRouter()


@router.get("/my-history", summary="Role-Based Activity & Records History From Start to Now")
def get_role_history(
    date_filter: Optional[str] = Query("all", description="all, today, yesterday, week, month"),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Returns complete, personalized activity and operational history tailored to the logged-in user's role.
    Shows records from starting till now with search, date filters, and aggregated summary counters.
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

    search_term = f"%{search.strip()}%" if search and search.strip() else None

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

        if search_term:
            q = q.filter(
                or_(
                    Patient.full_name.ilike(search_term),
                    Patient.uhid.ilike(search_term),
                    OPDVisit.visit_number.ilike(search_term),
                )
            )

        total_records = q.count()
        visits = q.order_by(OPDVisit.visit_date.desc(), OPDVisit.queue_token.desc()).offset(skip).limit(limit).all()

        history_items = []
        for v in visits:
            pat = v.patient
            cr = db.query(ClinicalRecord).filter(ClinicalRecord.visit_id == v.id).first()
            history_items.append({
                "id": v.id,
                "type": "CONSULTATION",
                "title": f"Consultation Token #{v.queue_token} - {v.status}",
                "patient_id": v.patient_id,
                "patient_name": pat.full_name if pat else "Patient",
                "patient_uhid": pat.uhid if pat else "UHID",
                "patient_gender": pat.gender if pat else "N/A",
                "patient_age": f"{pat.age_years} Y" if pat and pat.age_years else "N/A",
                "visit_number": v.visit_number,
                "queue_token": v.queue_token,
                "department_name": v.department.name if v.department else "General Medicine",
                "status": v.status,
                "triage_priority": v.triage_priority,
                "diagnosis": (cr.final_diagnosis or cr.provisional_diagnosis) if cr else None,
                "chief_complaint": cr.presenting_complaint if cr else v.notes,
                "timestamp": v.visit_date.isoformat() if v.visit_date else None,
                "action_badge": "Completed" if v.status == "COMPLETED" else ("In Progress" if v.status == "IN_CONSULTATION" else "Waiting"),
            })

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

        if search_term:
            q = q.filter(
                or_(
                    Patient.full_name.ilike(search_term),
                    Patient.uhid.ilike(search_term),
                    Patient.phone.ilike(search_term),
                    OPDVisit.visit_number.ilike(search_term),
                )
            )

        total_records = q.count()
        visits = q.order_by(OPDVisit.visit_date.desc(), OPDVisit.queue_token.desc()).offset(skip).limit(limit).all()

        history_items = []
        for v in visits:
            pat = v.patient
            doc_user = v.doctor.user if v.doctor else None
            history_items.append({
                "id": v.id,
                "type": "REGISTRATION_AND_TOKEN",
                "title": f"Token #{v.queue_token} Issued - {v.visit_number}",
                "patient_id": v.patient_id,
                "patient_name": pat.full_name if pat else "Patient",
                "patient_uhid": pat.uhid if pat else "UHID",
                "patient_phone": pat.phone if pat else "",
                "patient_gender": pat.gender if pat else "N/A",
                "patient_age": f"{pat.age_years} Y" if pat and pat.age_years else "N/A",
                "visit_number": v.visit_number,
                "queue_token": v.queue_token,
                "department_name": v.department.name if v.department else "General Medicine",
                "doctor_name": doc_user.full_name if doc_user else "OPD Physician",
                "status": v.status,
                "triage_priority": v.triage_priority,
                "consultation_fee": float(v.consultation_fee or 500.0),
                "notes": v.notes,
                "timestamp": v.visit_date.isoformat() if v.visit_date else None,
                "action_badge": "Token Issued",
            })

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

        if search_term:
            q = q.filter(
                or_(
                    Patient.full_name.ilike(search_term),
                    Patient.uhid.ilike(search_term),
                    OPDVisit.visit_number.ilike(search_term),
                )
            )

        total_records = q.count()
        vitals_list = q.order_by(VitalSigns.recorded_at.desc()).offset(skip).limit(limit).all()

        history_items = []
        for vit in vitals_list:
            v = vit.visit
            pat = v.patient if v else None
            bp_str = f"{vit.systolic_bp}/{vit.diastolic_bp} mmHg" if vit.systolic_bp and vit.diastolic_bp else "N/A"
            pulse_str = f"{vit.pulse_rate} bpm" if vit.pulse_rate else "N/A"
            spo2_str = f"{vit.spo2_percent}%" if vit.spo2_percent else "N/A"
            temp_str = f"{vit.temperature_f} °F" if vit.temperature_f else "N/A"

            history_items.append({
                "id": vit.id,
                "type": "TRIAGE_VITALS",
                "title": f"Triage Assessment - BP: {bp_str} • SpO2: {spo2_str}",
                "visit_id": vit.visit_id,
                "visit_number": v.visit_number if v else "N/A",
                "queue_token": v.queue_token if v else None,
                "patient_id": pat.id if pat else None,
                "patient_name": pat.full_name if pat else "Patient",
                "patient_uhid": pat.uhid if pat else "UHID",
                "patient_gender": pat.gender if pat else "N/A",
                "patient_age": f"{pat.age_years} Y" if pat and pat.age_years else "N/A",
                "triage_priority": v.triage_priority if v else "NORMAL",
                "systolic_bp": vit.systolic_bp,
                "diastolic_bp": vit.diastolic_bp,
                "pulse_rate": vit.pulse_rate,
                "temperature_f": vit.temperature_f,
                "spo2_percent": vit.spo2_percent,
                "respiratory_rate": vit.respiratory_rate,
                "blood_glucose": vit.blood_glucose_mg_dl,
                "bmi": vit.bmi,
                "notes": vit.notes,
                "timestamp": vit.recorded_at.isoformat() if vit.recorded_at else None,
                "action_badge": v.triage_priority if v else "NORMAL",
            })

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
        q = db.query(Bill).join(Patient, Bill.patient_id == Patient.id, isouter=True)
        if start_dt:
            q = q.filter(Bill.billed_at >= start_dt)
        if end_dt:
            q = q.filter(Bill.billed_at < end_dt)

        if search_term:
            q = q.filter(
                or_(
                    Bill.bill_number.ilike(search_term),
                    Patient.full_name.ilike(search_term),
                    Patient.uhid.ilike(search_term),
                )
            )

        total_records = q.count()
        bills = q.order_by(Bill.billed_at.desc()).offset(skip).limit(limit).all()

        history_items = []
        for b in bills:
            pat = b.patient
            v = b.visit
            history_items.append({
                "id": b.id,
                "type": "BILLING_RECEIPT",
                "title": f"Invoice #{b.bill_number} - ₹{float(b.paid_amount or 0.0):.2f} ({b.payment_status})",
                "bill_number": b.bill_number,
                "patient_id": b.patient_id,
                "patient_name": pat.full_name if pat else "Patient",
                "patient_uhid": pat.uhid if pat else "UHID",
                "visit_number": v.visit_number if v else "N/A",
                "total_amount": float(b.total_amount or 0.0),
                "paid_amount": float(b.paid_amount or 0.0),
                "pending_amount": float(b.pending_amount or 0.0),
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
        # Resolve patient record
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

        if search_term:
            q = q.filter(
                or_(
                    OPDVisit.visit_number.ilike(search_term),
                    OPDVisit.notes.ilike(search_term),
                )
            )

        total_records = q.count()
        visits = q.order_by(OPDVisit.visit_date.desc(), OPDVisit.queue_token.desc()).offset(skip).limit(limit).all()

        history_items = []
        for v in visits:
            doc_user = v.doctor.user if v.doctor else None
            cr = db.query(ClinicalRecord).filter(ClinicalRecord.visit_id == v.id).first()
            bill = db.query(Bill).filter(Bill.visit_id == v.id).first()
            vit = db.query(VitalSigns).filter(VitalSigns.visit_id == v.id).first()
            vitals_str = f"BP: {vit.systolic_bp}/{vit.diastolic_bp} • SpO2: {vit.spo2_percent}%" if vit and vit.systolic_bp else "Vitals recorded"

            history_items.append({
                "id": v.id,
                "type": "PATIENT_HOSPITAL_VISIT",
                "title": f"Visit {v.visit_number} • Token #{v.queue_token} - {v.department.name if v.department else 'OPD'}",
                "patient_id": v.patient_id,
                "patient_name": patient.full_name if patient else current_user.full_name,
                "patient_uhid": patient.uhid if patient else "UHID",
                "visit_number": v.visit_number,
                "queue_token": v.queue_token,
                "department_name": v.department.name if v.department else "General Medicine",
                "doctor_name": doc_user.full_name if doc_user else "Consulting Doctor",
                "status": v.status,
                "triage_priority": v.triage_priority,
                "vitals_summary": vitals_str,
                "diagnosis": (cr.final_diagnosis or cr.provisional_diagnosis) if cr else "Routine Consultation",
                "bill_status": bill.payment_status if bill else "PAID",
                "bill_amount": float(bill.paid_amount) if bill and bill.paid_amount else float(v.consultation_fee or 500.0),
                "timestamp": v.visit_date.isoformat() if v.visit_date else None,
                "action_badge": v.status,
            })

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
        # Admin or other roles: Comprehensive master history
        q = db.query(OPDVisit).join(Patient, OPDVisit.patient_id == Patient.id, isouter=True)
        if start_dt:
            q = q.filter(OPDVisit.visit_date >= start_dt)
        if end_dt:
            q = q.filter(OPDVisit.visit_date < end_dt)

        if search_term:
            q = q.filter(
                or_(
                    Patient.full_name.ilike(search_term),
                    Patient.uhid.ilike(search_term),
                    OPDVisit.visit_number.ilike(search_term),
                )
            )

        total_records = q.count()
        visits = q.order_by(OPDVisit.visit_date.desc(), OPDVisit.queue_token.desc()).offset(skip).limit(limit).all()

        history_items = []
        for v in visits:
            pat = v.patient
            doc_user = v.doctor.user if v.doctor else None
            cr = db.query(ClinicalRecord).filter(ClinicalRecord.visit_id == v.id).first()
            bill = db.query(Bill).filter(Bill.visit_id == v.id).first()
            history_items.append({
                "id": v.id,
                "type": "HOSPITAL_VISIT_LIFECYCLE",
                "title": f"Visit {v.visit_number} • Token #{v.queue_token}",
                "patient_id": v.patient_id,
                "patient_name": pat.full_name if pat else "Patient",
                "patient_uhid": pat.uhid if pat else "UHID",
                "visit_number": v.visit_number,
                "queue_token": v.queue_token,
                "department_name": v.department.name if v.department else "General Medicine",
                "doctor_name": doc_user.full_name if doc_user else "Physician",
                "status": v.status,
                "triage_priority": v.triage_priority,
                "diagnosis": (cr.final_diagnosis or cr.provisional_diagnosis) if cr else None,
                "bill_status": bill.payment_status if bill else "UNBILLED",
                "bill_amount": float(bill.paid_amount) if bill and bill.paid_amount else float(v.consultation_fee or 500.0),
                "timestamp": v.visit_date.isoformat() if v.visit_date else None,
                "action_badge": v.status,
            })

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
