"""
Seed initial synthetic data for OPD Connect+ development:
- Core Roles (admin, doctor, nurse, receptionist, lab_tech, pharmacist)
- Hospital Departments (General Medicine, Pediatrics, Orthopedics, Cardiology, ENT)
- Default Staff (Dr. Sarah Chen, Receptionist Alice)
- Initial Demo Patients and Visits
"""
import os
import sys
from pathlib import Path
from datetime import datetime, date

# Ensure backend root is in sys.path
backend_dir = Path(__file__).resolve().parent.parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from sqlalchemy.orm import Session
from app.core.database import SessionLocal, engine, Base
from app.core.security import get_password_hash
import app.models  # Ensure all models are registered on Base.metadata
from app.models.user import Role, User, Permission, role_permissions, RefreshTokenSession
from app.models.department import Department
from app.models.doctor import Doctor
from app.models.patient import Patient
from app.models.visit import OPDVisit, VitalSigns
from app.models.clinical import ClinicalRecord
from app.models.prescription import Prescription, PrescriptionItem
from app.models.pharmacy import MedicineInventory, StockMovement
from app.models.billing import Bill, BillItem, PaymentTransaction
from app.models.config import SystemConfig


def seed_database():
    Base.metadata.create_all(bind=engine)
    db: Session = SessionLocal()

    try:
        # 1. Roles
        role_names = ["admin", "doctor", "nurse", "receptionist", "lab_tech", "laboratory", "pharmacist", "patient"]
        roles = {}
        for r_name in role_names:
            role = db.query(Role).filter(Role.name == r_name).first()
            if not role:
                role = Role(name=r_name, description=f"Hospital {r_name} role")
                db.add(role)
                db.flush()
            roles[r_name] = role

        # 1b. Permissions & Role Mapping
        permissions_data = [
            ("patient:read", "View patient demographics", "Read patient profile and permitted records"),
            ("patient:write", "Register/update patients", "Create or edit patient records"),
            ("patient:dependents", "Manage dependent profiles", "Link or manage family dependents"),
            ("clinical:read", "View clinical consultation records", "Doctor or clinician consultation review"),
            ("clinical:write", "Record clinical diagnoses and vitals", "Sign clinical sheets and prescriptions"),
            ("clinical:audit", "Clinical record audit override", "Authorized medical auditor access"),
            ("admin:users", "Manage hospital staff accounts", "Provision, activate, deactivate, or unlock users"),
            ("admin:roles", "Manage roles and privileges", "Modify staff roles and permissions"),
            ("admin:config", "Configure hospital settings", "Edit system configs and catalogues"),
            ("admin:reports", "Generate operational reports", "Access and export hospital footfall and billing reports"),
            ("admin:audit", "Search and inspect audit logs", "Compliance and security audit log inspection"),
            ("billing:read", "View invoices and payments", "Read-only access to billing data"),
            ("billing:write", "Process bills and refunds", "Generate invoices, payments, and refunds"),
            ("pharmacy:read", "View inventory and stock", "Read stock levels and drug catalogues"),
            ("pharmacy:write", "Dispense medicines and adjust stock", "Prescription dispensing and stock adjustments"),
            ("lab:read", "View laboratory orders", "Read lab orders and results"),
            ("lab:write", "Enter lab results and verify", "Enter specimen results and sign off"),
        ]
        perms = {}
        for code, name, desc in permissions_data:
            perm = db.query(Permission).filter(Permission.code == code).first()
            if not perm:
                perm = Permission(code=code, name=name, description=desc)
                db.add(perm)
                db.flush()
            perms[code] = perm

        role_perm_map = {
            "admin": ["admin:users", "admin:roles", "admin:config", "admin:reports", "admin:audit", "billing:read", "billing:write", "pharmacy:read", "pharmacy:write", "lab:read", "patient:read"],
            "doctor": ["patient:read", "clinical:read", "clinical:write", "lab:read", "lab:write", "pharmacy:read"],
            "nurse": ["patient:read", "clinical:write", "lab:read"],
            "receptionist": ["patient:read", "patient:write", "billing:read", "billing:write"],
            "pharmacist": ["pharmacy:read", "pharmacy:write", "billing:read", "billing:write"],
            "laboratory": ["lab:read", "lab:write"],
            "lab_tech": ["lab:read", "lab:write"],
            "patient": ["patient:read", "patient:dependents", "billing:read"],
        }
        for r_name, p_codes in role_perm_map.items():
            r_obj = roles.get(r_name)
            if not r_obj:
                continue
            for p_code in p_codes:
                p_obj = perms.get(p_code)
                if p_obj and p_obj not in r_obj.permissions:
                    r_obj.permissions.append(p_obj)
        db.flush()

        # 1c. System Configs
        default_configs = [
            ("hospital_name", "Sri Manakula Vinayagar Medical College and Hospital", "HOSPITAL", "Official hospital name printed on OPD booklets and receipts"),
            ("hospital_tamil_name", "ஸ்ரீ மணக்குள விநாயகர் மருத்துவக் கல்லூரி மற்றும் மருத்துவமனை", "HOSPITAL", "Official Tamil hospital name"),
            ("hospital_code", "SMVMCH", "HOSPITAL", "Hospital code prefix for registrations"),
            ("hospital_address", "Kalitheerthalkuppam, Madagadipet, Puducherry - 605 107", "HOSPITAL", "Campus address"),
            ("hospital_phone", "0413 - 2643000", "HOSPITAL", "Official hospital telephone"),
            ("hospital_email", "principal@smvmch.ac.in", "HOSPITAL", "Official administrative email"),
            ("hospital_website", "www.smvmch.ac.in", "HOSPITAL", "Official hospital website"),
            ("hospital_gstin", "34AAATM9599A1ZE", "BILLING", "Hospital GST identification number"),
            ("hospital_tin", "34880001919", "BILLING", "Hospital TIN registration number"),
            ("pharmacy_dl_nos", "RLF20PY2024000071 / RLF21PY2024000075 / RLF20F2024PY000001", "PHARMACY", "Pharmacy drug licenses"),
            ("opd_operating_hours", "24 Hours Casualty & Emergency • OPD: 08:00 AM - 08:00 PM", "HOSPITAL", "Daily OPD operating hours"),
            ("consultation_default_fee", "500.00", "BILLING", "Default general OPD consultation fee"),
            ("tax_rate_medicines", "5.0", "BILLING", "Standard tax percentage for essential medicines (CGST 2.5% + SGST 2.5%)"),
            ("tax_rate_services", "0.0", "BILLING", "Standard tax percentage for clinical healthcare services (exempt)"),
            ("backup_schedule", "Daily at 02:00 AM UTC", "BACKUP", "Automated backup schedule"),
            ("backup_retention_days", "30", "BACKUP", "Snapshot retention period in days"),
            ("emergency_helpline", "0413 - 2643000", "HOSPITAL", "24/7 Hospital emergency helpline"),
        ]
        for c_key, c_val, c_cat, c_desc in default_configs:
            cfg = db.query(SystemConfig).filter(SystemConfig.config_key == c_key).first()
            if not cfg:
                cfg = SystemConfig(config_key=c_key, config_value=c_val, category=c_cat, description=c_desc)
                db.add(cfg)
        db.flush()

        # 2. Departments
        departments_data = [
            ("General Medicine", "MED", "Internal medicine, acute infections, lifestyle disorders"),
            ("Dental / Maxillofacial Surgery", "DENT", "Oral, dental, and maxillofacial surgery OPD"),
            ("Pediatrics", "PED", "Comprehensive infant, child, and adolescent healthcare"),
            ("Orthopedics", "ORTH", "Bone, joint, spine, and trauma consultations"),
            ("Cardiology", "CARD", "Heart conditions, hypertension, preventive cardiology"),
            ("ENT", "ENT", "Ear, nose, throat and head-neck consultations"),
        ]
        departments = {}
        for name, code, desc in departments_data:
            dept = db.query(Department).filter(Department.code == code).first()
            if not dept:
                dept = Department(name=name, code=code, description=desc, is_active=True)
                db.add(dept)
                db.flush()
            departments[code] = dept

        # 3. Staff Users

        # Admin
        admin_user = db.query(User).filter((User.email == "admin@smvmch.ac.in") | (User.phone == "+1555000001")).first()
        if not admin_user:
            admin_user = User(
                email="admin@smvmch.ac.in",
                full_name="Admin Administrator",
                phone="+1555000001",
                hashed_password=get_password_hash("Admin@123"),
                role_id=roles["admin"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(admin_user)
            db.flush()
        else:
            admin_user.email = "admin@smvmch.ac.in"
            admin_user.hashed_password = get_password_hash("Admin@123")
            admin_user.is_active = True
            db.flush()

        # Doctor User
        doc_user = db.query(User).filter((User.email == "doctor@smvmch.ac.in") | (User.phone == "+1555000002")).first()
        if not doc_user:
            doc_user = User(
                email="doctor@smvmch.ac.in",
                full_name="Dr. Sarah Chen, MD",
                phone="+1555000002",
                hashed_password=get_password_hash("Doctor@123"),
                role_id=roles["doctor"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(doc_user)
            db.flush()
        else:
            doc_user.email = "doctor@smvmch.ac.in"
            doc_user.hashed_password = get_password_hash("Doctor@123")
            doc_user.is_active = True
            db.flush()

        # Doctor Profile
        doctor = db.query(Doctor).filter(Doctor.user_id == doc_user.id).first()
        if not doctor:
            doctor = Doctor(
                user_id=doc_user.id,
                department_id=departments["MED"].id,
                qualification="MBBS, MD (Internal Medicine)",
                specialization="General Medicine",
                registration_number="MCI-2018-98421",
                room_number="Room 104, OPD Block A",
                consultation_fee="500.00",
                is_available=True,
            )
            db.add(doctor)
            db.flush()

        # Receptionist
        rec_user = db.query(User).filter((User.email == "reception@smvmch.ac.in") | (User.phone == "+1555000003")).first()
        if not rec_user:
            rec_user = User(
                email="reception@smvmch.ac.in",
                full_name="Alice Adams (Reception Desk)",
                phone="+1555000003",
                hashed_password=get_password_hash("Reception@123"),
                role_id=roles["receptionist"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(rec_user)
            db.flush()
        else:
            rec_user.email = "reception@smvmch.ac.in"
            rec_user.hashed_password = get_password_hash("Reception@123")
            rec_user.is_active = True
            db.flush()

        # Laboratory Staff
        lab_user = db.query(User).filter((User.email == "lab@smvmch.ac.in") | (User.phone == "+1555000004")).first()
        if not lab_user:
            lab_user = User(
                email="lab@smvmch.ac.in",
                full_name="Marcus Vance (Lab Tech)",
                phone="+1555000004",
                hashed_password=get_password_hash("Lab@123"),
                role_id=roles["lab_tech"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(lab_user)
            db.flush()
        else:
            lab_user.email = "lab@smvmch.ac.in"
            lab_user.hashed_password = get_password_hash("Lab@123")
            lab_user.is_active = True
            db.flush()

        # Pharmacist
        pharm_user = db.query(User).filter((User.email == "pharmacy@smvmch.ac.in") | (User.phone == "+1555000005")).first()
        if not pharm_user:
            pharm_user = User(
                email="pharmacy@smvmch.ac.in",
                full_name="Elena Rostova (Pharmacist)",
                phone="+1555000005",
                hashed_password=get_password_hash("Pharmacy@123"),
                role_id=roles["pharmacist"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(pharm_user)
            db.flush()
        else:
            pharm_user.email = "pharmacy@smvmch.ac.in"
            pharm_user.hashed_password = get_password_hash("Pharmacy@123")
            pharm_user.is_active = True
            db.flush()

        # Nurse User
        nurse_user = db.query(User).filter((User.email == "nurse@smvmch.ac.in") | (User.phone == "+1555000006")).first()
        if not nurse_user:
            nurse_user = User(
                email="nurse@smvmch.ac.in",
                full_name="Sister Priya (Triage Nurse)",
                phone="+1555000006",
                hashed_password=get_password_hash("Nurse@123"),
                role_id=roles["nurse"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(nurse_user)
            db.flush()

        # Billing Cashier User
        billing_user = db.query(User).filter((User.email == "billing@smvmch.ac.in") | (User.phone == "+1555000007")).first()
        if not billing_user:
            billing_user = User(
                email="billing@smvmch.ac.in",
                full_name="Rajesh Kumar (Billing Desk)",
                phone="+1555000007",
                hashed_password=get_password_hash("Billing@123"),
                role_id=roles["billing" if "billing" in roles else "receptionist"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(billing_user)
            db.flush()

        # SMVMCH Official Specialty Medical Consultants
        institutional_staff = [
            ("pulmonology@smvmch.ac.in", "Dr. Harish Patel, MD", "+1555000031", "Doctor@123", "doctor"),
            ("cardiology@smvmch.ac.in", "Dr. R. Venkatesh, DM", "+1555000032", "Doctor@123", "doctor"),
            ("pediatrics@smvmch.ac.in", "Dr. Ananya Roy, MD", "+1555000033", "Doctor@123", "doctor"),
            ("orthopedics@smvmch.ac.in", "Dr. Vikram Mehta, MS", "+1555000034", "Doctor@123", "doctor"),
            ("dermatology@smvmch.ac.in", "Dr. Ananya Rao, MD", "+1555000035", "Doctor@123", "doctor"),
            ("endocrinology@smvmch.ac.in", "Dr. S. Kulkarni, DM", "+1555000036", "Doctor@123", "doctor"),
            ("gastroenterology@smvmch.ac.in", "Dr. Pradeep Menon, DM", "+1555000037", "Doctor@123", "doctor"),
            ("neurology@smvmch.ac.in", "Dr. Vikram Seth, DM", "+1555000038", "Doctor@123", "doctor"),
            ("oncology@smvmch.ac.in", "Dr. Malini Iyer, MD DM", "+1555000039", "Doctor@123", "doctor"),
            ("nephrology@smvmch.ac.in", "Dr. Gautam Das, DM", "+1555000040", "Doctor@123", "doctor"),
            ("gynecology@smvmch.ac.in", "Dr. Radhika Nair, MS DGO", "+1555000041", "Doctor@123", "doctor"),
            ("dental@smvmch.ac.in", "Dr. M. Arunraj, MDS", "+1555000042", "Doctor@123", "doctor"),
            ("ent@smvmch.ac.in", "Dr. Kavita Nair, MS ENT", "+1555000043", "Doctor@123", "doctor"),
        ]
        for inst_email, inst_name, inst_phone, inst_pass, inst_role in institutional_staff:
            u_check = db.query(User).filter(User.email == inst_email).first()
            if not u_check:
                u_check = User(
                    email=inst_email,
                    full_name=inst_name,
                    phone=inst_phone,
                    hashed_password=get_password_hash(inst_pass),
                    role_id=roles[inst_role].id,
                    is_active=True,
                    is_verified=True,
                )
                db.add(u_check)
                db.flush()

        # 4. Standard Essential Medicine Catalogue (Clean Master Formulary)
        medicines_data = [
            {
                "medicine_code": "MED-PCM-650-01",
                "name": "Paracetamol",
                "generic_name": "Paracetamol",
                "strength": "650 mg",
                "dosage_form": "Tablet",
                "batch_number": "BAT-2026-001",
                "expiry_date": date(2027, 12, 31),
                "available_quantity": 500,
                "reorder_level": 50,
                "unit_price": 2.50,
                "tax_classification": "GST_5",
            },
            {
                "medicine_code": "MED-AMX-500-02",
                "name": "Amoxicillin",
                "generic_name": "Amoxicillin",
                "strength": "500 mg",
                "dosage_form": "Capsule",
                "batch_number": "BAT-2026-002",
                "expiry_date": date(2027, 8, 15),
                "available_quantity": 300,
                "reorder_level": 30,
                "unit_price": 7.20,
                "tax_classification": "GST_5",
            },
            {
                "medicine_code": "MED-CTZ-010-03",
                "name": "Cetirizine",
                "generic_name": "Cetirizine Hydrochloride",
                "strength": "10 mg",
                "dosage_form": "Tablet",
                "batch_number": "BAT-2026-003",
                "expiry_date": date(2028, 3, 20),
                "available_quantity": 250,
                "reorder_level": 25,
                "unit_price": 3.00,
                "tax_classification": "GST_5",
            },
            {
                "medicine_code": "MED-PAN-040-04",
                "name": "Pantoprazole",
                "generic_name": "Pantoprazole Sodium",
                "strength": "40 mg",
                "dosage_form": "Tablet",
                "batch_number": "BAT-2026-004",
                "expiry_date": date(2027, 10, 10),
                "available_quantity": 400,
                "reorder_level": 40,
                "unit_price": 6.50,
                "tax_classification": "GST_5",
            },
            {
                "medicine_code": "MED-MET-500-05",
                "name": "Metformin",
                "generic_name": "Metformin Hydrochloride",
                "strength": "500 mg",
                "dosage_form": "Tablet",
                "batch_number": "BAT-2026-005",
                "expiry_date": date(2027, 9, 30),
                "available_quantity": 500,
                "reorder_level": 50,
                "unit_price": 4.00,
                "tax_classification": "GST_5",
            },
            {
                "medicine_code": "MED-AZI-500-06",
                "name": "Azithromycin",
                "generic_name": "Azithromycin Dihydrate",
                "strength": "500 mg",
                "dosage_form": "Tablet",
                "batch_number": "BAT-2026-006",
                "expiry_date": date(2027, 11, 15),
                "available_quantity": 200,
                "reorder_level": 30,
                "unit_price": 18.00,
                "tax_classification": "GST_12",
            },
            {
                "medicine_code": "MED-SAL-100-07",
                "name": "Salbutamol Inhaler",
                "generic_name": "Salbutamol Sulfate",
                "strength": "100 mcg",
                "dosage_form": "Inhaler",
                "batch_number": "BAT-2026-007",
                "expiry_date": date(2027, 6, 30),
                "available_quantity": 80,
                "reorder_level": 20,
                "unit_price": 120.00,
                "tax_classification": "GST_12",
            },
        ]

        for m_data in medicines_data:
            existing_med = db.query(MedicineInventory).filter(MedicineInventory.batch_number == m_data["batch_number"]).first()
            if not existing_med:
                med = MedicineInventory(
                    medicine_code=m_data["medicine_code"],
                    name=m_data["name"],
                    generic_name=m_data["generic_name"],
                    strength=m_data["strength"],
                    dosage_form=m_data["dosage_form"],
                    batch_number=m_data["batch_number"],
                    expiry_date=m_data["expiry_date"],
                    available_quantity=m_data["available_quantity"],
                    reorder_level=m_data["reorder_level"],
                    unit_price=m_data["unit_price"],
                    is_synthetic_price=False,
                    tax_classification=m_data["tax_classification"],
                    supplier_name="Hospital Central Pharmacy Formulary",
                )
                db.add(med)
                db.flush()

                movement = StockMovement(
                    inventory_id=med.id,
                    movement_type="PURCHASE_RECEIPT",
                    quantity=med.available_quantity,
                    balance_after=med.available_quantity,
                    reference_number=f"INIT-{med.batch_number}",
                    reason="Initial hospital pharmacy inventory baseline",
                )
                db.add(movement)

        # 5. Doctor Dr. Arunraj (SMVMCH Dental & Oral Surgery Specialist from document)
        doc_arun_user = db.query(User).filter(User.email == "dental@smvmch.ac.in").first()
        if not doc_arun_user:
            doc_arun_user = User(
                email="dental@smvmch.ac.in",
                full_name="Dr. M. Arunraj, MDS",
                phone="+1555000042",
                hashed_password=get_password_hash("Doctor@123"),
                role_id=roles["doctor"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(doc_arun_user)
            db.flush()
        else:
            doc_arun_user.email = "dental@smvmch.ac.in"
            doc_arun_user.hashed_password = get_password_hash("Doctor@123")
            db.flush()

        doctor_arun = db.query(Doctor).filter(Doctor.user_id == doc_arun_user.id).first()
        if not doctor_arun:
            doctor_arun = Doctor(
                user_id=doc_arun_user.id,
                department_id=departments["DENT"].id,
                qualification="BDS, MDS (Oral & Maxillofacial Surgery)",
                specialization="Dental & Oral Surgery",
                registration_number="TNDC-2016-44120",
                room_number="Room 208, Dental OPD",
                consultation_fee="500.00",
                is_available=True,
            )
        # 6. Canonical Verified Patients & Patient Portals
        canonical_patients = [
            {
                "id": "9791dc19-e67c-4921-8f9b-d1c6c8d12408",
                "uhid": "UHID-2026-00001",
                "hospital_reg_num": "REG-2026-00001",
                "full_name": "Lakshmi Srujana Majeti",
                "parent_spouse_name": "Majeti Satyanarayana",
                "parent_spouse_relation": "D/o",
                "gender": "FEMALE",
                "age_years": 22,
                "phone": "8374477999",
                "email": "srujana@smvmch.ac.in",
                "address": "Flat 402, Sri Krishna Heights, Kalitheerthalkuppam",
                "city": "Puducherry",
                "state": "Puducherry",
                "postal_code": "605107",
                "blood_group": "O+",
            },
            {
                "id": "746b2fb8-cc53-4e2f-aa85-0388067b1022",
                "uhid": "UHID-2026-00002",
                "hospital_reg_num": "REG-2026-00002",
                "full_name": "Uday Kumar",
                "parent_spouse_name": "S. Kumar",
                "parent_spouse_relation": "S/o",
                "gender": "MALE",
                "age_years": 23,
                "phone": "9347989890",
                "email": "uday.kumar@gmail.com",
                "address": "12 Anna Nagar",
                "city": "Puducherry",
                "state": "Puducherry",
                "postal_code": "605001",
                "blood_group": "A+",
            },
            {
                "id": "f5c22d18-d291-4992-adbc-01351ac5c40f",
                "uhid": "UHID-2026-00003",
                "hospital_reg_num": "REG-2026-00003",
                "full_name": "Ravi Shankar",
                "parent_spouse_name": "Prasad",
                "parent_spouse_relation": "S/o",
                "gender": "MALE",
                "age_years": 25,
                "phone": "9876543211",
                "email": "ravi@gmail.com",
                "address": "Main Bazaar",
                "city": "Puducherry",
                "state": "Puducherry",
                "postal_code": "605001",
                "blood_group": "O+",
            },
            {
                "id": "b45c7957-b64f-4fd8-b9ef-705bf68da328",
                "uhid": "UHID-2026-00004",
                "hospital_reg_num": "REG-2026-00004",
                "full_name": "Pavan Surya",
                "parent_spouse_name": "Venkatesh",
                "parent_spouse_relation": "S/o",
                "gender": "MALE",
                "age_years": 25,
                "phone": "9876543222",
                "email": "pavan@gmail.com",
                "address": "Beach Road",
                "city": "Puducherry",
                "state": "Puducherry",
                "postal_code": "605001",
                "blood_group": "O+",
            },
            {
                "id": "pat-sheela-00005",
                "uhid": "UHID-2026-00005",
                "hospital_reg_num": "REG-2026-00005",
                "full_name": "Sheela",
                "parent_spouse_name": "David",
                "parent_spouse_relation": "D/o",
                "gender": "FEMALE",
                "age_years": 25,
                "phone": "9999999999",
                "email": "sheela@gmail.com",
                "address": "Moon Land",
                "city": "Puducherry",
                "state": "Puducherry",
                "postal_code": "605001",
                "blood_group": "A-",
            },
            {
                "id": "pat-samanta-00006",
                "uhid": "UHID-2026-00006",
                "hospital_reg_num": "REG-2026-00006",
                "full_name": "Samanta",
                "parent_spouse_name": "Subramaniam",
                "parent_spouse_relation": "W/o",
                "gender": "FEMALE",
                "age_years": 79,
                "phone": "1234567890",
                "email": "samanta@gmail.com",
                "address": "Heritage Town",
                "city": "Puducherry",
                "state": "Puducherry",
                "postal_code": "605001",
                "blood_group": "B+",
            },
            {
                "id": "pat-teja-00007",
                "uhid": "UHID-2026-00007",
                "hospital_reg_num": "REG-2026-00007",
                "full_name": "Teja",
                "parent_spouse_name": "Narayana",
                "parent_spouse_relation": "S/o",
                "gender": "MALE",
                "age_years": 25,
                "phone": "9848022338",
                "email": "teja@gmail.com",
                "address": "Villupuram Road",
                "city": "Puducherry",
                "state": "Puducherry",
                "postal_code": "605107",
                "blood_group": "AB+",
            },
            {
                "id": "57cdc8e1-bbe5-4386-a47f-436bd078d80d",
                "uhid": "UHID-2026-00008",
                "hospital_reg_num": "REG-2026-00008",
                "full_name": "Swaroop",
                "parent_spouse_name": "Akhil",
                "parent_spouse_relation": "S/o",
                "gender": "MALE",
                "age_years": 23,
                "phone": "9988776655",
                "email": "swaroop@gmail.com",
                "address": "Vicity",
                "city": "Puducherry",
                "state": "Puducherry",
                "postal_code": "552630",
                "blood_group": "B-",
            },
            {
                "id": "pat-1792739937154",
                "uhid": "UHID-2026-00009",
                "hospital_reg_num": "REG-2026-00009",
                "full_name": "Syam Peddiraju",
                "parent_spouse_name": "Peddiraju",
                "parent_spouse_relation": "S/o",
                "gender": "MALE",
                "age_years": 20,
                "phone": "7337262831",
                "email": "syam@gmail.com",
                "address": "Puducherry",
                "city": "Puducherry",
                "state": "Puducherry",
                "postal_code": "605001",
                "blood_group": "O+",
            },
        ]

        patient_role = roles.get("patient")
        for cp in canonical_patients:
            pat = db.query(Patient).filter(Patient.id == cp["id"]).first()
            if not pat:
                pat = db.query(Patient).filter(Patient.uhid == cp["uhid"]).first()
            if not pat:
                pat = Patient(
                    id=cp["id"],
                    uhid=cp["uhid"],
                    hospital_reg_num=cp["hospital_reg_num"],
                    full_name=cp["full_name"],
                    parent_spouse_name=cp["parent_spouse_name"],
                    parent_spouse_relation=cp["parent_spouse_relation"],
                    gender=cp["gender"],
                    age_years=cp["age_years"],
                    phone=cp["phone"],
                    email=cp["email"],
                    address=cp["address"],
                    city=cp["city"],
                    state=cp["state"],
                    postal_code=cp["postal_code"],
                    blood_group=cp["blood_group"],
                    barcode_value=f"BAR-{cp['uhid']}",
                    qr_code_data=f"OPDCONNECT+{cp['uhid']}+{cp['hospital_reg_num']}",
                )
                db.add(pat)
                db.flush()
            else:
                pat.uhid = cp["uhid"]
                pat.hospital_reg_num = cp["hospital_reg_num"]
                pat.full_name = cp["full_name"]
                pat.parent_spouse_name = cp["parent_spouse_name"]
                pat.parent_spouse_relation = cp["parent_spouse_relation"]
                pat.gender = cp["gender"]
                pat.age_years = cp["age_years"]
                pat.phone = cp["phone"]
                pat.email = cp["email"]
                pat.address = cp["address"]
                pat.city = cp["city"]
                pat.state = cp["state"]
                pat.postal_code = cp["postal_code"]
                pat.blood_group = cp["blood_group"]
                db.flush()

            # Ensure linked patient user account
            pat_user = db.query(User).filter((User.patient_id == pat.id) | (User.phone == cp["phone"])).first()
            if pat_user:
                pat_user.full_name = cp["full_name"]
                pat_user.phone = cp["phone"]
                pat_user.patient_id = pat.id
                pat_user.is_active = True
                pat_user.is_verified = True
                db.flush()
            elif patient_role:
                pat_email = f"patient_{cp['uhid'].lower().replace('-', '_')}@opdconnect.local"
                pat_user = User(
                    email=pat_email,
                    phone=cp["phone"],
                    full_name=cp["full_name"],
                    hashed_password=get_password_hash("Patient@123"),
                    role_id=patient_role.id,
                    patient_id=pat.id,
                    is_active=True,
                    is_verified=True,
                )
                db.add(pat_user)
                db.flush()

        # 7. Initial Clinical Consultation & Prescription for Lakshmi Srujana Majeti
        srujana_pat = db.query(Patient).filter(Patient.uhid == "UHID-2026-00001").first()
        gen_med_dept = db.query(Department).filter(Department.code == "MED").first()
        gen_med_doc = db.query(Doctor).first()
        nurse_u = db.query(User).filter(User.email == "nurse@smvmch.ac.in").first()

        if srujana_pat and gen_med_doc and gen_med_dept:
            vis_srujana = db.query(OPDVisit).filter(OPDVisit.patient_id == srujana_pat.id).first()
            if not vis_srujana:
                vis_srujana = OPDVisit(
                    id="1e7ab4f3-e305-450d-888b-01a77b6023f5",
                    visit_number="SMVMCH2210260002",
                    patient_id=srujana_pat.id,
                    doctor_id=gen_med_doc.id,
                    department_id=gen_med_dept.id,
                    visit_date=datetime.now(),
                    queue_token=2,
                    triage_priority="NORMAL",
                    status="COMPLETED",
                    consultation_fee=500.0,
                    payment_status="PAID",
                    notes="Consultation completed. Patient advised rest and symptomatic treatment.",
                )
                db.add(vis_srujana)
                db.flush()
            else:
                vis_srujana.status = "COMPLETED"
                vis_srujana.payment_status = "PAID"
                db.flush()

            # Vitals
            vit_srujana = db.query(VitalSigns).filter(VitalSigns.visit_id == vis_srujana.id).first()
            if not vit_srujana:
                vit_srujana = VitalSigns(
                    id="vit-srujana-00001",
                    visit_id=vis_srujana.id,
                    recorded_by_user_id=nurse_u.id if nurse_u else None,
                    systolic_bp=118,
                    diastolic_bp=76,
                    pulse_rate=74,
                    temperature_f=98.4,
                    spo2_percent=99.0,
                    respiratory_rate=16,
                    weight_kg=54.0,
                    height_cm=162.0,
                    bmi=20.6,
                    blood_glucose_mg_dl=95.0,
                    recorded_at=datetime.now(),
                    notes="Normal vitals, afebrile at triage",
                )
                db.add(vit_srujana)
                db.flush()

            # Clinical record
            cr_srujana = db.query(ClinicalRecord).filter(ClinicalRecord.visit_id == vis_srujana.id).first()
            if not cr_srujana:
                cr_srujana = ClinicalRecord(
                    id="cr-srujana-00001",
                    visit_id=vis_srujana.id,
                    patient_id=srujana_pat.id,
                    doctor_id=gen_med_doc.id,
                    presenting_complaint="Mild fever and seasonal allergic rhinitis for 2 days",
                    history_of_present_illness="Patient reports low grade intermittent fever, mild headache and sneezing since 2 days. No breathing difficulty, cough, or nausea.",
                    allergies="No known drug allergies (NKDA)",
                    past_medical_history="None significant",
                    smoking_history="Non-smoker",
                    alcohol_history="None",
                    general_examination="Conscious, oriented, afebrile, well-hydrated. Throat: Mild pharyngeal congestion. Chest: Clear.",
                    respiratory_examination="Normal vesicular breath sounds, bilateral air entry equal, no added sounds.",
                    cardiovascular_examination="S1, S2 heard. Regular rate and rhythm, no murmurs.",
                    gastrointestinal_examination="Soft, non-tender, no organomegaly, normal bowel sounds.",
                    cns_examination="Grossly intact, cranial nerves normal, no neurological deficit.",
                    provisional_diagnosis="Acute Upper Respiratory Tract Infection (URTI) with Seasonal Rhinitis",
                    final_diagnosis="Acute Viral Rhinitis",
                    icd10_code="J00",
                    care_plan="Adequate hydration, warm saline gargle, rest, symptomatic antipyretic medication.",
                    dietary_advice="Light, nutritious, warm home-cooked meals. Plenty of fluids.",
                    status="FINALIZED",
                    version=1,
                    created_by_user_id=gen_med_doc.user_id,
                    updated_by_user_id=gen_med_doc.user_id,
                    signed_by_user_id=gen_med_doc.user_id,
                    signed_at=datetime.now(),
                )
                db.add(cr_srujana)
                db.flush()

            # Prescription
            pr_srujana = db.query(Prescription).filter(Prescription.visit_id == vis_srujana.id).first()
            if not pr_srujana:
                pr_srujana = Prescription(
                    id="pr-srujana-00001",
                    visit_id=vis_srujana.id,
                    patient_id=srujana_pat.id,
                    doctor_id=gen_med_doc.id,
                    status="SIGNED",
                    version=1,
                    notes="Standard OPD symptomatic care regimen",
                    signed_by_user_id=gen_med_doc.user_id,
                    signed_at=datetime.now(),
                    is_ocr_extracted=False,
                    is_verified_by_clinician=True,
                    allergy_warning_acknowledged=True,
                )
                db.add(pr_srujana)
                db.flush()

                meds_list = [
                    ("item-pr-srujana-1", pr_srujana.id, "Paracetamol", "Tablet", "650 mg", "Oral", "TDS (Thrice Daily)", 3, 9, "After Meals", "Take SOS if body temperature > 99°F"),
                    ("item-pr-srujana-2", pr_srujana.id, "Cetirizine", "Tablet", "10 mg", "Oral", "OD (Once Daily at Night)", 5, 5, "Bedtime", "For allergic rhinitis and nasal relief"),
                    ("item-pr-srujana-3", pr_srujana.id, "Pantoprazole", "Tablet", "40 mg", "Oral", "OD (Once Daily Morning)", 3, 3, "Before Breakfast", "Take on empty stomach for gastric protection"),
                ]
                for mid, pid, mname, mform, dos, route, freq, dur, qty, timing, inst in meds_list:
                    item = PrescriptionItem(
                        id=mid,
                        prescription_id=pid,
                        medicine_name=mname,
                        form=mform,
                        dosage=dos,
                        route=route,
                        frequency=freq,
                        duration_days=dur,
                        quantity=qty,
                        timing=timing,
                        instructions=inst,
                        is_dispensed=True,
                    )
                    db.add(item)
                db.flush()

        # Seed initial active staff sessions for live signin counters
        from datetime import timedelta
        admin_user = db.query(User).filter(User.email == "admin@smvmch.ac.in").first()
        doc_user = db.query(User).filter(User.email == "doctor@smvmch.ac.in").first()
        for u in [admin_user, doc_user]:
            if u:
                token_hash_val = f"seed-session-hash-{u.id}"
                existing_sess = db.query(RefreshTokenSession).filter(
                    (RefreshTokenSession.user_id == u.id) | (RefreshTokenSession.token_hash == token_hash_val)
                ).first()
                if not existing_sess:
                    sess = RefreshTokenSession(
                        user_id=u.id,
                        token_hash=token_hash_val,
                        expires_at=datetime.utcnow() + timedelta(days=7),
                        is_revoked=False,
                        ip_address="127.0.0.1",
                        user_agent="SMVMCH Hospital OPD Portal",
                        created_at=datetime.utcnow(),
                    )
                    db.add(sess)

        db.commit()
        print("Database initialized with SMVMCH master configuration, staff accounts, departments, formulary catalogue, canonical patients, and consultation records.")

    except Exception as e:
        db.rollback()
        print(f"Error seeding database: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()
