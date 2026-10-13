import pytest
from datetime import date


def get_doctor_and_receptionist_headers(client):
    # Register Doctor
    client.post("/api/v1/auth/register", json={
        "email": "dr_booklet@opdconnect.com",
        "password": "Password@123",
        "full_name": "Dr. Booklet Tester",
        "role_name": "doctor"
    })
    doc_login = client.post("/api/v1/auth/login", json={
        "email": "dr_booklet@opdconnect.com",
        "password": "Password@123"
    })
    doc_token = doc_login.json()["data"]["access_token"]
    doc_user_id = doc_login.json()["data"]["user"]["id"]

    # Register Receptionist
    client.post("/api/v1/auth/register", json={
        "email": "reception_booklet@opdconnect.com",
        "password": "Password@123",
        "full_name": "Receptionist Tester",
        "role_name": "receptionist"
    })
    rec_login = client.post("/api/v1/auth/login", json={
        "email": "reception_booklet@opdconnect.com",
        "password": "Password@123"
    })
    rec_token = rec_login.json()["data"]["access_token"]

    return (
        {"Authorization": f"Bearer {doc_token}"},
        doc_user_id,
        {"Authorization": f"Bearer {rec_token}"}
    )


def test_patient_registration_opd_booklet_fields_and_duplicate_prevention(client):
    doc_headers, doc_user_id, rec_headers = get_doctor_and_receptionist_headers(client)

    # 1. Register Patient with complete OPD booklet fields
    patient_payload = {
        "full_name": "Aarav Sharma",
        "parent_spouse_name": "Dev Sharma",
        "parent_spouse_relation": "S/o",
        "date_of_birth": "1995-08-20",
        "age_years": 31,
        "age_months": 2,
        "gender": "MALE",
        "phone": "+919876543210",
        "email": "aarav.sharma@example.com",
        "address": "Flat 402, Lotus Towers, Main Road",
        "city": "Hyderabad",
        "state": "Telangana",
        "postal_code": "500081",
        "blood_group": "B+",
        "emergency_contact_name": "Dev Sharma",
        "emergency_contact_phone": "+919876543211",
        "emergency_contact_relation": "Father"
    }

    create_res = client.post("/api/v1/patients", json=patient_payload, headers=rec_headers)
    assert create_res.status_code == 200
    pdata = create_res.json()["data"]
    patient_id = pdata["id"]

    # Verify auto-generated fields
    assert pdata["uhid"].startswith("UHID-")
    assert pdata["hospital_reg_num"].startswith("REG-")
    assert pdata["barcode_value"].startswith("BAR-")
    assert "OPDCONNECT+" in pdata["qr_code_data"]
    assert pdata["parent_spouse_name"] == "Dev Sharma"
    assert pdata["parent_spouse_relation"] == "S/o"
    assert pdata["city"] == "Hyderabad"
    assert pdata["postal_code"] == "500081"

    # 2. Duplicate Detection Workflow
    dup_check_res = client.post("/api/v1/patients/check-duplicate", json={
        "phone": "+919876543210",
        "full_name": "Aarav Sharma"
    }, headers=rec_headers)
    assert dup_check_res.status_code == 200
    dup_check = dup_check_res.json()["data"]
    assert dup_check["is_duplicate"] is True
    assert len(dup_check["candidates"]) >= 1
    assert dup_check["candidates"][0]["uhid"] == pdata["uhid"]

    # 3. Prevent accidental duplicate registration (Throws 409 Conflict)
    duplicate_payload = {
        "full_name": "Aarav Sharma",
        "gender": "MALE",
        "phone": "+919876543210",
    }
    collision_res = client.post("/api/v1/patients", json=duplicate_payload, headers=rec_headers)
    assert collision_res.status_code == 409
    err_msg = collision_res.json().get("message", "") or collision_res.json().get("detail", "")
    assert "Accidental duplicate prevented" in err_msg

    # 4. Search patient by Registration Number and Barcode
    reg_lookup = client.get(f"/api/v1/patients/reg/{pdata['hospital_reg_num']}", headers=rec_headers)
    assert reg_lookup.status_code == 200
    assert reg_lookup.json()["data"]["id"] == patient_id

    barcode_lookup = client.get(f"/api/v1/patients/barcode/{pdata['barcode_value']}", headers=rec_headers)
    assert barcode_lookup.status_code == 200
    assert barcode_lookup.json()["data"]["id"] == patient_id

    # 5. Controlled search query
    search_res = client.get("/api/v1/patients?query=Aarav", headers=rec_headers)
    assert search_res.status_code == 200
    assert any(p["id"] == patient_id for p in search_res.json()["data"])


