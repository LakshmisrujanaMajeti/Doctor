import pytest
from datetime import datetime, date, timedelta
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
from app.models.audit import AuditLog
from app.core.security import get_password_hash, create_access_token


@pytest.fixture
def test_setup(db_session: Session):
    # Ensure roles exist
    all_role_names = ["admin", "patient", "doctor", "nurse", "receptionist", "pharmacist", "laboratory", "lab_tech"]
    for r_name in all_role_names:
        r = db_session.query(Role).filter(Role.name == r_name).first()
        if not r:
            db_session.add(Role(name=r_name, description=r_name.capitalize()))
    db_session.flush()

    admin_role = db_session.query(Role).filter(Role.name == "admin").first()
    patient_role = db_session.query(Role).filter(Role.name == "patient").first()
    doc_role = db_session.query(Role).filter(Role.name == "doctor").first()

    # Department & Doctor
    dept = db_session.query(Department).filter(Department.code == "GEN").first()
    if not dept:
        dept = Department(name="General Medicine", code="GEN", is_active=True)
        db_session.add(dept)
        db_session.flush()

    doctor_user = db_session.query(User).filter(User.email == "doctor_portal_test@hospital.com").first()
    if not doctor_user:
        doctor_user = User(
            email="doctor_portal_test@hospital.com",
            full_name="Dr. Test Physician",
            hashed_password=get_password_hash("Doctor123!"),
            role=doc_role,
            is_active=True,
            is_verified=True,
        )
        db_session.add(doctor_user)
        db_session.flush()

    doctor = db_session.query(Doctor).filter(Doctor.user_id == doctor_user.id).first()
    if not doctor:
        doctor = Doctor(
            user_id=doctor_user.id,
            department_id=dept.id,
            registration_number="MCI-PORTAL-TEST",
            qualification="MBBS, MD",
            specialization="General Medicine",
            room_number="Room 101",
            is_available=True,
        )
        db_session.add(doctor)
        db_session.flush()

    # Patient 1 (Primary)
    p1 = db_session.query(Patient).filter(Patient.uhid == "UHID-PORTAL-0001").first()
    if not p1:
        p1 = Patient(
            uhid="UHID-PORTAL-0001",
            full_name="Arjun Sharma",
            gender="MALE",
            phone="+919876543210",
            age_years=35,
            registration_date=datetime.utcnow(),
        )
        db_session.add(p1)
        db_session.flush()

    u1 = db_session.query(User).filter(User.email == "arjun.patient@test.com").first()
    if not u1:
        u1 = User(
            email="arjun.patient@test.com",
            full_name="Arjun Sharma",
            hashed_password=get_password_hash("Patient123!"),
            role=patient_role,
            patient_id=p1.id,
            is_active=True,
            is_verified=True,
        )
        db_session.add(u1)
        db_session.flush()

    # Patient 2 (Unrelated Patient)
    p2 = db_session.query(Patient).filter(Patient.uhid == "UHID-PORTAL-0002").first()
    if not p2:
        p2 = Patient(
            uhid="UHID-PORTAL-0002",
            full_name="Pooja Verma",
            gender="FEMALE",
            phone="+919876543211",
            age_years=28,
            registration_date=datetime.utcnow(),
        )
        db_session.add(p2)
        db_session.flush()

    u2 = db_session.query(User).filter(User.email == "pooja.patient@test.com").first()
    if not u2:
        u2 = User(
            email="pooja.patient@test.com",
            full_name="Pooja Verma",
            hashed_password=get_password_hash("Patient123!"),
            role=patient_role,
            patient_id=p2.id,
            is_active=True,
            is_verified=True,
        )
        db_session.add(u2)
        db_session.flush()

    # Admin User
    admin_user = db_session.query(User).filter(User.email == "admin_portal_test@hospital.com").first()
    if not admin_user:
        admin_user = User(
            email="admin_portal_test@hospital.com",
            full_name="Chief Administrator",
            hashed_password=get_password_hash("Admin123!"),
            role=admin_role,
            is_active=True,
            is_verified=True,
        )
        db_session.add(admin_user)
        db_session.flush()

    db_session.commit()

    return {
        "p1": p1,
        "u1": u1,
        "p2": p2,
        "u2": u2,
        "admin_user": admin_user,
        "doctor": doctor,
        "dept": dept,
        "token_p1": create_access_token(subject=u1.id, extra_claims={"email": u1.email, "role": "patient"}),
        "token_p2": create_access_token(subject=u2.id, extra_claims={"email": u2.email, "role": "patient"}),
        "token_admin": create_access_token(subject=admin_user.id, extra_claims={"email": admin_user.email, "role": "admin"}),
    }


