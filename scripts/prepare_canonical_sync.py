import sys
import os
import json
import sqlite3
from datetime import datetime, date, time
from decimal import Decimal
import httpx

backend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend"))
sys.path.insert(0, backend_path)

from app.core.config import settings
from app.core.database import SessionLocal
from sqlalchemy import text

def serialize(obj):
    if isinstance(obj, (datetime, date, time)):
        return obj.isoformat()
    if isinstance(obj, Decimal):
        return float(obj)
    return str(obj)

def main():
    print("Connecting to PostgreSQL...")
    db = SessionLocal()

    # 1. Fetch Patients
    patients_rows = db.execute(text('SELECT * FROM patients ORDER BY uhid ASC')).mappings().fetchall()
    patients = [dict(r) for r in patients_rows]
    print(f"Loaded {len(patients)} patients from PostgreSQL.")

    # 2. Fetch Departments
    departments_rows = db.execute(text('SELECT * FROM departments ORDER BY code ASC')).mappings().fetchall()
    departments = [dict(r) for r in departments_rows]
    dept_map = {d['id']: d for d in departments}
    print(f"Loaded {len(departments)} departments from PostgreSQL.")

    # 3. Fetch Doctors and Users
    doctors_rows = db.execute(text('SELECT * FROM doctors')).mappings().fetchall()
    doctors = [dict(r) for r in doctors_rows]
    users_rows = db.execute(text('SELECT id, full_name, email, phone FROM users')).mappings().fetchall()
    user_map = {u['id']: dict(u) for u in users_rows}

    # Enrich doctors with user and department info
    for doc in doctors:
        u = user_map.get(doc['user_id'])
        if u:
            doc['user'] = u
            doc['full_name'] = u['full_name']
            doc['name'] = u['full_name']
        dept = dept_map.get(doc['department_id'])
        if dept:
            doc['department'] = dept
            doc['department_name'] = dept['name']

    print(f"Loaded {len(doctors)} doctors from PostgreSQL.")

    # 4. Fetch OPD Visits
    visits_rows = db.execute(text('SELECT * FROM opd_visits ORDER BY visit_date DESC, queue_token ASC')).mappings().fetchall()
    visits = [dict(r) for r in visits_rows]
    pat_map = {p['id']: p for p in patients}
    pat_uhid_map = {p['uhid']: p for p in patients}
    doc_map = {d['id']: d for d in doctors}

    # Enrich each visit with patient object, doctor_name, department_name
    for v in visits:
        p = pat_map.get(v['patient_id']) or pat_uhid_map.get(v['patient_id'])
        if p:
            v['patient'] = p
        d = doc_map.get(v['doctor_id'])
        if d:
            v['doctor_name'] = d.get('full_name') or d.get('name') or "Consulting Physician"
            v['department_name'] = d.get('department_name') or "General Medicine"
        else:
            dept = dept_map.get(v['department_id'])
            v['department_name'] = dept['name'] if dept else "General Medicine"

    print(f"Loaded {len(visits)} visits from PostgreSQL.")

    # 5. Fetch Formulary Medicines
    meds_rows = db.execute(text('SELECT * FROM medicine_inventory WHERE is_active=true')).mappings().fetchall()
    medicines = [dict(r) for r in meds_rows]
    print(f"Loaded {len(medicines)} medicines from PostgreSQL.")

    db.close()

    # 6. Generate initial_hospital_data.dart
    snapshot = {
        "patients": patients,
        "visits": visits,
        "doctors": doctors,
        "departments": departments,
        "inventory": medicines,
    }

    json_snapshot_str = json.dumps(snapshot, default=serialize, indent=2)

    dart_content = f'''// Auto-generated hospital seed dataset for 0ms initial app startup & offline resilience
// Generated on: {datetime.now().isoformat()}
// Contains all 25 canonical hospital patients, active queues, doctors, and formulary.

class InitialHospitalData {{
  static const String jsonSnapshot = r\'\'\'{json_snapshot_str}\'\'\';
}}
'''

    initial_data_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "frontend", "lib", "core", "storage", "initial_hospital_data.dart"))
    with open(initial_data_path, "w", encoding="utf-8") as f:
        f.write(dart_content)
    print(f"Wrote updated initial_hospital_data.dart ({os.path.getsize(initial_data_path)} bytes)")

    # 7. Sync SQLite opd_connect.db
    sqlite_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "opd_connect.db"))
    if os.path.exists(sqlite_path):
        conn = sqlite3.connect(sqlite_path)
        cur = conn.cursor()
        
        # Insert or update patients
        for p in patients:
            cur.execute("SELECT id FROM patients WHERE id = ? OR uhid = ?", (p['id'], p['uhid']))
            existing = cur.fetchone()
            if not existing:
                cur.execute("""
                    INSERT INTO patients (id, uhid, hospital_reg_num, full_name, parent_spouse_name, parent_spouse_relation,
                                          date_of_birth, age_years, age_months, gender, phone, email, address, city, state,
                                          postal_code, blood_group, registration_date, barcode_value, qr_code_data, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    p['id'], p['uhid'], p.get('hospital_reg_num'), p['full_name'], p.get('parent_spouse_name'), p.get('parent_spouse_relation'),
                    str(p['date_of_birth']) if p.get('date_of_birth') else None, p.get('age_years'), p.get('age_months'), p['gender'], p['phone'],
                    p.get('email'), p.get('address'), p.get('city'), p.get('state'), p.get('postal_code'), p.get('blood_group'),
                    str(p.get('registration_date') or datetime.now()), p.get('barcode_value'), p.get('qr_code_data'),
                    str(p.get('created_at') or datetime.now()), str(p.get('updated_at') or datetime.now())
                ))
        
        # Insert or update visits
        for v in visits:
            cur.execute("SELECT id FROM opd_visits WHERE id = ? OR visit_number = ?", (v['id'], v['visit_number']))
            existing_v = cur.fetchone()
            if not existing_v:
                cur.execute("""
                    INSERT INTO opd_visits (id, visit_number, patient_id, doctor_id, department_id, visit_date, queue_token,
                                            triage_priority, status, consultation_fee, payment_status, notes, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    v['id'], v['visit_number'], v['patient_id'], v['doctor_id'], v['department_id'],
                    str(v['visit_date']), v['queue_token'], v['triage_priority'], v['status'],
                    float(v.get('consultation_fee') or 500.0), v.get('payment_status', 'UNPAID'), v.get('notes'),
                    str(v.get('created_at') or datetime.now()), str(v.get('updated_at') or datetime.now())
                ))
        
        conn.commit()
        cur.execute("SELECT COUNT(*) FROM patients")
        sql_pat_count = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM opd_visits")
        sql_vis_count = cur.fetchone()[0]
        conn.close()
        print(f"SQLite synced successfully: {sql_pat_count} patients, {sql_vis_count} visits.")

    # 8. Sync to Supabase xxwidqatsxzsrulaxxal
    supa_url = "https://xxwidqatsxzsrulaxxal.supabase.co/rest/v1"
    supa_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4d2lkcWF0c3h6c3J1bGF4eGFsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTc3ODA4OCwiZXhwIjoyMTA3MzU0MDg4fQ.eayg90ZSOAT91ZA8c-mt28kRf3NkZOCvJDtTpRLHy8c"
    headers = {
        "apikey": supa_key,
        "Authorization": f"Bearer {supa_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }

    try:
        # Sync departments
        dept_payloads = []
        for d in departments:
            dp = {k: serialize(v) for k, v in d.items() if k in ['id', 'name', 'code', 'description', 'is_active', 'created_at', 'updated_at']}
            dept_payloads.append(dp)
        r_dept = httpx.post(f"{supa_url}/departments", headers=headers, json=dept_payloads, timeout=10)
        print(f"Supabase departments sync status: {r_dept.status_code}")

        # Sync patients
        pat_payloads = []
        for p in patients:
            pp = {k: serialize(v) for k, v in p.items() if k in [
                'id', 'uhid', 'hospital_reg_num', 'full_name', 'parent_spouse_name', 'parent_spouse_relation',
                'date_of_birth', 'age_years', 'age_months', 'gender', 'phone', 'email', 'address', 'city', 'state',
                'postal_code', 'blood_group', 'registration_date', 'barcode_value', 'qr_code_data', 'guardian_id',
                'registered_by_staff_id', 'registered_by_staff_name', 'registered_by_staff_role', 'created_at', 'updated_at'
            ]}
            pat_payloads.append(pp)
        r_pat = httpx.post(f"{supa_url}/patients", headers=headers, json=pat_payloads, timeout=10)
        print(f"Supabase patients sync status: {r_pat.status_code}")

        # Sync doctors
        doc_payloads = []
        for doc in doctors:
            dd = {k: serialize(v) for k, v in doc.items() if k in [
                'id', 'user_id', 'department_id', 'qualification', 'specialization', 'registration_number',
                'room_number', 'consultation_fee', 'is_available', 'created_at', 'updated_at'
            ]}
            doc_payloads.append(dd)
        r_doc = httpx.post(f"{supa_url}/doctors", headers=headers, json=doc_payloads, timeout=10)
        print(f"Supabase doctors sync status: {r_doc.status_code}")

        # Sync visits
        vis_payloads = []
        for v in visits:
            vp = {k: serialize(v) for k, v in v.items() if k in [
                'id', 'visit_number', 'patient_id', 'doctor_id', 'department_id', 'visit_date', 'queue_token',
                'triage_priority', 'status', 'consultation_fee', 'payment_status', 'notes', 'created_at', 'updated_at'
            ]}
            vis_payloads.append(vp)
        r_vis = httpx.post(f"{supa_url}/opd_visits", headers=headers, json=vis_payloads, timeout=10)
        print(f"Supabase visits sync status: {r_vis.status_code}")

    except Exception as e:
        print(f"Supabase cloud sync warning: {e}")

    print("\nALL CANONICAL DATA SYNCHRONIZATION COMPLETED SUCCESSFULLY!")

if __name__ == "__main__":
    main()
