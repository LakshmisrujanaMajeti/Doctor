import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def get_token(email: str, password: str) -> str:
    res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert res.status_code == 200, f"Login failed for {email}: {res.text}"
    return res.json()["data"]["access_token"]


@pytest.fixture(scope="module")
def admin_token():
    return get_token("admin@opdconnect.com", "Admin@123456")


@pytest.fixture(scope="module")
def doctor_token():
    return get_token("dr.chen@opdconnect.com", "Doctor@123456")


@pytest.fixture(scope="module")
def lab_token():
    return get_token("lab@opdconnect.com", "Lab@123456")


@pytest.fixture(scope="module")
def receptionist_token():
    return get_token("receptionist@opdconnect.com", "Reception@123456")


@pytest.fixture(scope="module")
def patient_token():
    return get_token("patient@opdconnect.com", "Patient@123456")


def test_laboratory_catalogue_matches_opd_booklet(lab_token):
    headers = {"Authorization": f"Bearer {lab_token}"}
    res = client.get("/api/v1/laboratory/catalogue", headers=headers)
    assert res.status_code == 200
    data = res.json()["data"]

    # Verify all categories exist
    test_names = {item["test_name"] for item in data}
    categories = {item["category"] for item in data}
    assert "BIOCHEMISTRY" in categories
    assert "HAEMATOLOGY" in categories
    assert "MICROBIOLOGY" in categories

    # Verify exact tests from prompt
    # Biochemistry
    assert "Glucose Fasting" in test_names
    assert "Glucose PP" in test_names
    assert "Glucose Random" in test_names
    assert "Urea" in test_names
    assert "Creatinine" in test_names
    assert "Cholesterol" in test_names
    assert "Triglycerides" in test_names
    assert "Glucose Tolerance Test (routine)" in test_names
    assert "Glucose Tolerance Test (pregnancy)" in test_names
    assert "Glucose Challenge Test (GCT)" in test_names

    # Haematology
    assert "Haemoglobin (Hb)" in test_names
    assert "Haematocrit (PCV)" in test_names
    assert "RBC Count" in test_names
    assert "Total Leucocyte Count (TC)" in test_names
    assert "Differential Count (DC)" in test_names
    assert "Platelet Count" in test_names
    assert "ESR" in test_names
    assert "Bleeding Time (BT)" in test_names
    assert "Clotting Time (CT)" in test_names
    assert "Urine Routine" in test_names

    # Microbiology
    assert "Sputum AFB" in test_names
    assert "Stool Ova/Cyst" in test_names
    assert "HIV" in test_names
    assert "VDRL" in test_names

    # Verify sensitive flags
    hiv_item = next(item for item in data if item["test_name"] == "HIV")
    assert hiv_item["is_sensitive"] is True
    vdrl_item = next(item for item in data if item["test_name"] == "VDRL")
    assert hiv_item["is_sensitive"] is True

    hb_item = next(item for item in data if item["test_name"] == "Haemoglobin (Hb)")
    assert hb_item["is_sensitive"] is False


def test_order_creation_with_unique_identifiers(doctor_token):
    headers = {"Authorization": f"Bearer {doctor_token}"}

    # Find a visit
    res_dash = client.get("/api/v1/doctors/me/dashboard", headers=headers)
    assert res_dash.status_code == 200
    visit_id = res_dash.json()["data"]["today_appointments"][0]["id"]

    order_payload = {
        "visit_id": visit_id,
        "test_name": "Glucose Fasting",
        "test_category": "BIOCHEMISTRY",
        "clinical_indication": "Annual glycemic health check",
        "priority": "ROUTINE",
    }
    res = client.post("/api/v1/laboratory/orders", json=order_payload, headers=headers)
    assert res.status_code in [200, 201]
    order = res.json()["data"]

    assert order["order_number"].startswith("LAB-")
    assert order["specimen_id"].startswith("SPEC-")
    assert order["test_name"] == "Glucose Fasting"
    assert order["test_category"] == "BIOCHEMISTRY"
    assert order["status"] == "ORDERED"
    assert order["specimen_status"] == "PENDING_COLLECTION"


def test_specimen_lifecycle_collection_receipt_and_rejection(lab_token, doctor_token):
    doc_headers = {"Authorization": f"Bearer {doctor_token}"}
    lab_headers = {"Authorization": f"Bearer {lab_token}"}

    # Create order
    res_dash = client.get("/api/v1/doctors/me/dashboard", headers=doc_headers)
    visit_id = res_dash.json()["data"]["today_appointments"][0]["id"]

    res_order = client.post(
        "/api/v1/laboratory/orders",
        json={"visit_id": visit_id, "test_name": "Sputum AFB", "test_category": "MICROBIOLOGY"},
        headers=doc_headers,
    )
    order_id = res_order.json()["data"]["id"]

    # 1. Collect Specimen
    res_collect = client.post(
        f"/api/v1/laboratory/orders/{order_id}/collect",
        json={"collector_name": "Nurse Phlebotomist", "specimen_type": "Early Morning Sputum"},
        headers=lab_headers,
    )
    assert res_collect.status_code == 200
    assert res_collect.json()["data"]["status"] == "COLLECTED"
    assert res_collect.json()["data"]["specimen_status"] == "COLLECTED"
    assert res_collect.json()["data"]["collected_by_name"] == "Nurse Phlebotomist"

    # 2. Receive Specimen in Lab
    res_receive = client.post(
        f"/api/v1/laboratory/orders/{order_id}/receive",
        json={"receiver_name": "Marcus Vance"},
        headers=lab_headers,
    )
    assert res_receive.status_code == 200
    assert res_receive.json()["data"]["status"] == "RECEIVED"
    assert res_receive.json()["data"]["specimen_status"] == "RECEIVED"

    # 3. Reject Specimen due to invalid sample quality
    res_reject = client.post(
        f"/api/v1/laboratory/orders/{order_id}/reject",
        json={"rejection_reason": "Salivary sample submitted; inadequate deep pulmonary sputum"},
        headers=lab_headers,
    )
    assert res_reject.status_code == 200
    assert res_reject.json()["data"]["status"] == "REJECTED"
    assert res_reject.json()["data"]["specimen_status"] == "REJECTED"
    assert "inadequate" in res_reject.json()["data"]["rejection_reason"]


