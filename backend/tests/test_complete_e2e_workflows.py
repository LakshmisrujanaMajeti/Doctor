import io
import json
import pytest
from datetime import datetime, date, timedelta
from decimal import Decimal
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.core.database import get_db
from app.models.user import User, Role, Permission
from app.models.patient import Patient
from app.models.visit import OPDVisit
from app.models.department import Department
from app.models.doctor import Doctor
from app.models.clinical import ClinicalRecord
from app.models.prescription import Prescription, PrescriptionItem
from app.models.laboratory import LabOrder, LabResult
from app.models.pharmacy import MedicineInventory, StockMovement
from app.models.billing import Bill, BillItem, PaymentTransaction
from app.models.document import MedicalDocument, DocumentPage, DocumentOCRExtraction
from app.models.audit import AuditLog
from app.core.security import get_password_hash, create_access_token


@pytest.fixture
def e2e_system_setup(db_session: Session):
    """Seed comprehensive roles, permissions, staff accounts, departments, and medicine inventory."""
    # 1. Roles
    all_role_names = ["admin", "patient", "doctor", "nurse", "receptionist", "pharmacist", "laboratory", "lab_tech"]
    roles = {}
    for r_name in all_role_names:
        r = db_session.query(Role).filter(Role.name == r_name).first()
        if not r:
            r = Role(name=r_name, description=r_name.capitalize())
            db_session.add(r)
            db_session.flush()
        roles[r_name] = r

    # 2. Permissions
    permissions_data = [
        ("patient:read", "Read patient data"),
        ("patient:write", "Create/update patient data"),
        ("patient:dependents", "Manage dependent profiles"),
        ("clinical:read", "Read clinical notes"),
        ("clinical:write", "Write clinical sheets and prescriptions"),
        ("clinical:audit", "Clinical auditor override"),
        ("admin:users", "Manage staff accounts"),
        ("admin:roles", "Manage roles"),
        ("admin:config", "Edit configs"),
        ("admin:reports", "Generate reports"),
        ("admin:audit", "Inspect audit logs"),
        ("billing:read", "Read bills"),
        ("billing:write", "Write bills and payments"),
        ("pharmacy:read", "Read formulary"),
        ("pharmacy:write", "Dispense medications"),
        ("lab:read", "Read lab orders"),
        ("lab:write", "Enter lab results"),
    ]
    perms = {}
    for code, desc in permissions_data:
        p = db_session.query(Permission).filter(Permission.code == code).first()
        if not p:
            p = Permission(code=code, name=code, description=desc)
            db_session.add(p)
            db_session.flush()
        perms[code] = p

    # Map permissions
    for p in perms.values():
        if p not in roles["admin"].permissions and p.code not in ["clinical:read", "clinical:write"]:
            roles["admin"].permissions.append(p)

    for p_code in ["patient:read", "clinical:read", "clinical:write", "lab:read", "lab:write", "pharmacy:read"]:
        if perms[p_code] not in roles["doctor"].permissions:
            roles["doctor"].permissions.append(perms[p_code])

    for p_code in ["patient:read", "patient:write", "billing:read", "billing:write"]:
        if perms[p_code] not in roles["receptionist"].permissions:
            roles["receptionist"].permissions.append(perms[p_code])

    for p_code in ["pharmacy:read", "pharmacy:write", "billing:read", "billing:write"]:
        if perms[p_code] not in roles["pharmacist"].permissions:
            roles["pharmacist"].permissions.append(perms[p_code])

    for p_code in ["lab:read", "lab:write"]:
        if perms[p_code] not in roles["lab_tech"].permissions:
            roles["lab_tech"].permissions.append(perms[p_code])

    for p_code in ["patient:read", "patient:dependents", "billing:read"]:
        if perms[p_code] not in roles["patient"].permissions:
            roles["patient"].permissions.append(perms[p_code])

    db_session.flush()

    # 3. Department
    dept = db_session.query(Department).filter(Department.code == "GEN").first()
    if not dept:
        dept = Department(name="General Medicine", code="GEN", is_active=True)
        db_session.add(dept)
        db_session.flush()

    # 4. Staff Accounts
    def get_or_create_user(email, full_name, role_name):
        u = db_session.query(User).filter(User.email == email).first()
        if not u:
            u = User(
                email=email,
                full_name=full_name,
                hashed_password=get_password_hash("HospitalPass123!"),
                role=roles[role_name],
                is_active=True,
                is_verified=True,
            )
            db_session.add(u)
            db_session.flush()
        return u

    admin_user = get_or_create_user("admin_e2e@hospital.com", "Chief Administrator", "admin")
    doc_user = get_or_create_user("doctor_e2e@hospital.com", "Dr. Alexander Fleming", "doctor")
    rec_user = get_or_create_user("receptionist_e2e@hospital.com", "Receptionist Clara", "receptionist")
    pharm_user = get_or_create_user("pharmacist_e2e@hospital.com", "Pharmacist Leo", "pharmacist")
    lab_user = get_or_create_user("lab_e2e@hospital.com", "Technologist Marie", "lab_tech")

    # Doctor Profile
    doctor = db_session.query(Doctor).filter(Doctor.user_id == doc_user.id).first()
    if not doctor:
        doctor = Doctor(
            user=doc_user,
            department=dept,
            specialization="Internal Medicine",
            qualification="MBBS, MD",
            registration_number="REG-E2E-9999",
        )
        db_session.add(doctor)
        db_session.flush()

    # 5. Pharmacy Inventory Item
    med = db_session.query(MedicineInventory).filter(MedicineInventory.medicine_code == "MED-E2E-AMOX").first()
    if not med:
        med = MedicineInventory(
            medicine_code="MED-E2E-AMOX",
            name="Amoxicillin 500mg",
            generic_name="Amoxicillin Trihydrate",
            strength="500 mg",
            dosage_form="Capsule",
            batch_number="BAT-E2E-001",
            expiry_date=date.today() + timedelta(days=365),
            available_quantity=200,
            reorder_level=30,
            unit_price=12.50,
            tax_classification="GST_12",
            is_synthetic_price=False,
            supplier_name="Global Pharma Corp",
        )
        db_session.add(med)
        db_session.flush()

    db_session.commit()

    return {
        "admin_token": create_access_token(subject=admin_user.id, extra_claims={"email": admin_user.email, "role": "admin"}),
        "doctor_token": create_access_token(subject=doc_user.id, extra_claims={"email": doc_user.email, "role": "doctor"}),
        "rec_token": create_access_token(subject=rec_user.id, extra_claims={"email": rec_user.email, "role": "receptionist"}),
        "pharm_token": create_access_token(subject=pharm_user.id, extra_claims={"email": pharm_user.email, "role": "pharmacist"}),
        "lab_token": create_access_token(subject=lab_user.id, extra_claims={"email": lab_user.email, "role": "lab_tech"}),
        "admin_user": admin_user,
        "doc_user": doc_user,
        "doctor": doctor,
        "department": dept,
        "medicine": med,
    }