def test_patient_portal_profile_and_dependent_registration(client: TestClient, test_setup: dict, db_session: Session):
    token_p1 = test_setup["token_p1"]
    headers = {"Authorization": f"Bearer {token_p1}"}

    # 1. Fetch own profile
    res = client.get("/api/v1/patient-portal/profile", headers=headers)
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["patient"]["uhid"] == "UHID-PORTAL-0001"
    assert data["patient"]["full_name"] == "Arjun Sharma"
    assert isinstance(data["dependents"], list)

    # 2. Add dependent (child)
    dep_payload = {
        "full_name": "Aarav Sharma",
        "relation": "Son",
        "gender": "MALE",
        "age_years": 5,
        "age_months": 2,
        "blood_group": "O+",
    }
    dep_res = client.post("/api/v1/patient-portal/dependents", headers=headers, json=dep_payload)
    assert dep_res.status_code == 201
    dep_data = dep_res.json()["data"]
    assert dep_data["full_name"] == "Aarav Sharma"
    assert dep_data["relation"] == "Son"
    assert "UHID-" in dep_data["uhid"]
    child_id = dep_data["id"]

    # Verify audit event DEPENDENT_LINKED was created
    audit = db_session.query(AuditLog).filter(AuditLog.action == "DEPENDENT_LINKED", AuditLog.entity_id == child_id).first()
    assert audit is not None
    assert audit.user_id == test_setup["u1"].id

    # 3. List dependents
    list_res = client.get("/api/v1/patient-portal/dependents", headers=headers)
    assert list_res.status_code == 200
    deps = list_res.json()["data"]
    assert any(d["id"] == child_id for d in deps)


def test_patient_data_isolation_enforcement(client: TestClient, test_setup: dict):
    """Verify patients can access ONLY their own and authorized dependent records."""
    token_p1 = test_setup["token_p1"]
    p2_id = test_setup["p2"].id
    headers = {"Authorization": f"Bearer {token_p1}"}

    # Patient 1 tries to access Patient 2's visits
    res = client.get(f"/api/v1/patient-portal/visits?patient_id={p2_id}", headers=headers)
    assert res.status_code == 403
    assert "Access to another patient's medical records is forbidden" in res.json()["message"]

    # Patient 1 tries to access Patient 2's bills
    res_bill = client.get(f"/api/v1/patient-portal/bills?patient_id={p2_id}", headers=headers)
    assert res_bill.status_code == 403

    # Patient 1 tries to access Patient 2's prescriptions
    res_rx = client.get(f"/api/v1/patient-portal/prescriptions?patient_id={p2_id}", headers=headers)
    assert res_rx.status_code == 403


def test_patient_support_workflow_and_admin_resolution(client: TestClient, test_setup: dict):
    headers_p = {"Authorization": f"Bearer {test_setup['token_p1']}"}
    headers_admin = {"Authorization": f"Bearer {test_setup['token_admin']}"}

    # Patient submits support inquiry
    ticket_payload = {
        "subject": "Inquiry regarding OPD consultation receipt",
        "category": "BILLING",
        "priority": "NORMAL",
        "message": "Could you please clarify the tax breakdown on my consultation bill?",
    }
    create_res = client.post("/api/v1/patient-portal/support", headers=headers_p, json=ticket_payload)
    assert create_res.status_code == 201
    ticket_id = create_res.json()["data"]["id"]
    assert create_res.json()["data"]["status"] == "OPEN"

    # Admin lists support tickets
    admin_list = client.get("/api/v1/admin/support-tickets", headers=headers_admin)
    assert admin_list.status_code == 200
    tickets = admin_list.json()["data"]
    assert any(t["id"] == ticket_id for t in tickets)

    # Admin responds and resolves ticket
    resolve_payload = {
        "admin_response": "OPD clinical consultation services are exempt from GST under Indian Healthcare services notifications.",
        "status": "RESOLVED",
    }
    resolve_res = client.post(f"/api/v1/admin/support-tickets/{ticket_id}/respond", headers=headers_admin, json=resolve_payload)
    assert resolve_res.status_code == 200
    assert resolve_res.json()["data"]["status"] == "RESOLVED"
    assert resolve_res.json()["data"]["admin_response"] is not None

    # Patient sees resolved status
    p_tickets = client.get("/api/v1/patient-portal/support", headers=headers_p)
    assert p_tickets.status_code == 200
    my_ticket = next(t for t in p_tickets.json()["data"] if t["id"] == ticket_id)
    assert my_ticket["status"] == "RESOLVED"
    assert "exempt from GST" in my_ticket["admin_response"]