def test_result_entry_verification_and_printable_report(lab_token, doctor_token):
    doc_headers = {"Authorization": f"Bearer {doctor_token}"}
    lab_headers = {"Authorization": f"Bearer {lab_token}"}

    res_dash = client.get("/api/v1/doctors/me/dashboard", headers=doc_headers)
    visit_id = res_dash.json()["data"]["today_appointments"][0]["id"]

    # Order Haematology Haemoglobin (Hb)
    res_order = client.post(
        "/api/v1/laboratory/orders",
        json={"visit_id": visit_id, "test_name": "Haemoglobin (Hb)", "test_category": "HAEMATOLOGY"},
        headers=doc_headers,
    )
    order_id = res_order.json()["data"]["id"]

    # Receive specimen directly
    client.post(f"/api/v1/laboratory/orders/{order_id}/receive", json={"receiver_name": "Marcus Vance"}, headers=lab_headers)

    # Enter Results with abnormal flag
    results_payload = {
        "results": [
            {
                "parameter_name": "Haemoglobin",
                "result_value": "9.8",
                "unit": "g/dL",
                "reference_range": "12.0 - 15.5 g/dL",
                "is_abnormal": True,
                "is_critical": False,
                "notes": "Mild microcytic anaemia",
            }
        ]
    }
    res_results = client.post(
        f"/api/v1/laboratory/orders/{order_id}/results",
        json=results_payload,
        headers=lab_headers,
    )
    assert res_results.status_code == 200
    order_data = res_results.json()["data"]
    assert order_data["status"] == "PROCESSING"
    assert order_data["requires_review"] is True
    assert len(order_data["results"]) == 1
    assert order_data["results"][0]["flag"] == "ABNORMAL"

    # Verify results by authorized lab personnel
    res_verify = client.post(
        f"/api/v1/laboratory/orders/{order_id}/verify",
        json={"verification_notes": "Results confirmed on repeat run. Pathologist sign-off complete."},
        headers=lab_headers,
    )
    assert res_verify.status_code == 200
    verified_data = res_verify.json()["data"]
    assert verified_data["status"] == "COMPLETED"
    assert verified_data["published_to_visit"] is True
    assert verified_data["verified_by_name"] is not None

    # Retrieve Printable Report
    res_report = client.get(f"/api/v1/laboratory/orders/{order_id}/report", headers=lab_headers)
    assert res_report.status_code == 200
    report = res_report.json()["data"]
    assert "hospital_name" in report
    assert "verification_seal" in report
    assert report["verification_seal"]["verification_status"] == "VERIFIED & SIGNED"
    assert report["order"]["order_number"] == verified_data["order_number"]


def test_sensitive_test_privacy_and_role_permissions(doctor_token, lab_token, receptionist_token):
    doc_headers = {"Authorization": f"Bearer {doctor_token}"}
    lab_headers = {"Authorization": f"Bearer {lab_token}"}
    rec_headers = {"Authorization": f"Bearer {receptionist_token}"}

    res_dash = client.get("/api/v1/doctors/me/dashboard", headers=doc_headers)
    visit_id = res_dash.json()["data"]["today_appointments"][0]["id"]

    # Order sensitive HIV test
    res_hiv = client.post(
        "/api/v1/laboratory/orders",
        json={"visit_id": visit_id, "test_name": "HIV", "test_category": "MICROBIOLOGY"},
        headers=doc_headers,
    )
    order_id = res_hiv.json()["data"]["id"]
    assert res_hiv.json()["data"]["is_sensitive"] is True

    # 1. Receptionist is forbidden from viewing lab orders / sensitive tests
    res_rec = client.get(f"/api/v1/laboratory/orders/{order_id}", headers=rec_headers)
    assert res_rec.status_code == 403

    # 2. Lab personnel has authorized access
    res_lab = client.get(f"/api/v1/laboratory/orders/{order_id}", headers=lab_headers)
    assert res_lab.status_code == 200
    assert res_lab.json()["data"]["test_name"] == "HIV"

    # 3. Ordering doctor has authorized access
    res_doc = client.get(f"/api/v1/laboratory/orders/{order_id}", headers=doc_headers)
    assert res_doc.status_code == 200
    assert res_doc.json()["data"]["test_name"] == "HIV"


def test_laboratory_dashboard_stats(lab_token):
    headers = {"Authorization": f"Bearer {lab_token}"}
    res = client.get("/api/v1/laboratory/dashboard-stats", headers=headers)
    assert res.status_code == 200
    stats = res.json()["data"]

    assert "pending_collection_count" in stats
    assert "received_processing_count" in stats
    assert "pending_verification_count" in stats
    assert "completed_today_count" in stats
    assert "rejected_count" in stats
    assert "sensitive_tests_count" in stats