def test_complete_end_to_end_12_workflows(client: TestClient, db_session: Session, e2e_system_setup: dict):
    """
    Executes and validates the 12 complete hospital workflows sequentially.
    """
    admin_hdr = {"Authorization": f"Bearer {e2e_system_setup['admin_token']}"}
    doc_hdr = {"Authorization": f"Bearer {e2e_system_setup['doctor_token']}"}
    rec_hdr = {"Authorization": f"Bearer {e2e_system_setup['rec_token']}"}
    pharm_hdr = {"Authorization": f"Bearer {e2e_system_setup['pharm_token']}"}
    lab_hdr = {"Authorization": f"Bearer {e2e_system_setup['lab_token']}"}
    dept_id = e2e_system_setup["department"].id
    doctor_id = e2e_system_setup["doctor"].id

    # =========================================================================
    # WORKFLOW 1: Patient registration -> OPD visit creation
    # =========================================================================
    patient_payload = {
        "full_name": "Rohan Deshmukh",
        "gender": "MALE",
        "phone": "+919876599901",
        "date_of_birth": "1990-06-15",
        "address": "742 Evergreen Terrace",
        "city": "Bengaluru",
        "state": "Karnataka",
        "postal_code": "560001",
        "blood_group": "O+",
        "emergency_contact_name": "Pooja Deshmukh",
        "emergency_contact_phone": "+919876599902",
        "emergency_contact_relation": "Spouse",
    }
    reg_res = client.post("/api/v1/patients", json=patient_payload, headers=rec_hdr)
    assert reg_res.status_code in [200, 201], reg_res.text
    patient_data = reg_res.json()["data"]
    patient_id = patient_data["id"]
    patient_uhid = patient_data["uhid"]
    assert patient_uhid.startswith("UHID-")
    assert patient_data["full_name"] == "Rohan Deshmukh"

    # Create OPD Visit
    visit_payload = {
        "patient_id": patient_id,
        "department_id": dept_id,
        "doctor_id": doctor_id,
        "triage_priority": "NORMAL",
        "chief_complaint": "Persistent productive cough, high fever for 3 days",
    }
    visit_res = client.post("/api/v1/visits", json=visit_payload, headers=rec_hdr)
    assert visit_res.status_code in [200, 201], visit_res.text
    visit_data = visit_res.json()["data"]
    visit_id = visit_data["id"]
    assert visit_data["queue_token"] is not None
    assert visit_data["status"] == "REGISTERED"

    # =========================================================================
    # WORKFLOW 2: Receptionist -> appointment and patient lookup & duplicate check
    # =========================================================================
    # Search by UHID
    search_res = client.get(f"/api/v1/patients?query={patient_uhid}", headers=rec_hdr)
    assert search_res.status_code == 200
    matched_patients = search_res.json()["data"]
    assert len(matched_patients) >= 1
    assert matched_patients[0]["id"] == patient_id

    # Search by Phone
    search_phone_res = client.get("/api/v1/patients?query=9876599901", headers=rec_hdr)
    assert search_phone_res.status_code == 200
    assert any(p["id"] == patient_id for p in search_phone_res.json()["data"])

    # Duplicate Prevention: Attempt creating patient with same phone
    dup_res = client.post("/api/v1/patients", json=patient_payload, headers=rec_hdr)
    assert dup_res.status_code in [400, 409], "Duplicate patient registration must be rejected"

    # =========================================================================
    # WORKFLOW 3: Doctor -> assessment, examination, diagnosis, and treatment plan
    # Record vitals & calculate BMI (transitions visit to TRIAGED)
    vitals_payload = {
        "visit_id": visit_id,
        "systolic_bp": 124,
        "diastolic_bp": 82,
        "pulse_rate": 78,
        "temperature_f": 101.4,
        "spo2_percent": 97.0,
        "height_cm": 172.0,
        "weight_kg": 70.0,
    }
    vitals_res = client.post(f"/api/v1/visits/{visit_id}/vitals", json=vitals_payload, headers=doc_hdr)
    assert vitals_res.status_code == 200
    assert vitals_res.json()["data"]["bmi"] > 0

    # Doctor opens consultation context: transitions from TRIAGED to IN_CONSULTATION
    visit_in_consult = client.get(f"/api/v1/visits/{visit_id}/consultation-context", headers=doc_hdr)
    assert visit_in_consult.status_code == 200
    assert visit_in_consult.json()["data"]["visit"]["status"] == "IN_CONSULTATION"

    # Doctor Clinical Consultation Sheet
    clinical_payload = {
        "visit_id": visit_id,
        "presenting_complaint": "Fever, chills, productive yellow sputum",
        "respiratory_examination": "Bilateral coarse crackles at lung bases. Throat congested.",
        "provisional_diagnosis": "Community-Acquired Bacterial Pneumonia",
        "icd10_code": "J15.9",
        "care_plan": "Oral amoxicillin course, antipyretic hydration, diagnostic CBC and chest workup.",
    }
    consult_res = client.post("/api/v1/clinical-records", json=clinical_payload, headers=doc_hdr)
    assert consult_res.status_code in [200, 201], consult_res.text
    record_data = consult_res.json()["data"]
    clinical_record_id = record_data["id"]

    # =========================================================================
    # WORKFLOW 4: Doctor -> laboratory order
    # =========================================================================
    lab_order_payload = {
        "visit_id": visit_id,
        "test_name": "Complete Blood Count (CBC)",
        "test_category": "HAEMATOLOGY",
        "priority": "ROUTINE",
        "clinical_indication": "Evaluate leukocytosis and infection markers",
    }
    order_res = client.post("/api/v1/laboratory/orders", json=lab_order_payload, headers=doc_hdr)
    assert order_res.status_code in [200, 201], order_res.text
    lab_order_id = order_res.json()["data"]["id"]

    # =========================================================================
    # WORKFLOW 5: Laboratory staff -> specimen processing, result entry, verification & release
    # =========================================================================
    # Collect Specimen
    collect_res = client.post(
        f"/api/v1/laboratory/orders/{lab_order_id}/collect",
        json={"specimen_type": "Whole Blood (EDTA)", "collector_name": "Phlebotomist Marie"},
        headers=lab_hdr,
    )
    assert collect_res.status_code == 200

    # Receive Specimen
    recv_res = client.post(
        f"/api/v1/laboratory/orders/{lab_order_id}/receive",
        json={"receiver_name": "Technologist Marie"},
        headers=lab_hdr,
    )
    assert recv_res.status_code == 200

    # Enter Results
    result_entry_payload = {
        "results": [
            {"parameter_name": "Hemoglobin", "result_value": "13.8", "unit": "g/dL", "reference_range": "13.0 - 17.0"},
            {"parameter_name": "Total Leukocyte Count (WBC)", "result_value": "12500", "unit": "/cumm", "reference_range": "4000 - 11000", "is_abnormal": True},
            {"parameter_name": "Platelets", "result_value": "240000", "unit": "/cumm", "reference_range": "150000 - 450000"},
        ]
    }
    res_entry = client.post(f"/api/v1/laboratory/orders/{lab_order_id}/results", json=result_entry_payload, headers=lab_hdr)
    assert res_entry.status_code in [200, 201], res_entry.text

    # Pathologist Verification and Release
    verify_res = client.post(
        f"/api/v1/laboratory/orders/{lab_order_id}/verify",
        json={"verification_notes": "Verified against automated haematology analyzer"},
        headers=lab_hdr,
    )
    assert verify_res.status_code == 200
    assert verify_res.json()["data"]["status"] == "COMPLETED"

    # =========================================================================
    # WORKFLOW 6: Doctor -> prescription creation and signing
    # =========================================================================
    rx_payload = {
        "visit_id": visit_id,
        "allergy_warning_acknowledged": True,
        "items": [
            {
                "medicine_name": "Amoxicillin 500mg",
                "dosage": "500 mg",
                "frequency": "TDS",
                "duration_days": 5,
                "quantity": 15,
                "route": "Oral",
                "instructions": "Take after meals with a glass of water",
            }
        ],
        "notes": "Complete the full 5-day antibiotic course even if fever resolves early.",
    }
    rx_res = client.post("/api/v1/prescriptions", json=rx_payload, headers=doc_hdr)
    assert rx_res.status_code in [200, 201], rx_res.text
    prescription_data = rx_res.json()["data"]
    prescription_id = prescription_data["id"]
    rx_item_id = prescription_data["items"][0]["id"]

    # Sign Prescription
    sign_res = client.post(f"/api/v1/prescriptions/{prescription_id}/sign", headers=doc_hdr)
    assert sign_res.status_code == 200
    assert sign_res.json()["data"]["status"] == "SIGNED"

    # =========================================================================
    # WORKFLOW 7 & 8: Pharmacist -> verification, dispensing, stock deduction & billing
    # =========================================================================
    initial_stock = e2e_system_setup["medicine"].available_quantity
    dispense_payload = {
        "prescription_id": prescription_id,
        "items": [
            {
                "prescription_item_id": rx_item_id,
                "inventory_id": e2e_system_setup["medicine"].id,
                "quantity_to_dispense": 15,
                "instructions": "Take 1 cap TDS after meals",
            }
        ],
        "notes": "Dispensed Amoxicillin 500mg (15 capsules)",
    }
    dispense_res = client.post("/api/v1/pharmacy/dispense", json=dispense_payload, headers=pharm_hdr)
    assert dispense_res.status_code in [200, 201], dispense_res.text

    # Verify inventory was automatically deducted in DB
    db_session.expire_all()
    updated_med = db_session.query(MedicineInventory).filter(MedicineInventory.id == e2e_system_setup["medicine"].id).first()
    assert updated_med.available_quantity == initial_stock - 15

    # Pharmacy / Hospital Billing Invoice Creation:
    # Consultation (300.00 @ 0%), Lab CBC (250.00 @ 0%), Amox (15 * 12.50 = 187.50 @ 12% = 22.50 tax).
    # Discount: FIXED 50.00
    # Subtotal base = 300 + 250 + 187.50 = 737.50
    # Total amount = 737.50 - 50 + 22.50 = 710.00
    bill_payload = {
        "visit_id": visit_id,
        "patient_id": patient_id,
        "discount_type": "FIXED",
        "discount_amount": 50.0,
        "payment_method": "CASH",
        "paid_amount": 0.0,
        "items": [
            {"item_type": "CONSULTATION", "description": "General OPD Consultation Fee", "quantity": 1, "unit_price": 300.0, "tax_rate_percent": 0.0},
            {"item_type": "PROCEDURE", "description": "Amoxicillin 500mg (15 Capsules)", "quantity": 15, "unit_price": 12.50, "tax_rate_percent": 12.0},
            {"item_type": "LAB", "description": "Complete Blood Count (CBC)", "quantity": 1, "unit_price": 250.0, "tax_rate_percent": 0.0},
        ],
    }
    bill_res = client.post("/api/v1/billing", json=bill_payload, headers=rec_hdr)
    assert bill_res.status_code in [200, 201], bill_res.text
    bill_data = bill_res.json()["data"]
    bill_id = bill_data["id"]

    assert float(bill_data["subtotal"]) == 737.50
    assert float(bill_data["discount_amount"]) == 50.0
    assert float(bill_data["total_amount"]) == 710.00
    assert float(bill_data["outstanding_balance"]) == 710.00

    # Payment Processing & Verification
    pay_payload = {
        "amount": 710.00,
        "payment_method": "CASH",
    }
    pay_res1 = client.post(f"/api/v1/billing/{bill_id}/payments", json=pay_payload, headers=rec_hdr)
    assert pay_res1.status_code in [200, 201]

    # Bill status should be PAID
    refetched_bill = client.get(f"/api/v1/billing/{bill_id}", headers=rec_hdr).json()["data"]
    assert refetched_bill["payment_status"] == "PAID"
    assert float(refetched_bill["outstanding_balance"]) == 0.00

    # Duplicate payment submission when bill is already fully paid must be prevented
    pay_dup = client.post(f"/api/v1/billing/{bill_id}/payments", json=pay_payload, headers=rec_hdr)
    assert pay_dup.status_code in [400, 409], "Duplicate over-payment must be prevented"

    # =========================================================================
    # WORKFLOW 9: Patient -> authorized access & strict privacy isolation
    # =========================================================================
    # Create patient login account linked to patient_id
    patient_user = User(
        email="rohan.patient@opdconnect.com",
        full_name="Rohan Deshmukh",
        hashed_password=get_password_hash("PatientPass123!"),
        role=db_session.query(Role).filter(Role.name == "patient").first(),
        patient_id=patient_id,
        is_active=True,
        is_verified=True,
    )
    db_session.add(patient_user)
    db_session.commit()
    patient_token = create_access_token(subject=patient_user.id, extra_claims={"email": patient_user.email, "role": "patient"})
    pat_hdr = {"Authorization": f"Bearer {patient_token}"}

    # Patient retrieves their own profile
    profile_res = client.get("/api/v1/patient-portal/profile", headers=pat_hdr)
    assert profile_res.status_code == 200
    assert profile_res.json()["data"]["patient"]["uhid"] == patient_uhid

    # Patient retrieves their own prescriptions and lab reports
    pat_rx_res = client.get("/api/v1/patient-portal/prescriptions", headers=pat_hdr)
    assert pat_rx_res.status_code == 200
    assert len(pat_rx_res.json()["data"]) >= 1

    pat_lab_res = client.get("/api/v1/patient-portal/lab-reports", headers=pat_hdr)
    assert pat_lab_res.status_code == 200
    assert len(pat_lab_res.json()["data"]) >= 1
    assert pat_lab_res.json()["data"][0]["status"] == "COMPLETED"

    # Patient retrieves their own itemized bill
    pat_bills_res = client.get("/api/v1/patient-portal/bills", headers=pat_hdr)
    assert pat_bills_res.status_code == 200
    assert len(pat_bills_res.json()["data"]) >= 1

    # Patient Data Isolation: Register a second patient and ensure patient 1 cannot access patient 2's data
    other_patient = Patient(
        full_name="Other Confidential Patient",
        gender="FEMALE",
        phone="+919876543299",
        uhid="UHID-OTHER-999",
        registration_date=datetime.utcnow(),
    )
    db_session.add(other_patient)
    db_session.commit()

    cross_access_res = client.get(f"/api/v1/patient-portal/prescriptions?patient_id={other_patient.id}", headers=pat_hdr)
    assert cross_access_res.status_code == 403, "Access to unauthorized patient records must be denied with 403"

    # =========================================================================
    # WORKFLOW 10: Administrator -> user management, reports, and audit logs
    # =========================================================================
    # Admin checks operational summary
    dash_res = client.get("/api/v1/admin/dashboard-summary", headers=admin_hdr)
    assert dash_res.status_code == 200
    assert dash_res.json()["data"]["total_patients_registered"] >= 1

    # Admin provisions a new staff user
    new_staff_payload = {
        "email": "nurse_new@hospital.com",
        "full_name": "Nurse Nancy",
        "password": "TemporaryPassword123!",
        "role_name": "nurse",
        "phone": "+919876543277",
    }
    provision_res = client.post("/api/v1/admin/users", json=new_staff_payload, headers=admin_hdr)
    assert provision_res.status_code == 201
    provisioned_id = provision_res.json()["data"]["id"]

    # Admin deactivates that account
    deactivate_res = client.patch(
        f"/api/v1/admin/users/{provisioned_id}/status",
        json={"is_active": False},
        headers=admin_hdr,
    )
    assert deactivate_res.status_code == 200
    assert deactivate_res.json()["data"]["is_active"] is False

    # Admin CSV Report Generation with PII Shielding
    csv_rep_res = client.get("/api/v1/admin/reports/registrations?format=csv", headers=admin_hdr)
    assert csv_rep_res.status_code == 200
    assert "text/csv" in csv_rep_res.headers.get("content-type", "")
    csv_content = csv_rep_res.text
    assert "Visit Number" in csv_content
    # PII Protection: Patient raw phone number and email must not appear in operational CSV report
    assert "+919876599901" not in csv_content
    assert "rohan.patient@opdconnect.com" not in csv_content

    # Non-clinical staff (receptionist) cannot directly access confidential clinical consultations
    clinical_role_check = client.get(f"/api/v1/clinical-records/{clinical_record_id}", headers=rec_hdr)
    assert clinical_role_check.status_code == 403, "Non-clinical staff must not access raw clinical consultations"

    # Audit Log Inspection
    audit_res = client.get("/api/v1/admin/audit-logs?limit=20", headers=admin_hdr)
    assert audit_res.status_code == 200
    audit_logs = audit_res.json()["data"]
    assert len(audit_logs) >= 1
    # Verify passwords, tokens, or private medical notes are not stored in audit details
    for log in audit_logs:
        log_str = json.dumps(log["details"]).lower()
        assert "password" not in log_str
        assert "access_token" not in log_str
        assert "secret" not in log_str

    # =========================================================================
    # WORKFLOW 11: Medical document -> scan/import, OCR review, verification, storage
    # =========================================================================
    # Upload document
    dummy_pdf = b"%PDF-1.4 demo medical record booklet scan content"
    files = {"file": ("opd_booklet_scan.pdf", io.BytesIO(dummy_pdf), "application/pdf")}
    data = {
        "patient_id": patient_id,
        "document_type": "OPD_BOOKLET_SCAN",
        "description": "Scanned physical OPD consultation booklet",
        "page_count": 1,
    }
    upload_res = client.post("/api/v1/documents/upload", headers=doc_hdr, data=data, files=files)
    assert upload_res.status_code in [200, 201], upload_res.text
    doc_data = upload_res.json()["data"]
    document_id = doc_data["id"]

    # Extract OCR fields
    ocr_extract_res = client.post(f"/api/v1/documents/{document_id}/ocr/extract", headers=doc_hdr)
    assert ocr_extract_res.status_code == 200
    extractions = ocr_extract_res.json()["data"]
    assert len(extractions) > 0

    # Clinician verifies all extracted fields
    for ext in extractions:
        client.put(
            f"/api/v1/documents/{document_id}/ocr/{ext['id']}/verify",
            headers=doc_hdr,
            json={"verification_status": "CONFIRMED", "verified_value": ext["normalized_value"]},
        )

    # Clinician signs off on entire document
    sign_off_res = client.post(
        f"/api/v1/documents/{document_id}/verify-all",
        headers=doc_hdr,
        json={"clinician_notes": "Reviewed and verified against physical OPD consultation booklet"},
    )
    assert sign_off_res.status_code == 200
    assert sign_off_res.json()["data"]["verification_status"] == "VERIFIED"

    # =========================================================================
    # WORKFLOW 12: Logout, token expiry, account deactivation, and unauthorized access
    # =========================================================================
    # Logout
    logout_res = client.post("/api/v1/auth/logout", headers=pat_hdr)
    assert logout_res.status_code in [200, 204]

    # Deactivated account immediate rejection
    login_attempt = client.post(
        "/api/v1/auth/login",
        json={"identifier": "nurse_new@hospital.com", "password": "TemporaryPassword123!"},
    )
    assert login_attempt.status_code in [400, 401, 403], "Deactivated account must be rejected on login"

    # Unauthorized access rejection on protected route without authorization header
    unauth_res = client.get("/api/v1/visits")
    assert unauth_res.status_code == 401, "Protected routes must reject requests without tokens"
