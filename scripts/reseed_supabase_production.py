#!/usr/bin/env python3
"""
Complete Production Reseeder for SMVMCH OPD Connect+ Supabase PostgreSQL
Clears all legacy/test seed records and inserts:
- 8 System Roles
- 6 Clinical Hospital Departments
- 30 Staff Accounts:
    * 1 Hospital Admin
    * 18 Doctors (3 for each of the 6 departments)
    * 2 Receptionists
    * 5 Pharmacists
    * 3 Laboratory Technicians
    * 4 Billing Counter Staff
- 18 Doctor Clinical Profiles
- 20 Patients with distinct health conditions, vitals, and medical histories
- 20 Live OPD Visits with Tokens, Triage Priorities, and Statuses
- 20 Vital Signs records
- 20 Clinical Records & Diagnoses with ICD-10 classifications
- 20 Prescriptions & Prescription Items
- 10 Laboratory Investigation Orders & Results
- 28 Formulary Medicine Inventory items
"""

import json
import urllib.request
import urllib.error
from datetime import datetime, date, timedelta

SUPABASE_URL = "https://xxwidqatsxzsrulaxxal.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4d2lkcWF0c3h6c3J1bGF4eGFsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTc3ODA4OCwiZXhwIjoyMTA3MzU0MDg4fQ.eayg90ZSOAT91ZA8c-mt28kRf3NkZOCvJDtTpRLHy8c"

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates,return=representation",
}

def postgrest_delete(table: str):
    """Delete all rows from a table using PostgREST filter."""
    url = f"{SUPABASE_URL}/rest/v1/{table}?id=neq.00000000-0000-0000-0000-000000000000"
    req = urllib.request.Request(url, headers=HEADERS, method="DELETE")
    try:
        with urllib.request.urlopen(req) as resp:
            print(f"[{table}] Cleared table. HTTP {resp.status}")
    except urllib.error.HTTPError as e:
        print(f"[{table}] Clear note (HTTP {e.code}): {e.read().decode('utf-8')}")
    except Exception as e:
        print(f"[{table}] Clear error: {e}")

def postgrest_insert(table: str, rows: list):
    """Insert batch of rows into a PostgREST table."""
    if not rows:
        return
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    
    # Ensure all objects in the batch have matching keys
    all_keys = set()
    for r in rows:
        all_keys.update(r.keys())
    
    normalized = []
    for r in rows:
        norm = {k: r.get(k, None) for k in all_keys}
        normalized.append(norm)

    data = json.dumps(normalized).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            print(f"[{table}] Successfully inserted {len(rows)} records! HTTP {resp.status}")
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8")
        print(f"[{table}] HTTP Error {e.code}: {err}")
        raise e
    except Exception as e:
        print(f"[{table}] Insert error: {e}")
        raise e

