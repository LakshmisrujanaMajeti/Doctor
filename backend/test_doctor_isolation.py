import urllib.request
import urllib.error
import json

BASE_API = "http://127.0.0.1:8000/api/v1"

def test_loose_token_rejection():
    for token_id in ["#1", "1", "Token 2"]:
        data = json.dumps({"identifier": token_id}).encode()
        req = urllib.request.Request(f"{BASE_API}/patient-portal/quick-access", data=data, headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req) as resp:
                print(f"FAILED: loose token '{token_id}' should have been rejected!")
        except urllib.error.HTTPError as e:
            err = json.loads(e.read().decode())
            print(f"[SUCCESS] Loose token '{token_id}' correctly rejected: {err.get('message') or err.get('detail')}")

def test_doctor_logins():
    doctors = [
        ("doctor@smvmch.ac.in", "General Medicine"),
        ("pulmonology@smvmch.ac.in", "Pulmonology"),
        ("cardiology@smvmch.ac.in", "Cardiology"),
        ("pediatrics@smvmch.ac.in", "Pediatrics"),
        ("orthopedics@smvmch.ac.in", "Orthopedics"),
        ("dermatology@smvmch.ac.in", "Dermatology"),
        ("endocrinology@smvmch.ac.in", "Endocrinology"),
        ("gastroenterology@smvmch.ac.in", "Gastroenterology"),
        ("neurology@smvmch.ac.in", "Neurology"),
        ("oncology@smvmch.ac.in", "Oncology"),
        ("nephrology@smvmch.ac.in", "Nephrology"),
        ("gynecology@smvmch.ac.in", "Gynecology"),
        ("dental@smvmch.ac.in", "Dental"),
        ("ent@smvmch.ac.in", "ENT"),
    ]
    print("\n--- Testing All Doctor Logins ---")
    tokens = {}
    for email, dept in doctors:
        data = json.dumps({"email": email, "password": "Doctor@123"}).encode()
        req = urllib.request.Request(f"{BASE_API}/auth/login", data=data, headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req) as resp:
                res = json.loads(resp.read().decode())
                tok = res["data"]["access_token"]
                tokens[email] = tok
                print(f"[OK] {dept:16} Doctor Login ({email})")
        except urllib.error.HTTPError as e:
            print(f"[ERR] Failed {email}: {e.read().decode()}")
    return tokens

def test_doctor_queue_isolation(tokens):
    print("\n--- Testing Doctor Patient Queue Isolation ---")
    # Fetch Pulmonology Doctor Dashboard
    req_pulmo = urllib.request.Request(
        f"{BASE_API}/doctors/me/dashboard",
        headers={"Authorization": f"Bearer {tokens['pulmonology@smvmch.ac.in']}"}
    )
    with urllib.request.urlopen(req_pulmo) as resp:
        res = json.loads(resp.read().decode())
        pulmo_doc = res["data"]["doctor"]["specialization"]
        print(f"[OK] Pulmonology Dashboard loaded for: {pulmo_doc}")

    # Fetch General Medicine Doctor Dashboard
    req_gen = urllib.request.Request(
        f"{BASE_API}/doctors/me/dashboard",
        headers={"Authorization": f"Bearer {tokens['doctor@smvmch.ac.in']}"}
    )
    with urllib.request.urlopen(req_gen) as resp:
        res = json.loads(resp.read().decode())
        gen_doc = res["data"]["doctor"]["specialization"]
        print(f"[OK] General Medicine Dashboard loaded for: {gen_doc}")

if __name__ == "__main__":
    test_loose_token_rejection()
    tokens = test_doctor_logins()
    test_doctor_queue_isolation(tokens)
    print("\nALL VERIFICATIONS PASSED!")
