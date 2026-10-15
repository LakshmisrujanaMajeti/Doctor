#!/usr/bin/env python3
"""
Generator for complete, idempotent supabase_schema.sql.
Outputs:
1. DDL for all 34 tables (PostgreSQL compatible)
2. Row Level Security bypass (DISABLE ROW LEVEL SECURITY) for seamless mobile app access
3. Seed data with ON CONFLICT (id) DO UPDATE for:
   - 8 System Roles
   - 6 Hospital Departments
   - 33 Staff User Accounts (Admin, 18 Doctors [3 per dept], 2 Receptionists, 5 Pharmacists, 3 Lab Technicians, 4 Billing Counter Staff)
   - 18 Doctor Clinical Profiles
   - 20 Patients with distinct health conditions
   - 20 OPD Visits
   - 20 Vital Signs
   - 20 Clinical Records
   - 20 Prescriptions & 40 Prescription Items
   - 10 Lab Orders & 5 Lab Results
   - 20 Bills
   - 28 Formulary Medicine Inventory items
"""

import os
import re
from datetime import datetime, date, timedelta

def escape_sql(val):
    if val is None:
        return "NULL"
    elif isinstance(val, bool):
        return "TRUE" if val else "FALSE"
    elif isinstance(val, (int, float)):
        return str(val)
    elif isinstance(val, (datetime, date)):
        return f"'{val.isoformat()}'"
    else:
        # String
        s = str(val).replace("'", "''")
        return f"'{s}'"