def main():
    print("==================================================")
    print("Starting Clean Production Reseed of Supabase Cloud")
    print("==================================================")

    now = datetime.now()
    now_iso = now.isoformat()
    today_str = date.today().isoformat()

    # Step 1: Clean out existing data in reverse foreign-key order
    tables_to_clear = [
        "pharmacy_dispense_items",
        "pharmacy_dispenses",
        "prescription_items",
        "prescriptions",
        "lab_results",
        "lab_orders",
        "clinical_amendments",
        "clinical_records",
        "vital_signs",
        "bill_items",
        "payment_transactions",
        "bills",
        "medical_documents",
        "opd_visits",
        "doctors",
        "patients",
        "users",
        "departments",
        "roles",
        "medicine_inventory"
    ]

    print("\n--- Purging Old Seed & Test Records ---")
    for t in tables_to_clear:
        postgrest_delete(t)

    # -------------------------------------------------------------------------
    # 1. ROLES (8 System Roles)
    # -------------------------------------------------------------------------
    roles = [
        {"id": "role_admin", "name": "admin", "description": "Full Hospital System Administrator", "created_at": now_iso, "updated_at": now_iso},
        {"id": "role_doctor", "name": "doctor", "description": "Consultant Physician / Specialist", "created_at": now_iso, "updated_at": now_iso},
        {"id": "role_receptionist", "name": "receptionist", "description": "Front Desk Registration & Token Issuer", "created_at": now_iso, "updated_at": now_iso},
        {"id": "role_pharmacist", "name": "pharmacist", "description": "Pharmacy Order Dispenser & Formulary Manager", "created_at": now_iso, "updated_at": now_iso},
        {"id": "role_lab_tech", "name": "lab_tech", "description": "Laboratory Diagnostics & Pathology Technician", "created_at": now_iso, "updated_at": now_iso},
        {"id": "role_billing", "name": "billing", "description": "Billing Counter Cashier & Fee Collector", "created_at": now_iso, "updated_at": now_iso},
        {"id": "role_nurse", "name": "nurse", "description": "Triage & Vitals Assessment Nurse", "created_at": now_iso, "updated_at": now_iso},
        {"id": "role_patient", "name": "patient", "description": "Registered Patient Token & Records Access", "created_at": now_iso, "updated_at": now_iso},
    ]
    postgrest_insert("roles", roles)

    # -------------------------------------------------------------------------
    # 2. DEPARTMENTS (6 Hospital Departments)
    # -------------------------------------------------------------------------
    departments = [
        {"id": "dept_med", "name": "General Medicine", "code": "MED", "description": "Adult Internal Medicine, Hypertension, Diabetes, and Infectious Diseases", "is_active": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "dept_ped", "name": "Pediatrics", "code": "PED", "description": "Neonatal, Child Health, Immunization & Pediatric Care", "is_active": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "dept_ortho", "name": "Orthopedics", "code": "ORTH", "description": "Bone, Joint, Spine, Fracture Trauma & Sports Injury", "is_active": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "dept_cardio", "name": "Cardiology", "code": "CARD", "description": "Cardiac Diagnostics, Heart Disease, ECG & Preventive Cardiology", "is_active": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "dept_ent", "name": "ENT (Otorhinolaryngology)", "code": "ENT", "description": "Ear, Nose, Throat, Sinus, Voice & Hearing Disorders", "is_active": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "dept_dent", "name": "Dental & Maxillofacial Surgery", "code": "DENT", "description": "Oral Health, Orthodontics, Endodontics & Maxillofacial Care", "is_active": True, "created_at": now_iso, "updated_at": now_iso},
    ]
    postgrest_insert("departments", departments)

    # -------------------------------------------------------------------------
    # 3. USERS (33 Hospital Staff Accounts)
    # -------------------------------------------------------------------------
    hashed_pwd = "pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f" # Default password for staff
    users = [
        # Admin
        {"id": "usr_admin", "email": "admin@smvmch.ac.in", "phone": "9876543200", "full_name": "Hospital Administrator", "hashed_password": hashed_pwd, "role_id": "role_admin", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},

        # 3 Doctors for General Medicine
        {"id": "usr_doc_med_1", "email": "dr.sarah.chen@smvmch.ac.in", "phone": "9876543101", "full_name": "Dr. Sarah Chen, MD", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_doc_med_2", "email": "dr.rajesh.sundaram@smvmch.ac.in", "phone": "9876543102", "full_name": "Dr. Rajesh Sundaram, MBBS, MD", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_doc_med_3", "email": "dr.ananya.sharma@smvmch.ac.in", "phone": "9876543103", "full_name": "Dr. Ananya Sharma, MD, DNB", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},

        # 3 Doctors for Pediatrics
        {"id": "usr_doc_ped_1", "email": "dr.priya.balakrishnan@smvmch.ac.in", "phone": "9876543104", "full_name": "Dr. Priya Balakrishnan, MD (Peds)", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_doc_ped_2", "email": "dr.vikram.rao@smvmch.ac.in", "phone": "9876543105", "full_name": "Dr. Vikramaditya Rao, DCH, DNB", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_doc_ped_3", "email": "dr.meera.nambiar@smvmch.ac.in", "phone": "9876543106", "full_name": "Dr. Meera Nambiar, MBBS, MD", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},

        # 3 Doctors for Orthopedics
        {"id": "usr_doc_ortho_1", "email": "dr.karthik.subramaniam@smvmch.ac.in", "phone": "9876543107", "full_name": "Dr. Karthik Subramaniam, MS (Ortho)", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_doc_ortho_2", "email": "dr.david.miller@smvmch.ac.in", "phone": "9876543108", "full_name": "Dr. David Miller, MD, FRCS", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_doc_ortho_3", "email": "dr.sanjay.verma@smvmch.ac.in", "phone": "9876543109", "full_name": "Dr. Sanjay Verma, MS (Ortho)", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},

        # 3 Doctors for Cardiology
        {"id": "usr_doc_cardio_1", "email": "dr.arvind.swamy@smvmch.ac.in", "phone": "9876543110", "full_name": "Dr. Arvind Swamy, MD, DM (Cardio)", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_doc_cardio_2", "email": "dr.preethi.venkat@smvmch.ac.in", "phone": "9876543111", "full_name": "Dr. Preethi Venkat, MBBS, DNB (Cardio)", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_doc_cardio_3", "email": "dr.ramesh.chandran@smvmch.ac.in", "phone": "9876543112", "full_name": "Dr. Ramesh Chandran, MD, DM, FACC", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},

        # 3 Doctors for ENT
        {"id": "usr_doc_ent_1", "email": "dr.pooja.deshmukh@smvmch.ac.in", "phone": "9876543113", "full_name": "Dr. Pooja Deshmukh, MS (ENT)", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_doc_ent_2", "email": "dr.harish.kumar@smvmch.ac.in", "phone": "9876543114", "full_name": "Dr. Harish Kumar, MBBS, DLO", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_doc_ent_3", "email": "dr.gautham.menon@smvmch.ac.in", "phone": "9876543115", "full_name": "Dr. Gautham Menon, MS (ENT)", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},

        # 3 Doctors for Dental
        {"id": "usr_doc_dent_1", "email": "dr.arunraj@smvmch.ac.in", "phone": "9876543116", "full_name": "Dr. M. Arunraj, MDS (Oral Surg)", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_doc_dent_2", "email": "dr.swathi.reddy@smvmch.ac.in", "phone": "9876543117", "full_name": "Dr. Swathi Reddy, BDS, MDS (Ortho)", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_doc_dent_3", "email": "dr.kevin.thomas@smvmch.ac.in", "phone": "9876543118", "full_name": "Dr. Kevin Thomas, MDS (Periodontics)", "hashed_password": hashed_pwd, "role_id": "role_doctor", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},

        # 2 Receptionists
        {"id": "usr_rec_1", "email": "receptionist1@smvmch.ac.in", "phone": "9876543210", "full_name": "Alice Adams (Reception 1)", "hashed_password": hashed_pwd, "role_id": "role_receptionist", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_rec_2", "email": "receptionist2@smvmch.ac.in", "phone": "9876543211", "full_name": "Kavitha Raman (Reception 2)", "hashed_password": hashed_pwd, "role_id": "role_receptionist", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},

        # 5 Pharmacists
        {"id": "usr_pharm_1", "email": "pharmacist1@smvmch.ac.in", "phone": "9876543221", "full_name": "Elena Rostova (Lead Pharmacist)", "hashed_password": hashed_pwd, "role_id": "role_pharmacist", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_pharm_2", "email": "pharmacist2@smvmch.ac.in", "phone": "9876543222", "full_name": "Rahul Sharma (Pharmacist Desk 2)", "hashed_password": hashed_pwd, "role_id": "role_pharmacist", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_pharm_3", "email": "pharmacist3@smvmch.ac.in", "phone": "9876543223", "full_name": "Deepa Krishnan (Pharmacist Desk 3)", "hashed_password": hashed_pwd, "role_id": "role_pharmacist", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_pharm_4", "email": "pharmacist4@smvmch.ac.in", "phone": "9876543224", "full_name": "Manoj Kumar (Dispensing Pharmacist)", "hashed_password": hashed_pwd, "role_id": "role_pharmacist", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_pharm_5", "email": "pharmacist5@smvmch.ac.in", "phone": "9876543225", "full_name": "Sneha Patel (Inventory Pharmacist)", "hashed_password": hashed_pwd, "role_id": "role_pharmacist", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},

        # 3 Laboratory Technicians
        {"id": "usr_lab_1", "email": "lab1@smvmch.ac.in", "phone": "9876543231", "full_name": "Marcus Vance (Senior Lab Tech)", "hashed_password": hashed_pwd, "role_id": "role_lab_tech", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_lab_2", "email": "lab2@smvmch.ac.in", "phone": "9876543232", "full_name": "Divya Prakash (Biochemist)", "hashed_password": hashed_pwd, "role_id": "role_lab_tech", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_lab_3", "email": "lab3@smvmch.ac.in", "phone": "9876543233", "full_name": "Sandeep Varma (Hematologist Tech)", "hashed_password": hashed_pwd, "role_id": "role_lab_tech", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},

        # 4 Billing Counter Staff
        {"id": "usr_bill_1", "email": "billing1@smvmch.ac.in", "phone": "9876543241", "full_name": "Rajesh Kumar (Counter 1)", "hashed_password": hashed_pwd, "role_id": "role_billing", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_bill_2", "email": "billing2@smvmch.ac.in", "phone": "9876543242", "full_name": "Suresh Babu (Counter 2)", "hashed_password": hashed_pwd, "role_id": "role_billing", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_bill_3", "email": "billing3@smvmch.ac.in", "phone": "9876543243", "full_name": "Lakshmi Narayanan (Counter 3)", "hashed_password": hashed_pwd, "role_id": "role_billing", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
        {"id": "usr_bill_4", "email": "billing4@smvmch.ac.in", "phone": "9876543244", "full_name": "Anitha Murugan (Counter 4)", "hashed_password": hashed_pwd, "role_id": "role_billing", "is_active": True, "is_verified": True, "failed_login_attempts": 0, "created_at": now_iso, "updated_at": now_iso},
    ]
    postgrest_insert("users", users)

    # -------------------------------------------------------------------------
    # 4. DOCTORS (18 Doctors: 3 per department)
    # -------------------------------------------------------------------------
    doctors = [
        # General Medicine (MED)
        {"id": "doc_med_1", "user_id": "usr_doc_med_1", "department_id": "dept_med", "qualification": "MBBS, MD (General Medicine)", "specialization": "Internal Medicine & Diabetology", "registration_number": "MCI-TN-48901", "room_number": "OPD Room 101, Ground Floor", "consultation_fee": "500", "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_med_2", "user_id": "usr_doc_med_2", "department_id": "dept_med", "qualification": "MBBS, MD (Internal Medicine)", "specialization": "Geriatrics & Hypertension", "registration_number": "MCI-TN-51204", "room_number": "OPD Room 102, Ground Floor", "consultation_fee": "500", "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_med_3", "user_id": "usr_doc_med_3", "department_id": "dept_med", "qualification": "MD, DNB (General Medicine)", "specialization": "Infectious Diseases & Critical Care", "registration_number": "MCI-TN-54329", "room_number": "OPD Room 103, Ground Floor", "consultation_fee": "500", "is_available": True, "created_at": now_iso, "updated_at": now_iso},

        # Pediatrics (PED)
        {"id": "doc_ped_1", "user_id": "usr_doc_ped_1", "department_id": "dept_ped", "qualification": "MBBS, MD (Pediatrics)", "specialization": "Pediatric Pulmonology & Allergy", "registration_number": "MCI-TN-61002", "room_number": "OPD Room 201, 1st Floor", "consultation_fee": "600", "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_ped_2", "user_id": "usr_doc_ped_2", "department_id": "dept_ped", "qualification": "DCH, DNB (Pediatrics)", "specialization": "Neonatology & Growth Assessment", "registration_number": "MCI-TN-62187", "room_number": "OPD Room 202, 1st Floor", "consultation_fee": "600", "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_ped_3", "user_id": "usr_doc_ped_3", "department_id": "dept_ped", "qualification": "MBBS, MD (Pediatrics)", "specialization": "Child Nutrition & Immunization", "registration_number": "MCI-TN-63401", "room_number": "OPD Room 203, 1st Floor", "consultation_fee": "600", "is_available": True, "created_at": now_iso, "updated_at": now_iso},

        # Orthopedics (ORTH)
        {"id": "doc_ortho_1", "user_id": "usr_doc_ortho_1", "department_id": "dept_ortho", "qualification": "MS (Orthopedics)", "specialization": "Spine & Joint Replacement", "registration_number": "MCI-TN-71890", "room_number": "OPD Room 301, 2nd Floor", "consultation_fee": "700", "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_ortho_2", "user_id": "usr_doc_ortho_2", "department_id": "dept_ortho", "qualification": "MD, FRCS (Ortho)", "specialization": "Sports Medicine & Arthroscopy", "registration_number": "MCI-TN-72543", "room_number": "OPD Room 302, 2nd Floor", "consultation_fee": "750", "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_ortho_3", "user_id": "usr_doc_ortho_3", "department_id": "dept_ortho", "qualification": "MS (Ortho), DNB", "specialization": "Trauma & Fracture Reconstruction", "registration_number": "MCI-TN-73912", "room_number": "OPD Room 303, 2nd Floor", "consultation_fee": "700", "is_available": True, "created_at": now_iso, "updated_at": now_iso},

        # Cardiology (CARD)
        {"id": "doc_cardio_1", "user_id": "usr_doc_cardio_1", "department_id": "dept_cardio", "qualification": "MD, DM (Cardiology)", "specialization": "Interventional Cardiology & Angiography", "registration_number": "MCI-TN-81098", "room_number": "OPD Room 401, 3rd Floor", "consultation_fee": "900", "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_cardio_2", "user_id": "usr_doc_cardio_2", "department_id": "dept_cardio", "qualification": "MBBS, DNB (Cardiology)", "specialization": "Non-Invasive Cardiology & Echocardiography", "registration_number": "MCI-TN-82341", "room_number": "OPD Room 402, 3rd Floor", "consultation_fee": "850", "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_cardio_3", "user_id": "usr_doc_cardio_3", "department_id": "dept_cardio", "qualification": "MD, DM, FACC", "specialization": "Heart Failure & Preventive Cardiology", "registration_number": "MCI-TN-83567", "room_number": "OPD Room 403, 3rd Floor", "consultation_fee": "1000", "is_available": True, "created_at": now_iso, "updated_at": now_iso},

        # ENT (ENT)
        {"id": "doc_ent_1", "user_id": "usr_doc_ent_1", "department_id": "dept_ent", "qualification": "MS (ENT)", "specialization": "Endoscopic Sinus Surgery & Rhinology", "registration_number": "MCI-TN-91045", "room_number": "OPD Room 501, 4th Floor", "consultation_fee": "550", "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_ent_2", "user_id": "usr_doc_ent_2", "department_id": "dept_ent", "qualification": "MBBS, DLO, DNB (ENT)", "specialization": "Otology & Audiology", "registration_number": "MCI-TN-92189", "room_number": "OPD Room 502, 4th Floor", "consultation_fee": "550", "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_ent_3", "user_id": "usr_doc_ent_3", "department_id": "dept_ent", "qualification": "MS (ENT)", "specialization": "Laryngology & Voice Disorders", "registration_number": "MCI-TN-93450", "room_number": "OPD Room 503, 4th Floor", "consultation_fee": "600", "is_available": True, "created_at": now_iso, "updated_at": now_iso},

        # Dental (DENT)
        {"id": "doc_dent_1", "user_id": "usr_doc_dent_1", "department_id": "dept_dent", "qualification": "BDS, MDS (Oral & Maxillofacial)", "specialization": "Oral Surgery & Dental Implants", "registration_number": "DCI-TN-31092", "room_number": "Dental Clinic 208, Block B", "consultation_fee": "600", "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_dent_2", "user_id": "usr_doc_dent_2", "department_id": "dept_dent", "qualification": "BDS, MDS (Orthodontics)", "specialization": "Dentofacial Orthopedics & Braces", "registration_number": "DCI-TN-32145", "room_number": "Dental Clinic 209, Block B", "consultation_fee": "600", "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_dent_3", "user_id": "usr_doc_dent_3", "department_id": "dept_dent", "qualification": "MDS (Periodontics)", "specialization": "Gum Diseases & Aesthetic Dentistry", "registration_number": "DCI-TN-33410", "room_number": "Dental Clinic 210, Block B", "consultation_fee": "600", "is_available": True, "created_at": now_iso, "updated_at": now_iso},
    ]
    postgrest_insert("doctors", doctors)

    # -------------------------------------------------------------------------
    # 5. PATIENTS (20 Patients with distinct health conditions)
    # -------------------------------------------------------------------------
    patient_data_specs = [
        ("pat_001", "UHID-2026-00001", "REG-2026-00001", "Lakshmi Srujana Majeti", "Majeti Satyanarayana", "Daughter", 30, "FEMALE", "8374477999", "O+", "Flat 402, Sri Krishna Heights", "Vijayawada", "Andhra Pradesh", "520010", "Type 2 Diabetes Mellitus with Peripheral Neuropathy"),
        ("pat_002", "UHID-2026-00002", "REG-2026-00002", "uday", "satya", "Son", 25, "MALE", "9876543201", "O+", "Door No 14/2, Anna Nagar", "Puducherry", "Puducherry", "605001", "Acute Lumbar Muscle Sprain & Sciatica"),
        ("pat_003", "UHID-2026-00003", "REG-2026-00003", "K. Venkatasubramanian", "Krishnan Iyer", "Son", 62, "MALE", "9443218765", "B+", "72, East Car Street, Chidambaram", "Cuddalore", "Tamil Nadu", "608001", "Essential Hypertension & CAD (Post-PTCA Follow-up)"),
        ("pat_004", "UHID-2026-00004", "REG-2026-00004", "Sowmya Radhakrishnan", "Radhakrishnan Nair", "Wife", 28, "FEMALE", "9840123456", "A+", "Plot 18, Lake View Enclave", "Chennai", "Tamil Nadu", "600042", "Antenatal Care 26 Weeks Gestation with Mild Anemia"),
        ("pat_005", "UHID-2026-00005", "REG-2026-00005", "Master Aarav Vignesh", "Vigneshwaran M", "Son", 6, "MALE", "9884567890", "O+", "22, Gandhi Road", "Villupuram", "Tamil Nadu", "605602", "Pediatric Bronchial Asthma with Acute Wheezing"),
        ("pat_006", "UHID-2026-00006", "REG-2026-00006", "Meenakshi Sundaram", "Sundaramurthy Pillai", "Wife", 58, "FEMALE", "9444123890", "AB+", "45/A, North Mada Street, Mylapore", "Chennai", "Tamil Nadu", "600004", "Bilateral Knee Osteoarthritis Grade III"),
        ("pat_007", "UHID-2026-00007", "REG-2026-00007", "R. Karthikeyan", "Ramasamy Gounder", "Son", 34, "MALE", "9789012345", "B+", "12, Bharathi Street", "Tindivanam", "Tamil Nadu", "604001", "Acute Febrile Illness - Suspected Dengue Fever"),
        ("pat_008", "UHID-2026-00008", "REG-2026-00008", "Baby Ananya Sri", "Senthil Kumar", "Daughter", 3, "FEMALE", "9940123789", "A+", "5/8, Church Street", "Puducherry", "Puducherry", "605003", "Acute Otitis Media & Upper Respiratory Infection"),
        ("pat_009", "UHID-2026-00009", "REG-2026-00009", "Farooq Ahmed", "Abdul Razack", "Son", 47, "MALE", "9841234567", "O-", "89, Mosque Street, Gorimedu", "Puducherry", "Puducherry", "605006", "Chronic Obstructive Pulmonary Disease (COPD) Grade II"),
        ("pat_010", "UHID-2026-00010", "REG-2026-00010", "Geetha Govindaraj", "Govindarajan K", "Wife", 42, "FEMALE", "9710234567", "B-", "34, South Street, Cuddalore Old Town", "Cuddalore", "Tamil Nadu", "607003", "Hypothyroidism with Dyslipidemia & Weight Gain"),
        ("pat_011", "UHID-2026-00011", "REG-2026-00011", "Pradeep Chandran", "Chandrasekaran V", "Son", 38, "MALE", "9884012345", "A-", "101, Beach Road", "Karaikal", "Puducherry", "609602", "Acute Left Ureteric Calculus with Severe Renal Colic"),
        ("pat_012", "UHID-2026-00012", "REG-2026-00012", "Rukmani Ammal", "Late Rangasamy", "Wife", 71, "FEMALE", "9444567812", "O+", "67, Perumal Koil Street", "Madurantakam", "Tamil Nadu", "603306", "Chronic Kidney Disease Stage 3b & Diabetic Nephropathy"),
        ("pat_013", "UHID-2026-00013", "REG-2026-00013", "Vasanth Kumar", "Kumaravel S", "Son", 22, "MALE", "9600123456", "AB-", "College Road, Lawspet", "Puducherry", "Puducherry", "605008", "Right Ankle Inversion Injury / Lateral Ligament Sprain"),
        ("pat_014", "UHID-2026-00014", "REG-2026-00014", "Nithya Kalyani", "Muthukrishnan T", "Daughter", 31, "FEMALE", "9840567812", "A+", "42, Kamaraj Salai", "Puducherry", "Puducherry", "605009", "Chronic Migraine with Visual Aura & Photophobia"),
        ("pat_015", "UHID-2026-00015", "REG-2026-00015", "Balaji Narayanan", "Narayanasamy R", "Son", 49, "MALE", "9790123456", "B+", "15, Cross Street, Saram", "Puducherry", "Puducherry", "605013", "Gastroesophageal Reflux Disease (GERD) & Erosive Gastritis"),
        ("pat_016", "UHID-2026-00016", "REG-2026-00016", "Shalini Mohan", "Mohanraj P", "Daughter", 26, "FEMALE", "9962123456", "O+", "88, Main Road, Neyveli", "Cuddalore", "Tamil Nadu", "607803", "Severe Iron Deficiency Anemia (Hb 7.8 g/dL)"),
        ("pat_017", "UHID-2026-00017", "REG-2026-00017", "C. Dhandapani", "Chinnasamy G", "Son", 55, "MALE", "9443567890", "A+", "33, Bazaar Street", "Panruti", "Tamil Nadu", "607106", "Severe Acute Pulpitis & Mandibular 1st Molar Abscess"),
        ("pat_018", "UHID-2026-00018", "REG-2026-00018", "Fatima Beevi", "Late Syed Ibrahim", "Wife", 65, "FEMALE", "9841987654", "B+", "19, New Street, Heritage Town", "Puducherry", "Puducherry", "605001", "Chronic Allergic Contact Dermatitis & Numular Eczema"),
        ("pat_019", "UHID-2026-00019", "REG-2026-00019", "G. Senthil Nathan", "Ganesan P", "Son", 41, "MALE", "9789567890", "O+", "51, Extension Colony", "Kanchipuram", "Tamil Nadu", "631502", "Allergic Rhinitis with Chronic Maxillary Sinusitis"),
        ("pat_020", "UHID-2026-00020", "REG-2026-00020", "Dr. Chintha Ravi Prasanth", "Late C. Subba Rao", "Son", 35, "MALE", "8555027225", "B+", "Flat 204, Executive Enclave", "Hyderabad", "Telangana", "500081", "Executive Annual Health Evaluation & Routine Screen"),
    ]

    patients = []
    for (pid, uhid, reg, name, parent, rel, age, gender, phone, blood, addr, city, state, pin, cond) in patient_data_specs:
        patients.append({
            "id": pid,
            "uhid": uhid,
            "hospital_reg_num": reg,
            "abha_number": f"{phone[:4]}-{phone[4:8]}-{phone[8:]}-99",
            "full_name": name,
            "parent_spouse_name": parent,
            "parent_spouse_relation": rel,
            "date_of_birth": (date.today() - timedelta(days=age*365)).isoformat(),
            "age_years": age,
            "age_months": 0,
            "gender": gender,
            "phone": phone,
            "email": f"{name.lower().replace(' ', '.').replace('/', '').replace('&', '')}@opdpatient.in",
            "address": addr,
            "city": city,
            "state": state,
            "postal_code": pin,
            "blood_group": blood,
            "registration_date": now_iso,
            "barcode_value": f"BAR-{uhid}",
            "qr_code_data": f"SMVMCH|{uhid}|{reg}|{name}|{blood}",
            "registered_by_staff_id": "usr_rec_1",
            "registered_by_staff_name": "Alice Adams (Reception 1)",
            "registered_by_staff_role": "receptionist",
            "guardian_id": None,
            "created_at": now_iso,
            "updated_at": now_iso,
        })
    postgrest_insert("patients", patients)

    # -------------------------------------------------------------------------
    # 6. OPD VISITS (20 Live OPD Visits)
    # -------------------------------------------------------------------------
    # Map patients to department and doctor
    dept_doc_routing = [
        ("dept_med", "doc_med_1", "NORMAL", "IN_CONSULTATION"),     # Pat 1: Diabetes (Chen)
        ("dept_ortho", "doc_ortho_1", "NORMAL", "WAITING"),         # Pat 2: Lumbar Sprain (Subramaniam)
        ("dept_cardio", "doc_cardio_1", "PRIORITY", "IN_CONSULTATION"), # Pat 3: CAD (Swamy)
        ("dept_med", "doc_med_2", "NORMAL", "WAITING"),             # Pat 4: Antenatal (Sundaram)
        ("dept_ped", "doc_ped_1", "EMERGENCY", "TRIAGED"),          # Pat 5: Child Asthma (Balakrishnan)
        ("dept_ortho", "doc_ortho_2", "NORMAL", "WAITING"),         # Pat 6: Knee Osteoarthritis (Miller)
        ("dept_med", "doc_med_3", "EMERGENCY", "TRIAGED"),          # Pat 7: Dengue (Sharma)
        ("dept_ped", "doc_ped_2", "PRIORITY", "WAITING"),           # Pat 8: Otitis Media (Rao)
        ("dept_med", "doc_med_1", "PRIORITY", "IN_CONSULTATION"),    # Pat 9: COPD (Chen)
        ("dept_med", "doc_med_2", "NORMAL", "COMPLETED"),           # Pat 10: Hypothyroidism (Sundaram)
        ("dept_med", "doc_med_3", "EMERGENCY", "TRIAGED"),          # Pat 11: Renal Colic (Sharma)
        ("dept_med", "doc_med_1", "PRIORITY", "WAITING"),           # Pat 12: CKD (Chen)
        ("dept_ortho", "doc_ortho_3", "PRIORITY", "WAITING"),        # Pat 13: Ankle Injury (Verma)
        ("dept_med", "doc_med_2", "NORMAL", "WAITING"),             # Pat 14: Migraine (Sundaram)
        ("dept_med", "doc_med_3", "NORMAL", "COMPLETED"),           # Pat 15: GERD (Sharma)
        ("dept_med", "doc_med_1", "PRIORITY", "WAITING"),           # Pat 16: Severe Anemia (Chen)
        ("dept_dent", "doc_dent_1", "PRIORITY", "IN_CONSULTATION"),  # Pat 17: Pulpitis (Arunraj)
        ("dept_med", "doc_med_2", "NORMAL", "COMPLETED"),           # Pat 18: Dermatitis (Sundaram)
        ("dept_ent", "doc_ent_1", "NORMAL", "WAITING"),             # Pat 19: Sinusitis (Deshmukh)
        ("dept_med", "doc_med_3", "NORMAL", "COMPLETED"),           # Pat 20: Executive Checkup (Sharma)
    ]

    visits = []
    vitals = []
    clinical_records = []
    prescriptions = []
    prescription_items = []
    lab_orders = []
    lab_results = []
    bills = []

    for i, p in enumerate(patients):
        pid = p["id"]
        v_num = f"VIS-20261015-{(i+1):04d}"
        token = i + 1
        d_id, doc_id, triage, status = dept_doc_routing[i]
        cond = patient_data_specs[i][14]
        v_id = f"vis_{pid}"

        # 6.1 OPD Visit
        visits.append({
            "id": v_id,
            "visit_number": v_num,
            "patient_id": pid,
            "doctor_id": doc_id,
            "department_id": d_id,
            "visit_date": now_iso,
            "queue_token": token,
            "triage_priority": triage,
            "status": status,
            "consultation_fee": 500.0 if "med" in d_id or "ent" in d_id else (600.0 if "ped" in d_id or "dent" in d_id else 750.0),
            "payment_status": "PAID" if status == "COMPLETED" else "PAID",
            "notes": f"Chief Clinical Diagnosis: {cond}",
            "created_at": now_iso,
            "updated_at": now_iso,
        })

        # 6.2 Vital Signs
        sys_bp = 120 + (i * 2) % 40
        dia_bp = 78 + (i * 1) % 20
        pulse = 74 + (i * 3) % 25
        temp = 98.4 if triage != "EMERGENCY" else 101.8
        spo2 = 98.0 if "COPD" not in cond and "Asthma" not in cond else 94.0
        vitals.append({
            "id": f"vit_{v_id}",
            "visit_id": v_id,
            "systolic_bp": sys_bp,
            "diastolic_bp": dia_bp,
            "pulse_rate": pulse,
            "temperature_f": float(temp),
            "spo2_percent": float(spo2),
            "respiratory_rate": 18,
            "height_cm": 165.0,
            "weight_kg": 64.0,
            "bmi": 23.5,
            "recorded_by_user_id": "usr_rec_1",
            "recorded_at": now_iso,
            "notes": f"Triage assessment for {cond}",
            "created_at": now_iso,
            "updated_at": now_iso,
        })

        # 6.3 Clinical Records
        clinical_records.append({
            "id": f"cr_{v_id}",
            "visit_id": v_id,
            "patient_id": pid,
            "doctor_id": doc_id,
            "presenting_complaint": f"Presents with symptoms of {cond}",
            "history_of_present_illness": f"Patient reports onset of symptoms since 1-2 weeks. Aggravated on exertion. {cond}",
            "general_examination": f"Vitals: BP {sys_bp}/{dia_bp}, Pulse {pulse} bpm, SpO2 {spo2}%.",
            "provisional_diagnosis": cond,
            "final_diagnosis": cond,
            "icd10_code": "E11.9" if "Diabetes" in cond else ("M54.5" if "Sprain" in cond else ("I25.1" if "CAD" in cond else "R69")),
            "care_plan": f"Initiate medical management for {cond}. Review in OPD in 14 days with investigation results.",
            "follow_up_date": (date.today() + timedelta(days=14)).isoformat(),
            "status": "COMPLETED",
            "version": 1,
            "created_by_user_id": doc_id.replace("doc_", "usr_doc_"),
            "created_at": now_iso,
            "updated_at": now_iso,
        })

        # 6.4 Prescriptions
        rx_id = f"rx_{v_id}"
        prescriptions.append({
            "id": rx_id,
            "visit_id": v_id,
            "patient_id": pid,
            "doctor_id": doc_id,
            "status": "COMPLETED" if status == "COMPLETED" else "ACTIVE",
            "version": 1,
            "notes": "Take medications strictly after food. Drink plenty of water.",
            "is_ocr_extracted": False,
            "is_verified_by_clinician": True,
            "allergy_warning_acknowledged": True,
            "created_at": now_iso,
            "updated_at": now_iso,
        })

        # 6.5 Prescription Items
        med_name1 = "Paracetamol 650mg" if "Dengue" in cond or "Fever" in cond else "Metformin 500mg"
        prescription_items.append({
            "id": f"rxi_{v_id}_1",
            "prescription_id": rx_id,
            "medicine_name": med_name1,
            "form": "Tablet",
            "dosage": "650mg" if "Paracetamol" in med_name1 else "500mg",
            "route": "ORAL",
            "frequency": "TID" if "Fever" in cond else "BD",
            "duration_days": 5 if "Acute" in cond else 30,
            "timing": "AFTER_FOOD",
            "instructions": "Take after meals with warm water",
            "is_dispensed": status == "COMPLETED",
            "created_at": now_iso,
            "updated_at": now_iso,
        })
        prescription_items.append({
            "id": f"rxi_{v_id}_2",
            "prescription_id": rx_id,
            "medicine_name": "Pantoprazole 40mg",
            "form": "Tablet",
            "dosage": "40mg",
            "route": "ORAL",
            "frequency": "OD",
            "duration_days": 14,
            "timing": "BEFORE_FOOD",
            "instructions": "Take morning empty stomach 30 mins before breakfast",
            "is_dispensed": status == "COMPLETED",
            "created_at": now_iso,
            "updated_at": now_iso,
        })

        # 6.6 Lab Orders (for first 10 patients)
        if i < 10:
            lo_id = f"lo_{v_id}"
            test_name = "Complete Blood Count (CBC)" if i % 2 == 0 else "HbA1c & Fasting Lipid Profile"
            category = "HEMATOLOGY" if "CBC" in test_name else "BIOCHEMISTRY"
            lab_orders.append({
                "id": lo_id,
                "order_number": f"LAB-20261015-{(i+1):03d}",
                "visit_id": v_id,
                "patient_id": pid,
                "ordered_by_doctor_id": doc_id,
                "test_name": test_name,
                "test_category": category,
                "status": "COMPLETED" if i < 5 else "ORDERED",
                "clinical_indication": f"Diagnostic evaluation for {cond}",
                "specimen_status": "COLLECTED",
                "is_sensitive": False,
                "requires_review": False,
                "published_to_visit": True,
                "ordered_at": now_iso,
                "created_at": now_iso,
                "updated_at": now_iso,
            })
            if i < 5:
                lab_results.append({
                    "id": f"lr_{lo_id}",
                    "lab_order_id": lo_id,
                    "parameter_name": "Hemoglobin (Hb)" if "CBC" in test_name else "Glycated Hemoglobin (HbA1c)",
                    "result_value": "12.8" if "CBC" in test_name else "7.4",
                    "unit": "g/dL" if "CBC" in test_name else "%",
                    "reference_range": "11.5 - 16.0 g/dL" if "CBC" in test_name else "< 5.7% Normal",
                    "is_abnormal": "HbA1c" in test_name,
                    "is_critical": False,
                    "flag": "HIGH" if "HbA1c" in test_name else "NORMAL",
                    "notes": "Verified by Clinical Pathology Lab",
                    "reported_at": now_iso,
                    "verified_by_user_id": "usr_lab_1",
                    "verified_at": now_iso,
                    "created_at": now_iso,
                    "updated_at": now_iso,
                })

        # 6.7 Billing
        bill_fee = 500.0 if "med" in d_id or "ent" in d_id else (600.0 if "ped" in d_id or "dent" in d_id else 750.0)
        bills.append({
            "id": f"bill_{v_id}",
            "visit_id": v_id,
            "patient_id": pid,
            "invoice_number": f"INV-20261015-{(i+1):04d}",
            "subtotal": bill_fee,
            "discount_type": "NONE",
            "discount_rate": 0.0,
            "discount_amount": 0.0,
            "taxable_amount": bill_fee,
            "cgst_amount": 0.0,
            "sgst_amount": 0.0,
            "igst_amount": 0.0,
            "total_tax_amount": 0.0,
            "total_amount": bill_fee,
            "net_amount": bill_fee,
            "paid_amount": bill_fee,
            "outstanding_balance": 0.0,
            "status": "PAID",
            "payment_status": "PAID",
            "payment_method": "CASH",
            "billed_by_user_id": "usr_bill_1",
            "billed_at": now_iso,
            "is_synthetic_pricing": False,
            "created_at": now_iso,
            "updated_at": now_iso,
        })

    postgrest_insert("opd_visits", visits)
    postgrest_insert("vital_signs", vitals)
    postgrest_insert("clinical_records", clinical_records)
    postgrest_insert("prescriptions", prescriptions)
    postgrest_insert("prescription_items", prescription_items)
    postgrest_insert("lab_orders", lab_orders)
    postgrest_insert("lab_results", lab_results)
    postgrest_insert("bills", bills)

    # -------------------------------------------------------------------------
    # 7. MEDICINE INVENTORY (28 Formulary Items)
    # -------------------------------------------------------------------------
    formulary_specs = [
        ("MED-001", "Paracetamol 650mg", "Paracetamol", "650mg", "Tablet", "BATCH-2026-A1", 450, 50, 2.50),
        ("MED-002", "Metformin 500mg", "Metformin Hydrochloride", "500mg", "Tablet", "BATCH-2026-A2", 600, 100, 3.20),
        ("MED-003", "Amlodipine 5mg", "Amlodipine Besylate", "5mg", "Tablet", "BATCH-2026-A3", 350, 50, 4.00),
        ("MED-004", "Telmisartan 40mg", "Telmisartan", "40mg", "Tablet", "BATCH-2026-A4", 280, 40, 8.50),
        ("MED-005", "Pantoprazole 40mg", "Pantoprazole Sodium", "40mg", "Tablet", "BATCH-2026-A5", 500, 60, 6.00),
        ("MED-006", "Amoxicillin + Clavulanic Acid 625mg", "Amoxicillin Clavulanate", "625mg", "Tablet", "BATCH-2026-A6", 240, 30, 22.00),
        ("MED-007", "Azithromycin 500mg", "Azithromycin", "500mg", "Tablet", "BATCH-2026-A7", 180, 25, 18.50),
        ("MED-008", "Ceftriaxone 1g Injection", "Ceftriaxone", "1g", "Injection", "BATCH-2026-A8", 120, 20, 65.00),
        ("MED-009", "Atorvastatin 10mg", "Atorvastatin Calcium", "10mg", "Tablet", "BATCH-2026-A9", 400, 50, 7.50),
        ("MED-010", "Salbutamol 100mcg Inhaler", "Salbutamol", "100mcg", "Inhaler", "BATCH-2026-B1", 85, 15, 140.00),
        ("MED-011", "Budesonide 200mcg Inhaler", "Budesonide", "200mcg", "Inhaler", "BATCH-2026-B2", 60, 10, 210.00),
        ("MED-012", "Cetirizine 10mg", "Cetirizine Hydrochloride", "10mg", "Tablet", "BATCH-2026-B3", 520, 50, 2.00),
        ("MED-013", "Montelukast 10mg", "Montelukast Sodium", "10mg", "Tablet", "BATCH-2026-B4", 210, 30, 9.50),
        ("MED-014", "Diclofenac Sodium 50mg", "Diclofenac", "50mg", "Tablet", "BATCH-2026-B5", 380, 40, 3.50),
        ("MED-015", "Tramadol 50mg Capsule", "Tramadol", "50mg", "Capsule", "BATCH-2026-B6", 90, 20, 12.00),
        ("MED-016", "Oral Rehydration Salts (ORS)", "Sodium/Potassium/Glucose", "20.5g", "Sachet", "BATCH-2026-B7", 650, 100, 20.00),
        ("MED-017", "Ondansetron 4mg", "Ondansetron", "4mg", "Tablet", "BATCH-2026-B8", 300, 40, 5.00),
        ("MED-018", "Ferrous Ascorbate + Folic Acid", "Iron + Folate", "100mg", "Tablet", "BATCH-2026-C1", 420, 50, 8.00),
        ("MED-019", "Calcium Carbonate + Vit D3", "Calcium + Cholecalciferol", "500mg", "Tablet", "BATCH-2026-C2", 390, 50, 6.50),
        ("MED-020", "Levothyroxine 50mcg", "Levothyroxine Sodium", "50mcg", "Tablet", "BATCH-2026-C3", 310, 40, 3.00),
        ("MED-021", "Insulin Glargine 100 IU/ml", "Insulin Glargine", "100 IU/ml", "Vial", "BATCH-2026-C4", 45, 10, 480.00),
        ("MED-022", "Ciprofloxacin Eye/Ear Drops", "Ciprofloxacin", "0.3%", "Drops", "BATCH-2026-C5", 140, 20, 35.00),
        ("MED-023", "Clotrimazole 1% Cream", "Clotrimazole", "1%", "Ointment", "BATCH-2026-C6", 110, 15, 45.00),
        ("MED-024", "Betamethasone 0.05% Cream", "Betamethasone", "0.05%", "Ointment", "BATCH-2026-C7", 95, 15, 55.00),
        ("MED-025", "Ranitidine 150mg", "Ranitidine Hydrochloride", "150mg", "Tablet", "BATCH-2026-C8", 200, 30, 2.80),
        ("MED-026", "Glibenclamide 5mg", "Glibenclamide", "5mg", "Tablet", "BATCH-2026-D1", 180, 25, 2.20),
        ("MED-027", "Xylometazoline Nasal Drops", "Xylometazoline", "0.1%", "Drops", "BATCH-2026-D2", 130, 20, 42.00),
        ("MED-028", "Chlorhexidine 0.2% Mouthwash", "Chlorhexidine Gluconate", "0.2%", "Liquid", "BATCH-2026-D3", 160, 25, 75.00),
    ]

    inventory = []
    for (m_code, m_name, g_name, strength, form, batch, qty, reorder, price) in formulary_specs:
        inventory.append({
            "id": f"inv_{m_code.lower().replace('-', '_')}",
            "medicine_code": m_code,
            "name": m_name,
            "generic_name": g_name,
            "strength": strength,
            "dosage_form": form,
            "batch_number": batch,
            "expiry_date": (date.today() + timedelta(days=500)).isoformat(),
            "available_quantity": qty,
            "reorder_level": reorder,
            "unit_price": price,
            "is_synthetic_price": False,
            "tax_classification": "GST_5",
            "tax_rate_percent": 5.0,
            "supplier_name": "SMVMCH Central Medical Stores",
            "supplier_contact": "cms-procurement@smvmch.ac.in",
            "is_active": True,
            "created_at": now_iso,
            "updated_at": now_iso,
        })
    postgrest_insert("medicine_inventory", inventory)

    print("\n==================================================")
    print("SUCCESS: Supabase Cloud Database Fully Seeded!")
    print(f"- 8 Roles")
    print(f"- 6 Departments")
    print(f"- 33 Staff User Logins (1 Admin, 18 Doctors [3 per dept], 2 Receptionists, 5 Pharmacists, 3 Lab Techs, 4 Billing)")
    print(f"- 18 Doctor Clinical Profiles")
    print(f"- 20 Patients with Full Health Conditions & Contact Info")
    print(f"- 20 Active OPD Visits & Queues")
    print(f"- 20 Vital Signs Assessments")
    print(f"- 20 Clinical Diagnoses & Records")
    print(f"- 20 Prescriptions & Item Orders")
    print(f"- 10 Laboratory Orders & Verified Results")
    print(f"- 20 Consultation Bills")
    print(f"- 28 Formulary Inventory Medicines")
    print("==================================================")

if __name__ == "__main__":
    main()
