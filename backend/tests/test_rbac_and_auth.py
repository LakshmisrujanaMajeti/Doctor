import pytest
from datetime import datetime, timedelta
from app.core.database import SessionLocal
from app.models.user import User, Role
from app.models.patient import Patient
from app.models.visit import OPDVisit
from app.models.clinical import ClinicalRecord
from app.core.security import get_password_hash


def setup_roles_and_users(db):
    role_names = ["admin", "doctor", "receptionist", "lab_tech", "laboratory", "pharmacist", "patient"]
    roles = {}
    for r in role_names:
        role = db.query(Role).filter(Role.name == r).first()
        if not role:
            role = Role(name=r, description=f"{r} role")
            db.add(role)
            db.flush()
        roles[r] = role

    # 1. Patient 1 (Johnathan)
    p1 = db.query(Patient).filter(Patient.uhid == "UHID-TEST-001").first()
    if not p1:
        p1 = Patient(
            uhid="UHID-TEST-001",
            full_name="Johnathan Test",
            gender="MALE",
            phone="+1555001111",
            email="patient1@test.com"
        )
        db.add(p1)
        db.flush()

    # Dependent of Patient 1 (Tommy)
    dep = db.query(Patient).filter(Patient.uhid == "UHID-TEST-DEP").first()
    if not dep:
        dep = Patient(
            uhid="UHID-TEST-DEP",
            full_name="Tommy Dependent Test",
            gender="MALE",
            phone="+1555001111",
            guardian_id=p1.id
        )
        db.add(dep)
        db.flush()

    # 2. Patient 2 (Unrelated Patient)
    p2 = db.query(Patient).filter(Patient.uhid == "UHID-TEST-002").first()
    if not p2:
        p2 = Patient(
            uhid="UHID-TEST-002",
            full_name="Unrelated Patient",
            gender="FEMALE",
            phone="+1555002222",
            email="patient2@test.com"
        )
        db.add(p2)
        db.flush()

    # Users for all 6 roles
    users_data = [
        ("admin@test.com", "+1555900001", "admin", "Admin User", None),
        ("doctor@test.com", "+1555900002", "doctor", "Dr. Test", None),
        ("receptionist@test.com", "+1555900003", "receptionist", "Receptionist Test", None),
        ("lab@test.com", "+1555900004", "lab_tech", "Lab Tech Test", None),
        ("pharmacist@test.com", "+1555900005", "pharmacist", "Pharmacist Test", None),
        ("patient1@test.com", "+1555001111", "patient", "Johnathan Test", p1.id),
        ("patient2@test.com", "+1555002222", "patient", "Unrelated Patient", p2.id),
    ]

    for email, phone, role_name, full_name, pat_id in users_data:
        u = db.query(User).filter(User.email == email).first()
        if not u:
            u = User(
                email=email,
                phone=phone,
                full_name=full_name,
                hashed_password=get_password_hash("Password@123"),
                role_id=roles[role_name].id,
                patient_id=pat_id,
                is_active=True,
                is_verified=True,
            )
            db.add(u)
            db.flush()

    db.commit()
    return p1, dep, p2


def test_all_six_roles_authenticate(client, db_session):
    setup_roles_and_users(db_session)

    roles_to_test = [
        ("admin@test.com", "Password@123", "admin"),
        ("doctor@test.com", "Password@123", "doctor"),
        ("receptionist@test.com", "Password@123", "receptionist"),
        ("lab@test.com", "Password@123", "lab_tech"),
        ("pharmacist@test.com", "Password@123", "pharmacist"),
        ("patient1@test.com", "Password@123", "patient"),
    ]

    for email, pwd, expected_role in roles_to_test:
        res = client.post("/api/v1/auth/login", json={"email": email, "password": pwd})
        assert res.status_code == 200, f"Failed for {email}: {res.text}"
        data = res.json()["data"]
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["user"]["role"]["name"] == expected_role


def test_login_with_phone_number(client, db_session):
    setup_roles_and_users(db_session)

    # Login using phone identifier instead of email
    res = client.post("/api/v1/auth/login", json={"phone": "+1555900002", "password": "Password@123"})
    assert res.status_code == 200
    assert res.json()["data"]["user"]["email"] == "doctor@test.com"


def test_failed_login_attempts_and_lockout(client, db_session):
    setup_roles_and_users(db_session)
    email = "doctor@test.com"

    # Attempt 4 failed logins
    for i in range(4):
        res = client.post("/api/v1/auth/login", json={"email": email, "password": "WrongPassword"})
        assert res.status_code == 401

    # 5th failed attempt triggers lockout
    res5 = client.post("/api/v1/auth/login", json={"email": email, "password": "WrongPassword"})
    assert res5.status_code == 401
    assert "locked" in res5.json()["message"].lower()

    # Even with correct password, account is locked
    res_locked = client.post("/api/v1/auth/login", json={"email": email, "password": "Password@123"})
    assert res_locked.status_code == 401
    assert "locked" in res_locked.json()["message"].lower()


def test_deactivated_account_rejection(client, db_session):
    setup_roles_and_users(db_session)
    user = db_session.query(User).filter(User.email == "receptionist@test.com").first()
    user.is_active = False
    db_session.commit()

    res = client.post("/api/v1/auth/login", json={"email": "receptionist@test.com", "password": "Password@123"})
    assert res.status_code == 403
    assert "deactivated" in res.json()["message"].lower()


def test_logout_and_revocation(client, db_session):
    setup_roles_and_users(db_session)
    login_res = client.post("/api/v1/auth/login", json={"email": "admin@test.com", "password": "Password@123"})
    refresh_token = login_res.json()["data"]["refresh_token"]

    # Logout
    logout_res = client.post("/api/v1/auth/logout", json={"refresh_token": refresh_token})
    assert logout_res.status_code == 200

    # Refresh with revoked token should now fail
    ref_res = client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    assert ref_res.status_code == 401


