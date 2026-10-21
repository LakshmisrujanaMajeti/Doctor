import os
import io
import time
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
def receptionist_token():
    return get_token("receptionist@opdconnect.com", "Reception@123456")


@pytest.fixture(scope="module")
def patient_info(admin_token):
    headers = {"Authorization": f"Bearer {admin_token}"}
    res = client.get("/api/v1/patients", headers=headers)
    assert res.status_code == 200
    patients = res.json()["data"]
    assert len(patients) > 0
    return patients[0]


@pytest.fixture(scope="module")
def patient_id(patient_info):
    return patient_info["id"]


@pytest.fixture(scope="module")
def patient_uhid(patient_info):
    return patient_info["uhid"]


@pytest.fixture(scope="module")
def visit_id(admin_token):
    headers = {"Authorization": f"Bearer {admin_token}"}
    res = client.get("/api/v1/visits", headers=headers)
    assert res.status_code == 200
    visits = res.json()["data"]
    assert len(visits) > 0
    return visits[0]["id"]


def test_document_upload_and_security_validation(doctor_token, patient_id):
    headers = {"Authorization": f"Bearer {doctor_token}"}

    # 1. Valid document upload (PDF)
    fake_pdf_content = b"%PDF-1.4 simulated multipage medical booklet scan contents"
    files = {"file": ("opd_booklet_scan_1.pdf", io.BytesIO(fake_pdf_content), "application/pdf")}
    data = {
        "patient_id": patient_id,
        "document_type": "OPD_BOOKLET_SCAN",
        "description": "Scanned physical OPD consultation booklet page 1 and 2",
        "page_count": 2,
    }

    res = client.post("/api/v1/documents/upload", headers=headers, data=data, files=files)
    assert res.status_code == 201, res.text
    doc_data = res.json()["data"]
    assert doc_data["file_name"] == "opd_booklet_scan_1.pdf"
    assert doc_data["page_count"] == 2
    assert doc_data["checksum_sha256"] is not None
    assert doc_data["verification_status"] == "UNVERIFIED"
    assert doc_data["is_verified"] is False
    doc_id = doc_data["id"]

    # 2. Reject Prohibited file extension (e.g. .exe / .sh)
    bad_files = {"file": ("malware.exe", io.BytesIO(b"MZ executable"), "application/x-msdownload")}
    bad_res = client.post("/api/v1/documents/upload", headers=headers, data=data, files=bad_files)
    assert bad_res.status_code == 400
    assert "Prohibited file extension" in bad_res.json()["message"]

    # 3. Retrieve document detail
    detail_res = client.get(f"/api/v1/documents/{doc_id}", headers=headers)
    assert detail_res.status_code == 200
    assert detail_res.json()["data"]["id"] == doc_id


def test_short_lived_signed_access_url(doctor_token, patient_id):
    headers = {"Authorization": f"Bearer {doctor_token}"}

    # Upload an image document
    fake_img = b"\xff\xd8\xff\xe0\x00\x10JFIF simulated jpeg document image data"
    files = {"file": ("ecg_scan.jpg", io.BytesIO(fake_img), "image/jpeg")}
    data = {"patient_id": patient_id, "document_type": "CLINICAL_SUMMARY"}
    upload_res = client.post("/api/v1/documents/upload", headers=headers, data=data, files=files)
    assert upload_res.status_code == 201
    doc_id = upload_res.json()["data"]["id"]

    # Generate short-lived signed link (valid for 15 minutes)
    signed_res = client.post(f"/api/v1/documents/{doc_id}/signed-url?validity_minutes=15", headers=headers)
    assert signed_res.status_code == 200
    link_info = signed_res.json()["data"]
    assert "access_token" in link_info
    assert "preview_url" in link_info
    assert link_info["validity_minutes"] == 15
    token = link_info["access_token"]

    # Preview using signed URL without Authorization header
    preview_res = client.get(f"/api/v1/documents/preview/{token}")
    assert preview_res.status_code == 200
    assert preview_res.headers["content-type"] in ["image/jpeg", "image/jpeg; charset=utf-8"]

    # Tampered token should be rejected (HTTP 403)
    tampered_token = token[:-4] + "abcd"
    tampered_res = client.get(f"/api/v1/documents/preview/{tampered_token}")
    assert tampered_res.status_code == 403

    # Expired token simulation
    expired_token = f"{doc_id}.user-123.{int(time.time()) - 100}.invalid_sig"
    expired_res = client.get(f"/api/v1/documents/preview/{expired_token}")
    assert expired_res.status_code == 403


