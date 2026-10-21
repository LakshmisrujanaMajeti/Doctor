import uuid
import pytest
from datetime import date
from fastapi.testclient import TestClient
from app.main import app
from app.core.database import SessionLocal
from app.models.user import User, Role
from app.models.doctor import Doctor
from app.models.department import Department
from app.models.patient import Patient
from app.models.visit import OPDVisit
from app.models.clinical import ClinicalRecord
from app.models.prescription import Prescription
from app.models.laboratory import LabOrder


@pytest.fixture(scope="module")
def client():
    return TestClient(app)


@pytest.fixture(scope="function")
def db():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.rollback()
        session.close()


@pytest.fixture(scope="module")
def auth_tokens(client):
    doc_login = client.post("/api/v1/auth/login", json={"email": "dr.chen@opdconnect.com", "password": "Doctor@123456"})
    admin_login = client.post("/api/v1/auth/login", json={"email": "admin@opdconnect.com", "password": "Admin@123456"})
    rec_login = client.post("/api/v1/auth/login", json={"email": "receptionist@opdconnect.com", "password": "Reception@123456"})
    pat_login = client.post("/api/v1/auth/login", json={"email": "patient@opdconnect.com", "password": "Patient@123456"})

    return {
        "doctor": doc_login.json()["data"]["access_token"],
        "admin": admin_login.json()["data"]["access_token"],
        "receptionist": rec_login.json()["data"]["access_token"],
        "patient": pat_login.json()["data"]["access_token"],
    }


def test_doctor_dashboard_retrieval(client, auth_tokens, db):
    """Verify doctor dashboard displays today's appointments, waiting queue, under consultation, completed, pending investigations, follow-ups."""
    headers = {"Authorization": f"Bearer {auth_tokens['doctor']}"}
    resp = client.get("/api/v1/doctors/me/dashboard", headers=headers)
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]

    assert "stats" in data
    assert "doctor" in data
    assert "waiting_patients" in data
    assert "under_consultation" in data
    assert "completed_consultations" in data
    assert "pending_investigations" in data
    assert "follow_up_appointments" in data
    assert "recent_authorized_patients" in data

    stats = data["stats"]
    assert stats["today_appointments"] >= 1


def test_consultation_context_and_workflow_initiation(client, auth_tokens, db):
    """
    Step 1 & 2 of Consultation Workflow:
    Open authorized visit, retrieve demographics, previous visits, allergies, history, investigations.
    Verify status automatically transitions from REGISTERED/TRIAGED to IN_CONSULTATION.
    """
    doc = db.query(Doctor).first()
    pat = db.query(Patient).filter(Patient.uhid == "UHID-2026-00002").first()
    dept = db.query(Department).first()

    # Create a fresh waiting visit
    test_visit = OPDVisit(
        visit_number=f"VIS-QUEUE-{uuid.uuid4().hex[:8].upper()}",
        patient_id=pat.id,
        doctor_id=doc.id,
        department_id=dept.id,
        queue_token=99,
        triage_priority="NORMAL",
        status="TRIAGED",
    )
    db.add(test_visit)
    db.commit()
    db.refresh(test_visit)

    headers = {"Authorization": f"Bearer {auth_tokens['doctor']}"}
    resp = client.get(f"/api/v1/visits/{test_visit.id}/consultation-context", headers=headers)
    assert resp.status_code == 200, resp.text
    context = resp.json()["data"]

    assert context["visit"]["id"] == test_visit.id
    assert context["visit"]["status"] == "IN_CONSULTATION" # Transitioned
    assert context["patient"]["uhid"] == pat.uhid
    assert "medical_history" in context
    assert "previous_visits" in context
    assert "available_investigations" in context
    assert "active_prescriptions" in context