def test_forgot_password_and_reset_flow(client, db_session):
    setup_roles_and_users(db_session)
    # Request recovery
    req_res = client.post("/api/v1/auth/forgot-password", json={"identifier": "pharmacist@test.com"})
    assert req_res.status_code == 200
    mock_token_str = req_res.json()["data"]["dev_mock_token"]
    assert mock_token_str is not None
    raw_token = mock_token_str.replace("[DEV_MOCK_RESET_TOKEN] ", "").strip()

    # Reset password with token
    reset_res = client.post("/api/v1/auth/reset-password", json={
        "token": raw_token,
        "new_password": "NewSecretPassword@999"
    })
    assert reset_res.status_code == 200

    # Login with new password
    new_login = client.post("/api/v1/auth/login", json={
        "email": "pharmacist@test.com",
        "password": "NewSecretPassword@999"
    })
    assert new_login.status_code == 200


def test_otp_dispatch_and_verification(client, db_session):
    setup_roles_and_users(db_session)
    # Send OTP
    send_res = client.post("/api/v1/auth/otp/send", json={"identifier": "+1555900001", "purpose": "login"})
    assert send_res.status_code == 200
    mock_otp_str = send_res.json()["data"]["dev_mock_otp"]
    assert mock_otp_str is not None
    otp_code = mock_otp_str.replace("[DEV_MOCK_OTP_ONLY] ", "").strip()

    # Verify OTP
    verify_res = client.post("/api/v1/auth/otp/verify", json={
        "identifier": "+1555900001",
        "otp": otp_code,
        "purpose": "login"
    })
    assert verify_res.status_code == 200


def test_patient_privacy_and_cross_record_isolation(client, db_session):
    p1, dep, p2 = setup_roles_and_users(db_session)

    # Login as Patient 1
    p1_login = client.post("/api/v1/auth/login", json={"email": "patient1@test.com", "password": "Password@123"})
    p1_token = p1_login.json()["data"]["access_token"]
    p1_headers = {"Authorization": f"Bearer {p1_token}"}

    # 1. Patient 1 accesses own record -> 200 OK
    res_own = client.get(f"/api/v1/patients/{p1.id}", headers=p1_headers)
    assert res_own.status_code == 200
    assert res_own.json()["data"]["uhid"] == "UHID-TEST-001"

    # 2. Patient 1 accesses linked dependent record (Tommy) -> 200 OK
    res_dep = client.get(f"/api/v1/patients/{dep.id}", headers=p1_headers)
    assert res_dep.status_code == 200
    assert res_dep.json()["data"]["uhid"] == "UHID-TEST-DEP"

    # 3. Patient 1 attempts to access Patient 2 (Unrelated Patient) -> 403 Forbidden!
    res_cross = client.get(f"/api/v1/patients/{p2.id}", headers=p1_headers)
    assert res_cross.status_code == 403
    assert "forbidden" in res_cross.json()["message"].lower()

    # 4. Patient 1 GET /patients list returns ONLY self and dependent
    res_list = client.get("/api/v1/patients", headers=p1_headers)
    assert res_list.status_code == 200
    patients_retrieved = res_list.json()["data"]
    retrieved_ids = {p["id"] for p in patients_retrieved}
    assert p1.id in retrieved_ids
    assert dep.id in retrieved_ids
    assert p2.id not in retrieved_ids


def test_rbac_access_restrictions_deny_by_default(client, db_session):
    p1, dep, p2 = setup_roles_and_users(db_session)

    # Receptionist login
    rec_login = client.post("/api/v1/auth/login", json={"email": "receptionist@test.com", "password": "Password@123"})
    rec_token = rec_login.json()["data"]["access_token"]
    rec_headers = {"Authorization": f"Bearer {rec_token}"}

    # Receptionist attempts to create clinical diagnoses / records -> 403 Forbidden!
    res_rec_clinical = client.post("/api/v1/clinical-records", json={
        "visit_id": "dummy-visit-id",
        "chief_complaint": "Headache",
        "final_diagnosis": "Migraine"
    }, headers=rec_headers)
    assert res_rec_clinical.status_code == 403

    # Receptionist attempts to create prescription -> 403 Forbidden!
    res_rec_rx = client.post("/api/v1/prescriptions", json={
        "visit_id": "dummy-visit-id",
        "items": []
    }, headers=rec_headers)
    assert res_rec_rx.status_code == 403

    # Lab Tech login
    lab_login = client.post("/api/v1/auth/login", json={"email": "lab@test.com", "password": "Password@123"})
    lab_token = lab_login.json()["data"]["access_token"]
    lab_headers = {"Authorization": f"Bearer {lab_token}"}

    # Lab Tech attempts to create prescription -> 403 Forbidden!
    res_lab_rx = client.post("/api/v1/prescriptions", json={
        "visit_id": "dummy-visit-id",
        "items": []
    }, headers=lab_headers)
    assert res_lab_rx.status_code == 403

    # Doctor login
    doc_login = client.post("/api/v1/auth/login", json={"email": "doctor@test.com", "password": "Password@123"})
    doc_token = doc_login.json()["data"]["access_token"]
    doc_headers = {"Authorization": f"Bearer {doc_token}"}

    # Doctor attempts to dispense pharmacy order -> 403 Forbidden!
    res_doc_dispense = client.patch("/api/v1/pharmacy/orders/dummy-id/dispense", headers=doc_headers)
    assert res_doc_dispense.status_code == 403

    # Unauthenticated request without token -> 401 Unauthorized
    res_no_auth = client.get("/api/v1/patients")
    assert res_no_auth.status_code == 401
