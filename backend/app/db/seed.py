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
            ("hospital_name", "City Care Memorial Hospital", "HOSPITAL", "Official hospital name printed on OPD booklets and receipts"),
            ("hospital_code", "CCMH-OPD", "HOSPITAL", "Hospital code prefix for registrations"),
            ("opd_operating_hours", "08:00 AM - 08:00 PM (Mon-Sat), 09:00 AM - 01:00 PM (Sun)", "HOSPITAL", "Daily OPD operating hours"),
            ("hospital_gstin", "29AAAAA0000A1Z5", "BILLING", "Hospital GST identification number"),
            ("consultation_default_fee", "500.00", "BILLING", "Default general OPD consultation fee"),
            ("tax_rate_medicines", "5.0", "BILLING", "Standard tax percentage for essential medicines"),
            ("tax_rate_services", "0.0", "BILLING", "Standard tax percentage for clinical healthcare services (exempt)"),
            ("backup_schedule", "Daily at 02:00 AM UTC", "BACKUP", "Automated backup schedule"),
            ("backup_retention_days", "30", "BACKUP", "Snapshot retention period in days"),
            ("emergency_helpline", "+91 8000 112 911", "HOSPITAL", "24/7 Hospital emergency helpline"),
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
        admin_user = db.query(User).filter((User.email == "admin@opdconnect.com") | (User.phone == "+1555000001")).first()
        if not admin_user:
            admin_user = User(
                email="admin@opdconnect.com",
                full_name="Admin Administrator",
                phone="+1555000001",
                hashed_password=get_password_hash("Admin@123456"),
                role_id=roles["admin"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(admin_user)
            db.flush()
        else:
            admin_user.email = "admin@opdconnect.com"
            admin_user.hashed_password = get_password_hash("Admin@123456")
            admin_user.is_active = True
            db.flush()

        # Doctor User
        doc_user = db.query(User).filter((User.email == "dr.chen@opdconnect.com") | (User.phone == "+1555000002")).first()
        if not doc_user:
            doc_user = User(
                email="dr.chen@opdconnect.com",
                full_name="Dr. Sarah Chen, MD",
                phone="+1555000002",
                hashed_password=get_password_hash("Doctor@123456"),
                role_id=roles["doctor"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(doc_user)
            db.flush()
        else:
            doc_user.email = "dr.chen@opdconnect.com"
            doc_user.hashed_password = get_password_hash("Doctor@123456")
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
        rec_user = db.query(User).filter((User.email == "receptionist@opdconnect.com") | (User.phone == "+1555000003")).first()
        if not rec_user:
            rec_user = User(
                email="receptionist@opdconnect.com",
                full_name="Alice Adams",
                phone="+1555000003",
                hashed_password=get_password_hash("Reception@123456"),
                role_id=roles["receptionist"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(rec_user)
            db.flush()
        else:
            rec_user.email = "receptionist@opdconnect.com"
            rec_user.hashed_password = get_password_hash("Reception@123456")
            rec_user.is_active = True
            db.flush()

        # Laboratory Staff
        lab_user = db.query(User).filter((User.email == "lab@opdconnect.com") | (User.phone == "+1555000004")).first()
        if not lab_user:
            lab_user = User(
                email="lab@opdconnect.com",
                full_name="Marcus Vance (Lab Tech)",
                phone="+1555000004",
                hashed_password=get_password_hash("Lab@123456"),
                role_id=roles["lab_tech"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(lab_user)
            db.flush()
        else:
            lab_user.email = "lab@opdconnect.com"
            lab_user.hashed_password = get_password_hash("Lab@123456")
            lab_user.is_active = True
            db.flush()

        # Pharmacist
        pharm_user = db.query(User).filter((User.email == "pharmacist@opdconnect.com") | (User.phone == "+1555000005")).first()
        if not pharm_user:
            pharm_user = User(
                email="pharmacist@opdconnect.com",
                full_name="Elena Rostova (Pharmacist)",
                phone="+1555000005",
                hashed_password=get_password_hash("Pharmacy@123456"),
                role_id=roles["pharmacist"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(pharm_user)
            db.flush()
        else:
            pharm_user.email = "pharmacist@opdconnect.com"
            pharm_user.hashed_password = get_password_hash("Pharmacy@123456")
            pharm_user.is_active = True
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

        db.commit()
        print("Database cleanly initialized with core roles, configs, master catalogues, and admin credentials. Zero demo patient records.")

    except Exception as e:
        db.rollback()
        print(f"Error seeding database: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()
