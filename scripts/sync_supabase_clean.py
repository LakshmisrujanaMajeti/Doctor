import sys
import os
backend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend"))
sys.path.insert(0, backend_path)
import httpx
from app.core.database import SessionLocal
from sqlalchemy import text

url = 'https://xxwidqatsxzsrulaxxal.supabase.co/rest/v1'
key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4d2lkcWF0c3h6c3J1bGF4eGFsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTc3ODA4OCwiZXhwIjoyMTA3MzU0MDg4fQ.eayg90ZSOAT91ZA8c-mt28kRf3NkZOCvJDtTpRLHy8c'
headers = {
    'apikey': key,
    'Authorization': f'Bearer {key}',
    'Content-Type': 'application/json',
    'Prefer': 'resolution=merge-duplicates'
}

def serialize(obj):
    if obj is None:
        return None
    if hasattr(obj, 'isoformat'):
        return obj.isoformat()
    if isinstance(obj, (int, float, bool, dict, list)):
        return obj
    return str(obj)

client = httpx.Client(timeout=30.0)
db = SessionLocal()

# 1. Sync Departments
departments = [dict(d) for d in db.execute(text('SELECT * FROM departments')).mappings().fetchall()]
for d in departments:
    payload = {k: serialize(v) for k, v in d.items()}
    r = client.post(f'{url}/departments', headers=headers, json=[payload])
    if r.status_code not in (200, 201, 204):
        print('Dept err:', d['code'], r.status_code, r.text)
print('Departments synced.')

# 2. Sync Users
users = [dict(u) for u in db.execute(text('SELECT id, email, phone, hashed_password, full_name, is_active, is_verified, role_id, created_at, updated_at FROM users')).mappings().fetchall()]
for u in users:
    payload = {k: serialize(v) for k, v in u.items()}
    payload['failed_login_attempts'] = 0
    payload['role_id'] = None  # to prevent role fk constraint if not matching
    r = client.post(f'{url}/users', headers=headers, json=[payload])
    if r.status_code not in (200, 201, 204):
        print('User err:', u['email'], r.status_code, r.text)
print('Users synced.')

# 3. Sync Patients
patients = [dict(p) for p in db.execute(text('SELECT * FROM patients')).mappings().fetchall()]
for p in patients:
    payload = {k: serialize(v) for k, v in p.items()}
    payload['registered_by_staff_id'] = None
    r = client.post(f'{url}/patients', headers=headers, json=[payload])
    if r.status_code not in (200, 201, 204):
        print('Patient err:', p['uhid'], r.status_code, r.text)
print(f'Patients synced ({len(patients)} total).')

# 4. Sync Doctors
doctors = [dict(d) for d in db.execute(text('SELECT * FROM doctors')).mappings().fetchall()]
for d in doctors:
    payload = {k: serialize(v) for k, v in d.items()}
    r = client.post(f'{url}/doctors', headers=headers, json=[payload])
    if r.status_code not in (200, 201, 204):
        print('Doctor err:', d['id'], r.status_code, r.text)
print(f'Doctors synced ({len(doctors)} total).')

# 5. Sync OPD Visits
visits = [dict(v) for v in db.execute(text('SELECT * FROM opd_visits')).mappings().fetchall()]
for v in visits:
    payload = {k: serialize(v) for k, v in v.items()}
    r = client.post(f'{url}/opd_visits', headers=headers, json=[payload])
    if r.status_code not in (200, 201, 204):
        print('Visit err:', v['visit_number'], r.status_code, r.text)
print(f'Visits synced ({len(visits)} total).')

db.close()
print('SUPABASE SYNC COMPLETED!')
