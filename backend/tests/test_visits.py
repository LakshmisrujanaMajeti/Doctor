def get_auth_headers(client):
    reg_payload = {
        "email": "doctor_visit_test@opdconnect.com",
        "password": "Password@123",
        "full_name": "Doctor Visit Tester",
        "role_name": "doctor"
    }
    client.post("/api/v1/auth/register", json=reg_payload)
    login_res = client.post("/api/v1/auth/login", json={
        "email": "doctor_visit_test@opdconnect.com",
        "password": "Password@123"
    })
    token = login_res.json()["data"]["access_token"]
    user_id = login_res.json()["data"]["user"]["id"]
    return {"Authorization": f"Bearer {token}"}, user_id


def test_opd_visit_and_vitals_workflow(client):
    headers, user_id = get_auth_headers(client)

    # 1. Create Department
    dept_res = client.post("/api/v1/departments", json={
        "name": "General Surgery",
        "code": "SURG",
        "description": "Surgical consultations"
    }, headers=headers)
    assert dept_res.status_code == 200
    dept_id = dept_res.json()["data"]["id"]

    # 2. Create Doctor Profile
    doc_res = client.post("/api/v1/doctors", json={
        "user_id": user_id,
        "department_id": dept_id,
        "qualification": "MS (General Surgery)",
        "specialization": "Surgery",
        "registration_number": "MED-REG-55443",
        "room_number": "Room 201"
    }, headers=headers)
    assert doc_res.status_code == 200
    doc_id = doc_res.json()["data"]["id"]

    # 3. Create Patient
    pat_res = client.post("/api/v1/patients", json={
        "full_name": "Clara Oswald",
        "gender": "FEMALE",
        "phone": "+1555777888",
        "age_years": 29
    }, headers=headers)
    assert pat_res.status_code == 200
    patient_id = pat_res.json()["data"]["id"]

    # 4. Create OPD Visit & Issue Token
    visit_res = client.post("/api/v1/visits", json={
        "patient_id": patient_id,
        "doctor_id": doc_id,
        "department_id": dept_id,
        "triage_priority": "NORMAL",
        "consultation_fee": 600.0
    }, headers=headers)
    assert visit_res.status_code == 200
    visit_data = visit_res.json()["data"]
    visit_id = visit_data["id"]
    assert visit_data["queue_token"] == 1
    assert visit_data["status"] == "REGISTERED"

    # 5. Record Vitals & Calculate BMI
    vitals_res = client.post(f"/api/v1/visits/{visit_id}/vitals", json={
        "visit_id": visit_id,
        "systolic_bp": 118,
        "diastolic_bp": 78,
        "pulse_rate": 72,
        "temperature_f": 98.4,
        "spo2_percent": 99.0,
        "height_cm": 165.0,
        "weight_kg": 58.0
    }, headers=headers)
    assert vitals_res.status_code == 200
    vitals_data = vitals_res.json()["data"]
    assert vitals_data["bmi"] == 21.3

    # Check that visit status progressed to TRIAGED
    visit_check = client.get(f"/api/v1/visits/{visit_id}", headers=headers)
    assert visit_check.json()["data"]["status"] == "TRIAGED"

    # 6. Record Clinical Examination (OPD Booklet sheet)
    clinic_res = client.post("/api/v1/clinical-records", json={
        "visit_id": visit_id,
        "chief_complaint": "Right lower quadrant abdominal pain for 12 hours",
        "history_of_present_illness": "Sudden onset periumbilical pain migrating to right iliac fossa.",
        "physical_examination": "Tenderness at McBurney's point. Rebound tenderness present.",
        "provisional_diagnosis": "Acute Appendicitis",
        "icd10_code": "K35.80",
        "clinical_notes": "Surgical consultation and urgent ultrasound abdomen ordered.",
    }, headers=headers)
    assert clinic_res.status_code == 200
    assert clinic_res.json()["data"]["provisional_diagnosis"] == "Acute Appendicitis"

    # Check that visit status progressed to COMPLETED
    visit_check2 = client.get(f"/api/v1/visits/{visit_id}", headers=headers)
    assert visit_check2.json()["data"]["status"] == "COMPLETED"
