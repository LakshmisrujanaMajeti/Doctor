def get_auth_headers(client):
    reg_payload = {
        "email": "staff_patient_test@opdconnect.com",
        "password": "Password@123",
        "full_name": "Test Receptionist",
        "role_name": "receptionist"
    }
    client.post("/api/v1/auth/register", json=reg_payload)
    login_res = client.post("/api/v1/auth/login", json={
        "email": "staff_patient_test@opdconnect.com",
        "password": "Password@123"
    })
    token = login_res.json()["data"]["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_patient_registration_and_search(client):
    headers = get_auth_headers(client)

    # 1. Create Patient
    payload = {
        "full_name": "Arthur Dent",
        "date_of_birth": "1982-03-11",
        "age_years": 44,
        "gender": "MALE",
        "phone": "+1555424242",
        "email": "arthur@dent.example.com",
        "address": "42 Galaxy Way",
        "blood_group": "AB+",
        "emergency_contact_name": "Ford Prefect",
        "emergency_contact_phone": "+1555424243"
    }
    res = client.post("/api/v1/patients", json=payload, headers=headers)
    assert res.status_code == 200
    data = res.json()["data"]
    assert "uhid" in data
    assert data["uhid"].startswith("UHID-")
    patient_id = data["id"]
    uhid = data["uhid"]

    # 2. Get by ID
    get_res = client.get(f"/api/v1/patients/{patient_id}", headers=headers)
    assert get_res.status_code == 200
    assert get_res.json()["data"]["full_name"] == "Arthur Dent"

    # 3. Get by UHID
    uhid_res = client.get(f"/api/v1/patients/uhid/{uhid}", headers=headers)
    assert uhid_res.status_code == 200
    assert uhid_res.json()["data"]["id"] == patient_id

    # 4. Search by Name
    search_res = client.get("/api/v1/patients?query=Arthur", headers=headers)
    assert search_res.status_code == 200
    results = search_res.json()["data"]
    assert len(results) >= 1
    assert any(p["id"] == patient_id for p in results)

    # 5. Download Booklet by Registration ID (UHID)
    dl_res = client.get(f"/api/v1/patients/download-by-reg/{uhid}", headers=headers)
    assert dl_res.status_code == 200
    assert dl_res.headers["content-type"] == "application/pdf"
    assert dl_res.content[:4] == b"%PDF"

    # 6. Verify staff attribution fields are recorded on patient record
    assert data.get("registered_by_staff_name") == "Test Receptionist"
    assert data.get("registered_by_staff_role") == "receptionist"