def test_admin_dashboard_metrics_and_operational_reporting(client: TestClient, test_setup: dict):
    headers_admin = {"Authorization": f"Bearer {test_setup['token_admin']}"}

    # Operational dashboard summary
    res = client.get("/api/v1/admin/dashboard-summary", headers=headers_admin)
    assert res.status_code == 200
    metrics = res.json()["data"]
    assert "total_patients_registered" in metrics
    assert "visits_today_count" in metrics
    assert "queue_breakdown" in metrics
    assert "revenue_today" in metrics
    assert "low_stock_items_count" in metrics

    # Registration reports (JSON mode)
    rep_res = client.get("/api/v1/admin/reports/registrations", headers=headers_admin)
    assert rep_res.status_code == 200
    rep_data = rep_res.json()["data"]
    assert "total_visits" in rep_data
    assert "status_summary" in rep_data

    # Registration reports (CSV export mode with PII protection)
    csv_res = client.get("/api/v1/admin/reports/registrations?format=csv", headers=headers_admin)
    assert csv_res.status_code == 200
    assert "text/csv" in csv_res.headers["content-type"]
    assert "attachment; filename=opd_registrations_report.csv" in csv_res.headers["content-disposition"]
    csv_content = csv_res.text
    assert "Visit Number,UHID,Department" in csv_content

    # Financial collections CSV report
    fin_res = client.get("/api/v1/admin/reports/billing?format=csv", headers=headers_admin)
    assert fin_res.status_code == 200
    assert "text/csv" in fin_res.headers["content-type"]
    assert "attachment; filename=billing_financial_report.csv" in fin_res.headers["content-disposition"]


def test_staff_account_deactivation_role_change_and_audit(client: TestClient, test_setup: dict, db_session: Session):
    headers_admin = {"Authorization": f"Bearer {test_setup['token_admin']}"}

    # 1. Provision new receptionist staff
    staff_payload = {
        "email": "temp_desk_staff@hospital.com",
        "password": "SecurePassword123!",
        "full_name": "Test Receptionist",
        "role_name": "receptionist",
        "phone": "+919111222333",
    }
    create_res = client.post("/api/v1/admin/users", headers=headers_admin, json=staff_payload)
    assert create_res.status_code == 201
    staff_id = create_res.json()["data"]["id"]

    # 2. Deactivate the staff account
    deactivate_payload = {"is_active": False, "unlock": False}
    deact_res = client.patch(f"/api/v1/admin/users/{staff_id}/status", headers=headers_admin, json=deactivate_payload)
    assert deact_res.status_code == 200
    assert deact_res.json()["data"]["is_active"] is False

    # Verify deactivation audit log
    audit_deact = db_session.query(AuditLog).filter(
        AuditLog.action == "USER_DEACTIVATED",
        AuditLog.entity_id == staff_id
    ).first()
    assert audit_deact is not None
    assert audit_deact.user_id == test_setup["admin_user"].id

    # Verify deactivated user cannot log in
    login_res = client.post(
        "/api/v1/auth/login",
        json={"identifier": "temp_desk_staff@hospital.com", "password": "SecurePassword123!"}
    )
    assert login_res.status_code == 403
    assert "deactivated" in login_res.json()["message"].lower()

    # 3. Change staff role to nurse
    role_change_payload = {"role_name": "nurse"}
    role_res = client.patch(f"/api/v1/admin/users/{staff_id}/role", headers=headers_admin, json=role_change_payload)
    assert role_res.status_code == 200
    assert role_res.json()["data"]["role"]["name"] == "nurse"

    # Verify role change audit log
    audit_role = db_session.query(AuditLog).filter(
        AuditLog.action == "USER_ROLE_CHANGED",
        AuditLog.entity_id == staff_id
    ).first()
    assert audit_role is not None
    assert "nurse" in audit_role.details_json


def test_admin_system_config_and_backup_guidance(client: TestClient, test_setup: dict):
    headers_admin = {"Authorization": f"Bearer {test_setup['token_admin']}"}

    # 1. Fetch system configurations
    conf_res = client.get("/api/v1/admin/system-config", headers=headers_admin)
    assert conf_res.status_code == 200
    configs = conf_res.json()["data"]
    assert any(c["config_key"] == "hospital_name" for c in configs)

    # 2. Update system configuration
    update_res = client.put(
        "/api/v1/admin/system-config",
        headers=headers_admin,
        json={"configs": {"hospital_name": "City Care Memorial Hospital & Research Institute"}}
    )
    assert update_res.status_code == 200
    assert "hospital_name" in update_res.json()["data"]["updated_keys"]

    # 3. Fetch backup guidance
    bg_res = client.get("/api/v1/admin/backup-guidance", headers=headers_admin)
    assert bg_res.status_code == 200
    guidance = bg_res.json()["data"]
    assert guidance["database_engine"] == "SQLite 3.x / WAL Mode"
    assert len(guidance["guidance_checklist"]) > 0
    assert "cron_specification" in guidance

    # 4. Trigger manual snapshot
    snap_res = client.post("/api/v1/admin/backup/export", headers=headers_admin)
    assert snap_res.status_code == 200
    assert "backup_filename" in snap_res.json()["data"]
    assert "opd_connect_backup_" in snap_res.json()["data"]["backup_filename"]