def test_medicine_catalog_search_and_allergy_warning_safety(client, auth_tokens, db):
    """
    Verify medicine catalog search and robust clinical allergy warning detection.
    Ensure allergy warning requires explicit acknowledgement before signing.
    """
    headers = {"Authorization": f"Bearer {auth_tokens['doctor']}"}

    # 1. Search medicine catalog
    resp = client.get("/api/v1/prescriptions/medicines?q=amox", headers=headers)
    assert resp.status_code == 200
    meds = resp.json()["data"]
    assert any("Amoxicillin" in m["name"] for m in meds)

    # 2. Check allergies against patient with recorded penicillin allergy
    pat = db.query(Patient).filter(Patient.uhid == "UHID-2026-00002").first()
    # Record allergic clinical history for patient 2
    doc = db.query(Doctor).first()
    visit = db.query(OPDVisit).filter(OPDVisit.patient_id == pat.id).first()
    existing_cr = db.query(ClinicalRecord).filter(ClinicalRecord.patient_id == pat.id).first()
    if not existing_cr:
        cr = ClinicalRecord(
            visit_id=visit.id,
            patient_id=pat.id,
            doctor_id=doc.id,
            presenting_complaint="Allergy consultation",
            allergies="Severe Penicillin and Sulfa allergy with urticaria",
            status="FINALIZED",
        )
        db.add(cr)
        db.commit()

    resp = client.post(
        "/api/v1/prescriptions/check-allergies",
        json={"patient_id": pat.id, "medicines": ["Amoxicillin", "Co-trimoxazole", "Paracetamol"]},
        headers=headers,
    )
    assert resp.status_code == 200
    check_data = resp.json()["data"]
    assert check_data["has_warnings"] is True
    assert len(check_data["warnings"]) >= 2

    # 3. Attempting to create and sign prescription with allergic medicine without acknowledgement must fail
    resp = client.post(
        "/api/v1/prescriptions",
        json={
            "visit_id": visit.id,
            "status": "SIGNED",
            "allergy_warning_acknowledged": False,
            "items": [
                {
                    "medicine_name": "Amoxicillin",
                    "form": "Capsule",
                    "dosage": "500 mg",
                    "route": "Oral",
                    "frequency": "TID",
                    "duration_days": 5,
                    "quantity": 15,
                    "instructions": "Take with meals",
                }
            ],
        },
        headers=headers,
    )
    assert resp.status_code == 400
    assert "Allergy Safety Alert" in resp.json()["message"]


def test_prescription_lifecycle_draft_sign_amend_and_audit(client, auth_tokens, db):
    """
    Test complete prescription lifecycle:
    Draft -> Sign -> Amend (preserving snapshot & reason) -> Cancel.
    Also verify unverified OCR prescriptions cannot be directly signed.
    """
    headers = {"Authorization": f"Bearer {auth_tokens['doctor']}"}
    visit = db.query(OPDVisit).first()

    # 1. OCR-extracted prescription with is_verified_by_clinician=False must be forced to DRAFT
    ocr_resp = client.post(
        "/api/v1/prescriptions",
        json={
            "visit_id": visit.id,
            "status": "SIGNED",
            "is_ocr_extracted": True,
            "is_verified_by_clinician": False,
            "items": [
                {
                    "medicine_name": "Paracetamol",
                    "form": "Tablet",
                    "dosage": "650 mg",
                    "frequency": "SOS",
                    "duration_days": 3,
                }
            ],
        },
        headers=headers,
    )
    assert ocr_resp.status_code in [200, 201]
    assert ocr_resp.json()["data"]["status"] == "DRAFT"
    assert ocr_resp.json()["data"]["is_verified_by_clinician"] is False
    rx_id = ocr_resp.json()["data"]["id"]

    # 2. Sign draft prescription
    sign_resp = client.post(
        f"/api/v1/prescriptions/{rx_id}/sign",
        json={"allergy_warning_acknowledged": True},
        headers=headers,
    )
    assert sign_resp.status_code == 200
    assert sign_resp.json()["data"]["status"] == "SIGNED"
    assert sign_resp.json()["data"]["is_verified_by_clinician"] is True
    assert sign_resp.json()["data"]["signed_by_user_id"] is not None

    # 3. Amend prescription (amendment preserves snapshot and increments version)
    amend_resp = client.post(
        f"/api/v1/prescriptions/{rx_id}/amend",
        json={
            "amendment_reason": "Patient reports persistent fever; adjusted dosage and duration",
            "items": [
                {
                    "medicine_name": "Paracetamol",
                    "form": "Tablet",
                    "dosage": "650 mg",
                    "route": "Oral",
                    "frequency": "TID",
                    "duration_days": 5,
                    "quantity": 15,
                    "instructions": "Regular intervals after meals",
                }
            ],
        },
        headers=headers,
    )
    assert amend_resp.status_code == 200
    amended_rx = amend_resp.json()["data"]
    assert amended_rx["status"] == "AMENDED"
    assert amended_rx["version"] == 2
    assert len(amended_rx["amendments"]) == 1
    assert "fever" in amended_rx["amendments"][0]["reason"]

    # 4. Cancel prescription
    cancel_resp = client.post(
        f"/api/v1/prescriptions/{rx_id}/cancel",
        json={"reason": "Superceded by alternate treatment"},
        headers=headers,
    )
    assert cancel_resp.status_code == 200
    assert cancel_resp.json()["data"]["status"] == "CANCELLED"


