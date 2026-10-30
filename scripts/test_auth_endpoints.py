import sys
import os
backend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend"))
sys.path.insert(0, backend_path)

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

login_res = client.post("/api/v1/auth/login", json={"identifier": "admin@smvmch.ac.in", "password": "Admin@123"})
print("Login status:", login_res.status_code)
login_json = login_res.json()
print("Login json keys:", list(login_json.keys()))
if "data" in login_json:
    token = login_json["data"]["access_token"]
else:
    token = login_json["access_token"]

headers = {"Authorization": f"Bearer {token}"}

pts_res = client.get("/api/v1/patients/", headers=headers)
print("GET /api/v1/patients/ status:", pts_res.status_code)
pts_data = pts_res.json().get("data", [])
print(f"Total Patients returned by Backend API: {len(pts_data)}")
for p in pts_data:
    print(f"  UHID: {p['uhid']} | Name: {p['full_name']} | Phone: {p['phone']}")