def test_ocr_extraction_confidence_and_uncertainty(doctor_token, patient_id):
    headers = {"Authorization": f"Bearer {doctor_token}"}

    files = {"file": ("opd_sheet.pdf", io.BytesIO(b"%PDF-1.4 opd booklet"), "application/pdf")}
    data = {"patient_id": patient_id, "document_type": "OPD_BOOKLET_SCAN"}
    upload_res = client.post("/api/v1/documents/upload", headers=headers, data=data, files=files)
    assert upload_res.status_code == 201
    doc_id = upload_res.json()["data"]["id"]

    # Trigger OCR extraction
    ocr_res = client.post(f"/api/v1/documents/{doc_id}/ocr/extract", headers=headers)
    assert ocr_res.status_code == 200
    extractions = ocr_res.json()["data"]
    assert len(extractions) > 0

    categories = {e["field_category"] for e in extractions}
    assert "PATIENT_IDENTIFIER" in categories
    assert "DATE" in categories
    assert "OBSERVATION" in categories
    assert "TEST_NAME" in categories
    assert "PRESCRIPTION" in categories

    # Verify bounding boxes and confidence score preservation
    for ext in extractions:
        assert ext["bounding_box_json"] is not None
        assert 0.0 <= ext["confidence"] <= 1.0
        assert ext["verification_status"] == "UNVERIFIED"

    # Verify that handwritten medication items are marked uncertain
    rx_items = [e for e in extractions if e["field_category"] == "PRESCRIPTION"]
    assert len(rx_items) > 0
    for rx in rx_items:
        assert rx["is_handwritten"] is True
        assert rx["is_uncertain"] is True
        assert rx["confidence"] < 0.80


def test_clinical_verification_safety_and_role_enforcement(
    doctor_token,
    receptionist_token,
    patient_id,
    visit_id
):
    doctor_headers = {"Authorization": f"Bearer {doctor_token}"}
    receptionist_headers = {"Authorization": f"Bearer {receptionist_token}"}

    # Upload booklet
    files = {"file": ("opd_notes.pdf", io.BytesIO(b"%PDF-1.4 opd notes"), "application/pdf")}
    data = {"patient_id": patient_id, "document_type": "OPD_BOOKLET_SCAN", "visit_id": visit_id}
    upload_res = client.post("/api/v1/documents/upload", headers=doctor_headers, data=data, files=files)
    doc_id = upload_res.json()["data"]["id"]

    # Extract OCR fields
    ocr_res = client.post(f"/api/v1/documents/{doc_id}/ocr/extract", headers=doctor_headers)
    extractions = ocr_res.json()["data"]
    rx_field = next(e for e in extractions if e["field_category"] == "PRESCRIPTION")
    patient_name_field = next(e for e in extractions if e["field_name"] == "patient_name")

    # 1. Non-clinician (receptionist) can verify administrative fields like patient_name
    rec_verify_res = client.put(
        f"/api/v1/documents/{doc_id}/ocr/{patient_name_field['id']}/verify",
        headers=receptionist_headers,
        json={"verification_status": "CONFIRMED", "verified_value": "Satya Narayan"}
    )
    assert rec_verify_res.status_code == 200

    # 2. SAFETY RESTRICTION: Non-clinician CANNOT verify handwritten medication / prescription
    rec_rx_res = client.put(
        f"/api/v1/documents/{doc_id}/ocr/{rx_field['id']}/verify",
        headers=receptionist_headers,
        json={"verification_status": "CONFIRMED"}
    )
    assert rec_rx_res.status_code == 403
    assert "authorized clinician" in rec_rx_res.json()["message"]

    # 3. SAFETY BLOCK: Attempting to apply unverified OCR data to active patient visit must FAIL
    apply_fail_res = client.post(
        f"/api/v1/documents/{doc_id}/apply-to-visit",
        headers=doctor_headers,
        json={"visit_id": visit_id, "apply_prescriptions": True}
    )
    assert apply_fail_res.status_code == 400
    assert "Cannot silently convert unverified OCR" in apply_fail_res.json()["message"]

    # 4. Authorized clinician verifies all prescription and observation items
    for e in extractions:
        client.put(
            f"/api/v1/documents/{doc_id}/ocr/{e['id']}/verify",
            headers=doctor_headers,
            json={"verification_status": "CONFIRMED", "verified_value": e["normalized_value"]}
        )

    # Clinician signs off on entire document
    sign_off_res = client.post(
        f"/api/v1/documents/{doc_id}/verify-all",
        headers=doctor_headers,
        json={"clinician_notes": "Reviewed and verified against physical OPD consultation booklet"}
    )
    assert sign_off_res.status_code == 200
    assert sign_off_res.json()["data"]["verification_status"] == "VERIFIED"
    assert sign_off_res.json()["data"]["is_verified"] is True

    # 5. Now transfer verified clinical data to patient visit
    apply_res = client.post(
        f"/api/v1/documents/{doc_id}/apply-to-visit",
        headers=doctor_headers,
        json={
            "visit_id": visit_id,
            "apply_vitals": True,
            "apply_complaints": True,
            "apply_diagnosis": True,
            "apply_prescriptions": True
        }
    )
    assert apply_res.status_code == 200
    result = apply_res.json()["data"]
    assert result["status"] == "APPLIED_SUCCESSFULLY"
    assert result["applied_summary"]["vitals"] is True
    assert result["applied_summary"]["complaints"] is True
    assert result["applied_summary"]["prescriptions_count"] >= 1