def test_complete_end_to_end_consultation_workflow(client, auth_tokens, db):
    """
    Complete end-to-end OPD consultation workflow:
    1. Open authorized patient visit -> context loaded
    2. Record clinical record with provisional/final diagnosis, exam, treatment plan, follow-up
    3. Order laboratory investigations
    4. Issue prescription
    5. Finalize consultation (visit status transitions to COMPLETED)
    """
    headers = {"Authorization": f"Bearer {auth_tokens['doctor']}"}
    doc = db.query(Doctor).first()
    pat = db.query(Patient).filter(Patient.uhid == "UHID-2026-00003").first()
    dept = db.query(Department).first()

    # Step 1: Open Visit
    visit = OPDVisit(
        visit_number=f"VIS-WORKFLOW-{uuid.uuid4().hex[:8].upper()}",
        patient_id=pat.id,
        doctor_id=doc.id,
        department_id=dept.id,
        queue_token=105,
        triage_priority="NORMAL",
        status="TRIAGED",
    )
    db.add(visit)
    db.commit()
    db.refresh(visit)

    ctx_resp = client.get(f"/api/v1/visits/{visit.id}/consultation-context", headers=headers)
    assert ctx_resp.status_code == 200
    assert ctx_resp.json()["data"]["visit"]["status"] == "IN_CONSULTATION"

    # Step 2: Record Clinical Record
    cr_resp = client.post(
        "/api/v1/clinical-records",
        json={
            "visit_id": visit.id,
            "presenting_complaint": "Polyuria, polydipsia, and fatigue for 2 weeks",
            "history_of_present_illness": "Gradual onset over 14 days with 3kg weight loss",
            "allergies": "No known drug allergies (NKDA)",
            "past_medical_history": "Type 2 Diabetes Mellitus diagnosed 2021",
            "general_examination": "Conscious, oriented, mild dehydration",
            "respiratory_examination": "Clear to auscultation bilaterally",
            "cardiovascular_examination": "S1 S2 normal, no murmurs",
            "gastrointestinal_examination": "Soft, non-tender",
            "cns_examination": "Grossly intact, sensation normal",
            "provisional_diagnosis": "Uncontrolled Type 2 Diabetes Mellitus",
            "final_diagnosis": "Type 2 Diabetes Mellitus with Hyperglycemia (E11.65)",
            "icd10_code": "E11.65",
            "care_plan": "Increase Metformin to 1000mg BD. Diabetic diet, lifestyle changes. Maintain blood glucose log.",
            "dietary_advice": "Low carbohydrate, high fiber, avoid refined sugars.",
            "follow_up_date": "2026-10-26",
            "status": "FINALIZED",
        },
        headers=headers,
    )
    assert cr_resp.status_code == 200, cr_resp.text
    assert cr_resp.json()["data"]["status"] == "FINALIZED"

    # Step 3: Order Laboratory Investigations
    lab_resp = client.post(
        "/api/v1/laboratory/orders",
        json={
            "visit_id": visit.id,
            "test_name": "Fasting Plasma Glucose & Serum Creatinine",
            "test_category": "Biochemistry",
            "clinical_indication": "Follow-up glycemic control and renal function assessment",
        },
        headers=headers,
    )
    assert lab_resp.status_code in [200, 201]
    assert lab_resp.json()["data"]["status"] == "ORDERED"

    # Step 4: Issue Prescription
    rx_resp = client.post(
        "/api/v1/prescriptions",
        json={
            "visit_id": visit.id,
            "status": "SIGNED",
            "notes": "Monitor morning fasting blood glucose daily",
            "allergy_warning_acknowledged": True,
            "items": [
                {
                    "medicine_name": "Metformin",
                    "form": "Tablet",
                    "dosage": "1000 mg",
                    "route": "Oral",
                    "frequency": "BD",
                    "duration_days": 14,
                    "quantity": 28,
                    "timing": "After Food",
                    "instructions": "Take with breakfast and dinner",
                }
            ],
        },
        headers=headers,
    )
    assert rx_resp.status_code in [200, 201]
    assert rx_resp.json()["data"]["status"] == "SIGNED"

    # Verify visit is now COMPLETED
    db.refresh(visit)
    assert visit.status == "COMPLETED"