def test_clinical_consultation_sheet_draft_and_amendment_workflow(client):
    doc_headers, doc_user_id, rec_headers = get_doctor_and_receptionist_headers(client)

    # Department and Doctor setup
    dept_res = client.post("/api/v1/departments", json={
        "name": "Pulmonology & Chest Clinic",
        "code": "PULM",
        "description": "Respiratory and chest medicine"
    }, headers=doc_headers)
    dept_id = dept_res.json()["data"]["id"]

    doc_res = client.post("/api/v1/doctors", json={
        "user_id": doc_user_id,
        "department_id": dept_id,
        "qualification": "MD (Pulmonary Medicine)",
        "specialization": "Pulmonologist",
        "registration_number": "PULM-7788",
        "room_number": "OPD 302"
    }, headers=doc_headers)
    doc_id = doc_res.json()["data"]["id"]

    # Create Patient
    pat_res = client.post("/api/v1/patients", json={
        "full_name": "Sunita Verma",
        "parent_spouse_name": "Vikram Verma",
        "parent_spouse_relation": "W/o",
        "gender": "FEMALE",
        "phone": "+919811223344",
        "age_years": 45,
        "blood_group": "O+"
    }, headers=rec_headers)
    patient_id = pat_res.json()["data"]["id"]

    # Create OPD Visit
    visit_res = client.post("/api/v1/visits", json={
        "patient_id": patient_id,
        "doctor_id": doc_id,
        "department_id": dept_id,
        "triage_priority": "PRIORITY",
        "consultation_fee": 700.0
    }, headers=rec_headers)
    visit_id = visit_res.json()["data"]["id"]

    # Record Comprehensive Booklet Vitals
    vitals_res = client.post(f"/api/v1/visits/{visit_id}/vitals", json={
        "visit_id": visit_id,
        "systolic_bp": 134,
        "diastolic_bp": 86,
        "pulse_rate": 84,
        "temperature_f": 99.1,
        "spo2_percent": 95.0,
        "respiratory_rate": 20,
        "weight_kg": 62.0,
        "height_cm": 158.0,
        "blood_glucose_mg_dl": 142.0,
        "notes": "Patient reports dyspnea on moderate exertion"
    }, headers=doc_headers)
    assert vitals_res.status_code == 200
    assert vitals_res.json()["data"]["blood_glucose_mg_dl"] == 142.0
    assert vitals_res.json()["data"]["bmi"] == 24.8

    # 1. Autosave / Draft Clinical Consultation Sheet
    draft_payload = {
        "visit_id": visit_id,
        "status": "DRAFT",
        "presenting_complaint": "Persistent dry cough for 3 weeks and breathlessness on exertion",
        "history_of_present_illness": "Symptoms worse in early mornings and after dust exposure.",
        "allergies": "Sulfa drugs (produces urticaria)",
        "past_medical_history": "Childhood wheezing episodes",
        "prior_hospitalization": "None",
        "hypertension_history": "Borderline elevated BP, not on therapy",
        "diabetes_history": "Impaired fasting glucose",
        "asthma_history": "Occasional Salbutamol inhaler use 5 years ago",
        "tuberculosis_history": "Negative, no household contacts",
        "smoking_history": "Non-smoker",
        "alcohol_history": "None",
        "family_history": "Mother had bronchial asthma",
        "general_examination": "Mild tachypnea. No cyanosis or clubbing.",
        "respiratory_examination": "Bilateral end-expiratory wheeze. Prolonged expiration.",
        "cardiovascular_examination": "S1 S2 normal, tachycardia 84 bpm.",
        "gastrointestinal_examination": "Abdomen soft, non-tender.",
        "cns_examination": "Alert and conscious.",
        "other_examination_findings": "Nasal mucosa boggy, pale turbinates.",
        "provisional_diagnosis": "Cough Variant Asthma vs Post-viral Bronchial Hyperresponsiveness",
        "care_plan": "Inhaled Budesonide/Formoterol 200/6 mcg 1 puff BD.",
        "investigations_requested": "Chest X-Ray PA view, Spirometry with reversibility, Complete Blood Count",
        "dietary_advice": "Avoid cold foods and exposure to allergens/dust",
        "follow_up_date": "2026-10-26"
    }

    draft_res = client.post("/api/v1/clinical-records", json=draft_payload, headers=doc_headers)
    assert draft_res.status_code == 200
    draft_data = draft_res.json()["data"]
    record_id = draft_data["id"]
    assert draft_data["status"] == "DRAFT"
    assert draft_data["version"] == 1
    assert draft_data["signed_by_user_id"] is None

    # Visit should still be in progress (e.g. TRIAGED), not COMPLETED while draft
    visit_check = client.get(f"/api/v1/visits/{visit_id}", headers=doc_headers)
    assert visit_check.json()["data"]["status"] == "TRIAGED"

    # 2. Update Draft safely
    draft_payload["provisional_diagnosis"] = "Bronchial Asthma (Moderate Persistent)"
    update_draft_res = client.post("/api/v1/clinical-records", json=draft_payload, headers=doc_headers)
    assert update_draft_res.status_code == 200
    assert update_draft_res.json()["data"]["provisional_diagnosis"] == "Bronchial Asthma (Moderate Persistent)"

    # 3. Doctor Signs and Finalizes Record
    sign_res = client.post(f"/api/v1/clinical-records/{record_id}/sign", headers=doc_headers)
    assert sign_res.status_code == 200
    signed_data = sign_res.json()["data"]
    assert signed_data["status"] == "FINALIZED"
    assert signed_data["signed_by_user_id"] == doc_user_id
    assert signed_data["signed_at"] is not None

    # Visit status is now COMPLETED
    visit_check2 = client.get(f"/api/v1/visits/{visit_id}", headers=doc_headers)
    assert visit_check2.json()["data"]["status"] == "COMPLETED"

    # 4. Data Integrity: Silent Overwrite is STRICTLY PREVENTED
    overwrite_attempt = client.post("/api/v1/clinical-records", json={
        "visit_id": visit_id,
        "presenting_complaint": "Overwritten complaint",
    }, headers=doc_headers)
    assert overwrite_attempt.status_code == 409
    err_msg2 = overwrite_attempt.json().get("message", "") or overwrite_attempt.json().get("detail", "")
    assert "already been finalized/signed" in err_msg2

    # 5. Non-Repudiation Amendment Workflow
    # Doctor amends final record with ICD-10 code and updated care plan
    amend_payload = {
        "final_diagnosis": "Bronchial Asthma, uncomplicated (ICD-10 J45.909)",
        "icd10_code": "J45.909",
        "care_plan": "Budesonide/Formoterol 200/6 mcg 2 puffs BD + Montelukast 10mg OD",
        "amendment_reason": "Spirometry confirmed reversible airway obstruction (FEV1 improved 16% post-bronchodilator)"
    }
    amend_res = client.post(f"/api/v1/clinical-records/{record_id}/amend", json=amend_payload, headers=doc_headers)
    assert amend_res.status_code == 200
    amended_data = amend_res.json()["data"]
    assert amended_data["status"] == "AMENDED"
    assert amended_data["version"] == 2
    assert amended_data["icd10_code"] == "J45.909"
    assert "Spirometry confirmed" in amended_data["amendment_reason"]

    # 6. Verify Audit Amendment History
    audit_res = client.get(f"/api/v1/clinical-records/{record_id}/amendments", headers=doc_headers)
    assert audit_res.status_code == 200
    amendments = audit_res.json()["data"]
    assert len(amendments) == 1
    assert amendments[0]["reason"] == amend_payload["amendment_reason"]
    assert "previous_snapshot_json" in amendments[0]
    # Check that previous snapshot captured version 1 state
    assert '"version": 1' in amendments[0]["previous_snapshot_json"]

    # 7. Access Control check: Receptionist must not access clinical examination sheet
    rec_access = client.get(f"/api/v1/clinical-records/{record_id}", headers=rec_headers)
    assert rec_access.status_code == 403
