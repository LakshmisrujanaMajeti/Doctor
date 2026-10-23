"""
Seed initial synthetic data for OPD Connect+ development:
- Core Roles (admin, doctor, nurse, receptionist, lab_tech, pharmacist)
- Hospital Departments (General Medicine, Pediatrics, Orthopedics, Cardiology, ENT)
- Default Staff (Dr. Sarah Chen, Receptionist Alice)
- Initial Demo Patients and Visits
"""
from datetime import datetime, date
from sqlalchemy.orm import Session
from app.core.database import SessionLocal, engine, Base
from app.core.security import get_password_hash
import app.models  # Ensure all models are registered on Base.metadata
from app.models.user import Role, User, Permission, role_permissions
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
        rec_user = db.query(User).filter((User.email == "reception@smvmch.ac.in") | (User.email == "receptionist@smvmch.ac.in") | (User.phone == "+1555000003")).first()
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

        # SMVMCH Official Institutional Credentials
        institutional_staff = [
            ("admin@smvmch.ac.in", "Admin Administrator", "+1555000011", "Admin@123", "admin"),
            ("doctor@smvmch.ac.in", "Dr. Sarah Chen, MD", "+1555000012", "Doctor@123", "doctor"),
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
            ("receptionist@smvmch.ac.in", "Alice Adams (Reception Desk)", "+1555000013", "Reception@123", "receptionist"),
            ("reception@smvmch.ac.in", "Alice Adams (Reception Desk)", "+1555000014", "Reception@123", "receptionist"),
            ("lab@smvmch.ac.in", "Marcus Vance (Lab Tech)", "+1555000015", "Lab@123", "lab_tech"),
            ("pharmacy@smvmch.ac.in", "Elena Rostova (Pharmacist)", "+1555000016", "Pharmacy@123", "pharmacist"),
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
        db.commit()
        print("Database initialized with SMVMCH master configuration, staff accounts, departments, and formulary catalogue.")

    except Exception as e:
        db.rollback()
        print(f"Error seeding database: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()