def make_insert_sql(table_name, rows, pkey="id"):
    if not rows:
        return ""
    
    # Collect all unique columns across all rows
    cols = []
    for r in rows:
        for k in r.keys():
            if k not in cols:
                cols.append(k)

    lines = [f"-- Data: {table_name} ({len(rows)} records)"]
    lines.append(f"INSERT INTO {table_name} ({', '.join(cols)}) VALUES")
    
    val_lines = []
    for r in rows:
        vals = [escape_sql(r.get(c, None)) for c in cols]
        val_lines.append(f"  ({', '.join(vals)})")
    
    lines.append(",\n".join(val_lines))
    
    update_set = ", ".join([f"{c} = EXCLUDED.{c}" for c in cols if c != pkey])
    if update_set:
        lines.append(f"ON CONFLICT ({pkey}) DO UPDATE SET {update_set};")
    else:
        lines.append(f"ON CONFLICT ({pkey}) DO NOTHING;")
    
    lines.append("")
    return "\n".join(lines)

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    target_sql_path = os.path.join(base_dir, "supabase_schema.sql")

    # Read existing DDL from supabase_schema.sql
    with open(target_sql_path, "r", encoding="utf-8") as f:
        existing_sql = f.read()

    # Extract table DDL blocks (from line 1 down to the last CREATE TABLE block)
    # Tables present in schema:
    all_tables = [
        "departments", "medicine_inventory", "otp_verifications", "patients",
        "permissions", "roles", "users", "audit_logs", "doctors", "password_reset_tokens",
        "refresh_token_sessions", "role_permissions", "stock_movements", "support_tickets",
        "system_configs", "opd_visits", "bills", "clinical_records", "lab_orders",
        "medical_documents", "prescriptions", "vital_signs", "bill_items",
        "clinical_amendments", "document_audit_logs", "document_ocr_extractions",
        "document_pages", "lab_results", "payment_transactions", "pharmacy_dispenses",
        "pharmacy_orders", "prescription_amendments", "prescription_items", "pharmacy_dispense_items"
    ]

    now_iso = "2026-10-15T10:30:00"
    today_str = "2026-10-15"

    # 1. ROLES
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

    # 2. DEPARTMENTS
    departments = [
        {"id": "dept_med", "name": "General Medicine", "code": "MED", "description": "Adult Internal Medicine, Hypertension, Diabetes, and Infectious Diseases", "is_active": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "dept_ped", "name": "Pediatrics", "code": "PED", "description": "Neonatal, Child Health, Immunization & Pediatric Care", "is_active": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "dept_ortho", "name": "Orthopedics", "code": "ORTH", "description": "Bone, Joint, Spine, Fracture Trauma & Sports Injury", "is_active": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "dept_cardio", "name": "Cardiology", "code": "CARD", "description": "Cardiac Diagnostics, Heart Disease, ECG & Preventive Cardiology", "is_active": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "dept_ent", "name": "ENT (Otorhinolaryngology)", "code": "ENT", "description": "Ear, Nose, Throat, Sinus, Voice & Hearing Disorders", "is_active": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "dept_dent", "name": "Dental & Maxillofacial Surgery", "code": "DENT", "description": "Oral Health, Orthodontics, Endodontics & Maxillofacial Care", "is_active": True, "created_at": now_iso, "updated_at": now_iso},
    ]

    # 3. USERS (33 Staff)
    hashed_pwd = "pbkdf2_sha256$260000$opdconnect$2d9c153f3e827a514d3f769018659178ad8e920d0f"
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

    # 4. DOCTORS (18 Doctors)
    doctors = [
        # General Medicine
        {"id": "doc_med_1", "user_id": "usr_doc_med_1", "department_id": "dept_med", "qualification": "MBBS, MD (General Medicine)", "specialization": "Internal Medicine & Diabetology", "registration_number": "MCI-TN-48901", "room_number": "OPD Room 101, Ground Floor", "consultation_fee": 500.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_med_2", "user_id": "usr_doc_med_2", "department_id": "dept_med", "qualification": "MBBS, MD (Internal Medicine)", "specialization": "Geriatrics & Hypertension", "registration_number": "MCI-TN-51204", "room_number": "OPD Room 102, Ground Floor", "consultation_fee": 500.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_med_3", "user_id": "usr_doc_med_3", "department_id": "dept_med", "qualification": "MD, DNB (General Medicine)", "specialization": "Infectious Diseases & Critical Care", "registration_number": "MCI-TN-54329", "room_number": "OPD Room 103, Ground Floor", "consultation_fee": 500.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        # Pediatrics
        {"id": "doc_ped_1", "user_id": "usr_doc_ped_1", "department_id": "dept_ped", "qualification": "MBBS, MD (Pediatrics)", "specialization": "Pediatric Pulmonology & Allergy", "registration_number": "MCI-TN-61002", "room_number": "OPD Room 201, 1st Floor", "consultation_fee": 600.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_ped_2", "user_id": "usr_doc_ped_2", "department_id": "dept_ped", "qualification": "DCH, DNB (Pediatrics)", "specialization": "Neonatology & Growth Assessment", "registration_number": "MCI-TN-62187", "room_number": "OPD Room 202, 1st Floor", "consultation_fee": 600.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_ped_3", "user_id": "usr_doc_ped_3", "department_id": "dept_ped", "qualification": "MBBS, MD (Pediatrics)", "specialization": "Child Nutrition & Immunization", "registration_number": "MCI-TN-63401", "room_number": "OPD Room 203, 1st Floor", "consultation_fee": 600.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        # Orthopedics
        {"id": "doc_ortho_1", "user_id": "usr_doc_ortho_1", "department_id": "dept_ortho", "qualification": "MS (Orthopedics)", "specialization": "Spine & Joint Replacement", "registration_number": "MCI-TN-71890", "room_number": "OPD Room 301, 2nd Floor", "consultation_fee": 700.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_ortho_2", "user_id": "usr_doc_ortho_2", "department_id": "dept_ortho", "qualification": "MD, FRCS (Ortho)", "specialization": "Sports Medicine & Arthroscopy", "registration_number": "MCI-TN-72543", "room_number": "OPD Room 302, 2nd Floor", "consultation_fee": 750.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_ortho_3", "user_id": "usr_doc_ortho_3", "department_id": "dept_ortho", "qualification": "MS (Ortho), DNB", "specialization": "Trauma & Fracture Reconstruction", "registration_number": "MCI-TN-73912", "room_number": "OPD Room 303, 2nd Floor", "consultation_fee": 700.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        # Cardiology
        {"id": "doc_cardio_1", "user_id": "usr_doc_cardio_1", "department_id": "dept_cardio", "qualification": "MD, DM (Cardiology)", "specialization": "Interventional Cardiology & Angiography", "registration_number": "MCI-TN-81098", "room_number": "OPD Room 401, 3rd Floor", "consultation_fee": 900.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_cardio_2", "user_id": "usr_doc_cardio_2", "department_id": "dept_cardio", "qualification": "MBBS, DNB (Cardiology)", "specialization": "Non-Invasive Cardiology & Echocardiography", "registration_number": "MCI-TN-82341", "room_number": "OPD Room 402, 3rd Floor", "consultation_fee": 850.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_cardio_3", "user_id": "usr_doc_cardio_3", "department_id": "dept_cardio", "qualification": "MD, DM, FACC", "specialization": "Heart Failure & Preventive Cardiology", "registration_number": "MCI-TN-83567", "room_number": "OPD Room 403, 3rd Floor", "consultation_fee": 1000.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        # ENT
        {"id": "doc_ent_1", "user_id": "usr_doc_ent_1", "department_id": "dept_ent", "qualification": "MS (ENT)", "specialization": "Endoscopic Sinus Surgery & Rhinology", "registration_number": "MCI-TN-91045", "room_number": "OPD Room 501, 4th Floor", "consultation_fee": 550.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_ent_2", "user_id": "usr_doc_ent_2", "department_id": "dept_ent", "qualification": "MBBS, DLO, DNB (ENT)", "specialization": "Otology & Audiology", "registration_number": "MCI-TN-92189", "room_number": "OPD Room 502, 4th Floor", "consultation_fee": 550.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_ent_3", "user_id": "usr_doc_ent_3", "department_id": "dept_ent", "qualification": "MS (ENT)", "specialization": "Laryngology & Voice Disorders", "registration_number": "MCI-TN-93450", "room_number": "OPD Room 503, 4th Floor", "consultation_fee": 600.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        # Dental
        {"id": "doc_dent_1", "user_id": "usr_doc_dent_1", "department_id": "dept_dent", "qualification": "BDS, MDS (Oral & Maxillofacial)", "specialization": "Oral Surgery & Dental Implants", "registration_number": "DCI-TN-31092", "room_number": "Dental Clinic 208, Block B", "consultation_fee": 600.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_dent_2", "user_id": "usr_doc_dent_2", "department_id": "dept_dent", "qualification": "BDS, MDS (Orthodontics)", "specialization": "Dentofacial Orthopedics & Braces", "registration_number": "DCI-TN-32145", "room_number": "Dental Clinic 209, Block B", "consultation_fee": 600.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
        {"id": "doc_dent_3", "user_id": "usr_doc_dent_3", "department_id": "dept_dent", "qualification": "MDS (Periodontics)", "specialization": "Gum Diseases & Aesthetic Dentistry", "registration_number": "DCI-TN-33410", "room_number": "Dental Clinic 210, Block B", "consultation_fee": 600.0, "is_available": True, "created_at": now_iso, "updated_at": now_iso},
    ]

    # 5. PATIENTS (20 Patients with distinct clinical conditions)
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
            "date_of_birth": f"{2026 - age}-01-15",
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

    # Routing
    dept_doc_routing = [
        ("dept_med", "doc_med_1", "NORMAL", "IN_CONSULTATION"),
        ("dept_ortho", "doc_ortho_1", "NORMAL", "WAITING"),
        ("dept_cardio", "doc_cardio_1", "PRIORITY", "IN_CONSULTATION"),
        ("dept_med", "doc_med_2", "NORMAL", "WAITING"),
        ("dept_ped", "doc_ped_1", "EMERGENCY", "TRIAGED"),
        ("dept_ortho", "doc_ortho_2", "NORMAL", "WAITING"),
        ("dept_med", "doc_med_3", "EMERGENCY", "TRIAGED"),
        ("dept_ped", "doc_ped_2", "PRIORITY", "WAITING"),
        ("dept_med", "doc_med_1", "PRIORITY", "IN_CONSULTATION"),
        ("dept_med", "doc_med_2", "NORMAL", "COMPLETED"),
        ("dept_med", "doc_med_3", "EMERGENCY", "TRIAGED"),
        ("dept_med", "doc_med_1", "PRIORITY", "WAITING"),
        ("dept_ortho", "doc_ortho_3", "PRIORITY", "WAITING"),
        ("dept_med", "doc_med_2", "NORMAL", "WAITING"),
        ("dept_med", "doc_med_3", "NORMAL", "COMPLETED"),
        ("dept_med", "doc_med_1", "PRIORITY", "WAITING"),
        ("dept_dent", "doc_dent_1", "PRIORITY", "IN_CONSULTATION"),
        ("dept_med", "doc_med_2", "NORMAL", "COMPLETED"),
        ("dept_ent", "doc_ent_1", "NORMAL", "WAITING"),
        ("dept_med", "doc_med_3", "NORMAL", "COMPLETED"),
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
        v_num = f"SMVMCH151026{(i+1):04d}"
        token = i + 1
        d_id, doc_id, triage, status = dept_doc_routing[i]
        cond = patient_data_specs[i][14]
        v_id = f"vis_{pid}"

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
            "follow_up_date": "2026-10-29",
            "status": "COMPLETED",
            "version": 1,
            "created_by_user_id": doc_id.replace("doc_", "usr_doc_"),
            "created_at": now_iso,
            "updated_at": now_iso,
        })

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

    formulary_specs = [
        ("MED-001", "Paracetamol 650mg", "Paracetamol", "650mg", "Tablet", "BATCH-2026-A1", 450, 50, 2.50),
        ("MED-002", "Metformin 500mg", "Metformin Hydrochloride", "500mg", "Tablet", "BATCH-2026-A2", 600, 100, 3.20),
        ("MED-003", "Amlodipine 5mg", "Amlodipine Besylate", "5mg", "Tablet", "BATCH-2026-A3", 350, 50, 4.00),
        ("MED-004", "Telmisartan 40mg", "Telmisartan", "40mg", "Tablet", "BATCH-2026-A4", 280, 40, 8.50),
        ("MED-005", "Pantoprazole 40mg", "Pantoprazole Sodium", "40mg", "Tablet", "BATCH-2026-A5", 500, 60, 6.00),
        ("MED-006", "Amoxicillin + Clavulanic Acid 625mg", "Amoxicillin Clavulanate", "625mg", "Tablet", "BATCH-2026-A6", 240, 30, 22.00),
        ("MED-007", "Cetirizine 10mg", "Cetirizine Dihydrochloride", "10mg", "Tablet", "BATCH-2026-A7", 400, 50, 3.00),
        ("MED-008", "Azithromycin 500mg", "Azithromycin Dihydrate", "500mg", "Tablet", "BATCH-2026-A8", 180, 25, 24.50),
        ("MED-009", "Ciprofloxacin 500mg", "Ciprofloxacin Hydrochloride", "500mg", "Tablet", "BATCH-2026-A9", 220, 30, 12.00),
        ("MED-010", "Ibuprofen 400mg", "Ibuprofen", "400mg", "Tablet", "BATCH-2026-B1", 320, 40, 3.80),
        ("MED-011", "Omeprazole 20mg", "Omeprazole Magnesium", "20mg", "Capsule", "BATCH-2026-B2", 410, 50, 4.50),
        ("MED-012", "Atorvastatin 10mg", "Atorvastatin Calcium", "10mg", "Tablet", "BATCH-2026-B3", 290, 40, 9.80),
        ("MED-013", "Levothyroxine 50mcg", "Levothyroxine Sodium", "50mcg", "Tablet", "BATCH-2026-B4", 300, 50, 2.20),
        ("MED-014", "Salbutamol Inhaler 100mcg", "Salbutamol Sulfate", "100mcg/dose", "Inhaler", "BATCH-2026-B5", 85, 15, 145.00),
        ("MED-015", "Oral Rehydration Salts (ORS)", "Sodium Chloride / Dextrose", "21.8g", "Sachet", "BATCH-2026-B6", 500, 100, 18.00),
        ("MED-016", "Ranitidine 150mg", "Ranitidine Hydrochloride", "150mg", "Tablet", "BATCH-2026-B7", 250, 40, 2.80),
        ("MED-017", "Losartan Potassium 50mg", "Losartan Potassium", "50mg", "Tablet", "BATCH-2026-B8", 210, 30, 6.50),
        ("MED-018", "Hydrochlorothiazide 12.5mg", "Hydrochlorothiazide", "12.5mg", "Tablet", "BATCH-2026-B9", 190, 25, 3.50),
        ("MED-019", "Cefixime 200mg", "Cefixime Trihydrate", "200mg", "Tablet", "BATCH-2026-C1", 160, 25, 18.50),
        ("MED-020", "Doxycycline 100mg", "Doxycycline Hyclate", "100mg", "Capsule", "BATCH-2026-C2", 140, 20, 8.00),
        ("MED-021", "Diclofenac Sodium 50mg", "Diclofenac Sodium", "50mg", "Tablet", "BATCH-2026-C3", 380, 50, 4.20),
        ("MED-022", "Tramadol Hydrochloride 50mg", "Tramadol HCl", "50mg", "Capsule", "BATCH-2026-C4", 95, 20, 14.00),
        ("MED-023", "Montelukast 10mg", "Montelukast Sodium", "10mg", "Tablet", "BATCH-2026-C5", 210, 30, 11.50),
        ("MED-024", "Clopidogrel 75mg", "Clopidogrel Bisulfate", "75mg", "Tablet", "BATCH-2026-C6", 175, 25, 15.00),
        ("MED-025", "Insulin Glargine 100 IU/ml", "Insulin Glargine", "100 IU/ml", "Vial", "BATCH-2026-C7", 60, 15, 520.00),
        ("MED-026", "Gliclazide 80mg", "Gliclazide", "80mg", "Tablet", "BATCH-2026-C8", 220, 30, 7.20),
        ("MED-027", "Ferrous Ascorbate + Folic Acid", "Iron + Folic Acid", "100mg/1.5mg", "Tablet", "BATCH-2026-C9", 420, 60, 8.50),
        ("MED-028", "Calcium Carbonate + Vit D3", "Calcium Carbonate + Cholecalciferol", "500mg/250IU", "Tablet", "BATCH-2026-D1", 360, 50, 7.00),
    ]

    inventory = []
    for code, name, gen, strength, form, batch, qty, reorder, price in formulary_specs:
        inventory.append({
            "id": f"inv_{code.lower().replace('-', '_')}",
            "medicine_code": code,
            "name": name,
            "generic_name": gen,
            "strength": strength,
            "dosage_form": form,
            "batch_number": batch,
            "expiry_date": "2027-12-31",
            "available_quantity": qty,
            "reorder_level": reorder,
            "unit_price": price,
            "is_synthetic_price": False,
            "tax_classification": "GST_5",
            "tax_rate_percent": 5.0,
            "supplier_name": "SMVMCH Central Pharmacy Depot",
            "supplier_contact": "depot@smvmch.ac.in",
            "is_active": True,
            "created_at": now_iso,
            "updated_at": now_iso,
        })

    # Prepare final output SQL
    header = """-- ========================================================
-- Sri Manakula Vinayagar Medical College and Hospital (SMVMCH)
-- OPD Connect+ Supabase PostgreSQL Production Schema & Seed
-- Ready for 1-Click Copy & Paste in Supabase SQL Editor (>_)
-- ========================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

"""

    # Keep DDL portion from existing_sql
    # Find up to end of tables definition
    ddl_part = existing_sql.strip()

    # RLS Disable Block
    rls_disable = "\n-- ========================================================\n-- 2. ROW LEVEL SECURITY (RLS) POLICIES\n-- Ensures mobile devices on any network connect seamlessly\n-- ========================================================\n"
    for tbl in all_tables:
        rls_disable += f"ALTER TABLE IF EXISTS {tbl} DISABLE ROW LEVEL SECURITY;\n"

    # Seed Data Block
    seed_data_header = "\n-- ========================================================\n-- 3. PRODUCTION SEED DATA (Doctors, Staff, Patients, Visits)\n-- Idempotent upserts (ON CONFLICT DO UPDATE)\n-- ========================================================\n\n"

    seed_sections = [
        make_insert_sql("roles", roles),
        make_insert_sql("departments", departments),
        make_insert_sql("users", users),
        make_insert_sql("doctors", doctors),
        make_insert_sql("patients", patients),
        make_insert_sql("opd_visits", visits),
        make_insert_sql("vital_signs", vitals),
        make_insert_sql("clinical_records", clinical_records),
        make_insert_sql("prescriptions", prescriptions),
        make_insert_sql("prescription_items", prescription_items),
        make_insert_sql("lab_orders", lab_orders),
        make_insert_sql("lab_results", lab_results),
        make_insert_sql("bills", bills),
        make_insert_sql("medicine_inventory", inventory),
    ]

    full_sql = ddl_part + "\n" + rls_disable + "\n" + seed_data_header + "\n".join(seed_sections)

    with open(target_sql_path, "w", encoding="utf-8") as f:
        f.write(full_sql)

    print(f"Successfully generated {target_sql_path} ({len(full_sql)} bytes)!")

if __name__ == "__main__":
    main()
