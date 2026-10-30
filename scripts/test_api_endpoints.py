import sys
import os
backend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend"))
sys.path.insert(0, backend_path)

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

print("1. Testing GET /api/v1/admin/stats without token:")
res_no_auth = client.get("/api/v1/admin/stats")
print(f"Status: {res_no_auth.status_code}")
print(f"Body: {res_no_auth.text[:300]}")

print("\n2. Testing GET /api/v1/admin/dashboard-summary without token:")
res_dash_no_auth = client.get("/api/v1/admin/dashboard-summary")
print(f"Status: {res_dash_no_auth.status_code}")

print("\n3. Testing GET /api/v1/patients/ without token:")
res_pts = client.get("/api/v1/patients/")
print(f"Status: {res_pts.status_code}")
print(f"Count returned: {len(res_pts.json().get('data', [])) if res_pts.status_code == 200 else res_pts.text[:200]}")