def test_barcode_and_qr_non_sensitive_policy_and_resolution(doctor_token, patient_id, patient_uhid, visit_id):
    headers = {"Authorization": f"Bearer {doctor_token}"}

    # 1. Generate non-sensitive Patient Registration QR code
    res_pat = client.post(
        "/api/v1/documents/barcode/generate",
        headers=headers,
        json={"identifier_type": "PATIENT", "resource_id": patient_uhid}
    )
    assert res_pat.status_code == 200
    data_pat = res_pat.json()["data"]
    assert data_pat["token"] == f"UHID:{patient_uhid}"
    assert data_pat["is_non_sensitive"] is True
    assert data_pat["svg_data"] is not None

    # 2. Generate Visit ID, Lab Order, and Specimen QR codes
    for id_type, res_id, prefix in [
        ("VISIT", "VIS-20261012-0001", "VIS:"),
        ("LAB_ORDER", "LAB-ORD-20261012-0001", "LAB:"),
        ("SPECIMEN", "SPEC-HAEM-20261012-0001", "SPEC:"),
    ]:
        res = client.post(
            "/api/v1/documents/barcode/generate",
            headers=headers,
            json={"identifier_type": id_type, "resource_id": res_id}
        )
        assert res.status_code == 200
        assert res.json()["data"]["token"].startswith(prefix)

    # 3. SAFETY POLICY REJECTION: Attempting to embed confidential diagnosis or card details in QR code
    res_bad = client.post(
        "/api/v1/documents/barcode/generate",
        headers=headers,
        json={"identifier_type": "PATIENT", "resource_id": "UHID-1234-diagnosis-cancer-hiv-sensitive-history"}
    )
    assert res_bad.status_code == 400
    assert "Security Policy Violation" in res_bad.json()["message"]

    # 4. Barcode scan resolution
    scan_res = client.post(
        "/api/v1/documents/barcode/scan",
        headers=headers,
        json={"scanned_payload": f"UHID:{patient_uhid}"}
    )
    assert scan_res.status_code == 200
    scan_data = scan_res.json()["data"]
    assert scan_data["identifier_type"] == "PATIENT"
    assert scan_data["resource_id"] == patient_uhid
    assert scan_data["is_valid"] is True


def test_document_audit_logging(doctor_token, patient_id):
    headers = {"Authorization": f"Bearer {doctor_token}"}

    # Upload document
    files = {"file": ("audit_test.pdf", io.BytesIO(b"%PDF-1.4 test audit"), "application/pdf")}
    data = {"patient_id": patient_id, "document_type": "ID_PROOF"}
    upload_res = client.post("/api/v1/documents/upload", headers=headers, data=data, files=files)
    doc_id = upload_res.json()["data"]["id"]

    # Download document
    dl_res = client.get(f"/api/v1/documents/{doc_id}/download", headers=headers)
    assert dl_res.status_code == 200

    # Delete document
    del_res = client.delete(f"/api/v1/documents/{doc_id}", headers=headers)
    assert del_res.status_code == 200

    # Fetch audit logs
    audit_res = client.get(f"/api/v1/documents/{doc_id}/audit-logs", headers=headers)
    assert audit_res.status_code == 200
    logs = audit_res.json()["data"]
    actions = [l["action"] for l in logs]
    assert "UPLOAD" in actions
    assert "DOWNLOAD" in actions
    assert "DELETE" in actions
