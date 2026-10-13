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

        # 4. Synthetic Demo Patients
        demo_patients_data = [
            ("UHID-2026-00001", "REG-2026-00001", "Johnathan Reynolds", "Thomas Reynolds", "S/o", date(1988, 4, 15), 38, 0, "MALE", "+15551234567", "O+", "Hypertension"),
            ("UHID-2026-00002", "REG-2026-00002", "Priya Sharma", "Rajesh Sharma", "W/o", date(1994, 9, 21), 32, 0, "FEMALE", "+15559876543", "B+", "Seasonal allergies"),
            ("UHID-2026-00003", "REG-2026-00003", "Robert Miller", "George Miller", "S/o", date(1965, 12, 3), 60, 0, "MALE", "+15554567890", "A+", "Type 2 Diabetes"),
        ]

        for uhid, reg, name, parent_spouse, relation, dob, age_y, age_m, gender, phone, bg, notes in demo_patients_data:
            pat = db.query(Patient).filter(Patient.uhid == uhid).first()
            if not pat:
                pat = Patient(
                    uhid=uhid,
                    hospital_reg_num=reg,
                    full_name=name,
                    parent_spouse_name=parent_spouse,
                    parent_spouse_relation=relation,
                    date_of_birth=dob,
                    age_years=age_y,
                    age_months=age_m,
                    gender=gender,
                    phone=phone,
                    blood_group=bg,
                    address="123 Hospital Ave, Metro Health District",
                    city="Metro City",
                    state="State Health Region",
                    postal_code="500001",
                    barcode_value=f"BAR-{uhid}",
                    qr_code_data=f"OPDCONNECT+{uhid}+{reg}",
                    emergency_contact_name="Family Contact",
                    emergency_contact_phone="+15559998888",
                    emergency_contact_relation="Spouse",
                )
                db.add(pat)
                db.flush()

                # Add a sample OPD Visit for first patient
                if uhid == "UHID-2026-00001":
                    visit = OPDVisit(
                        visit_number="VIS-20261012-0001",
                        patient_id=pat.id,
                        doctor_id=doctor.id,
                        department_id=departments["MED"].id,
                        queue_token=1,
                        triage_priority="NORMAL",
                        status="COMPLETED",
                        consultation_fee=500.0,
                        payment_status="PAID",
                    )
                    db.add(visit)
                    db.flush()

                    # Vitals
                    vitals = VitalSigns(
                        visit_id=visit.id,
                        systolic_bp=128,
                        diastolic_bp=82,
                        pulse_rate=76,
                        temperature_f=98.6,
                        spo2_percent=99.0,
                        respiratory_rate=16,
                        weight_kg=74.5,
                        height_cm=175.0,
                        bmi=24.3,
                        blood_glucose_mg_dl=110.0,
                    )
                    db.add(vitals)

                    # Clinical Record
                    clinic = ClinicalRecord(
                        visit_id=visit.id,
                        patient_id=pat.id,
                        doctor_id=doctor.id,
                        presenting_complaint="Throat pain and mild dry cough for 3 days",
                        history_of_present_illness="Patient reports scratchy throat starting Thursday. No high fever or dyspnea.",
                        allergies="No known drug allergies (NKDA)",
                        past_medical_history="Essential Hypertension on Telmisartan 40mg once daily",
                        prior_hospitalization="Appendectomy in 2018 at Metro General",
                        hypertension_history="Hypertensive for 4 years, controlled on monotherapy",
                        diabetes_history="No history of diabetes mellitus",
                        asthma_history="No history of asthma or reactive airway disease",
                        tuberculosis_history="No personal or contact history of tuberculosis",
                        smoking_history="Non-smoker",
                        alcohol_history="Social, 1-2 units on weekends",
                        family_history="Father: Hypertension, CAD at age 62. Mother: Alive and healthy.",
                        general_examination="Conscious, oriented, afebrile. No pallor, icterus, cyanosis, clubbing, lymphadenopathy, or pedal edema.",
                        respiratory_examination="Bilateral vesicular breath sounds, no rhonchi, wheezing, or crepitations.",
                        cardiovascular_examination="Normal S1 and S2 heard. No murmurs or gallops. Heart rate regular.",
                        gastrointestinal_examination="Abdomen soft, non-tender, no hepatosplenomegaly, normal bowel sounds present.",
                        cns_examination="Higher mental functions normal, cranial nerves II-XII grossly intact, no motor deficit.",
                        other_examination_findings="Oropharynx shows mild erythematous mucosal injection without purulent exudates.",
                        provisional_diagnosis="Acute Viral Pharyngitis",
                        final_diagnosis="Acute Viral Pharyngitis (J02.9)",
                        icd10_code="J02.9",
                        care_plan="Warm saline gargles 3x/day, adequate oral hydration, throat lozenges as needed. Review if high fever develops.",
                        investigations_requested="CBC, CRP (Optional if symptoms persist beyond 5 days)",
                        dietary_advice="Avoid cold drinks, acidic juices, and oily foods for 3 days.",
                        follow_up_date=date(2026, 10, 19),
                        status="FINALIZED",
                        version=1,
                        signed_by_user_id=doc_user.id,
                        signed_at=datetime.utcnow(),
                    )
                    db.add(clinic)

                    # Prescription
                    rx = Prescription(
                        visit_id=visit.id,
                        patient_id=pat.id,
                        doctor_id=doctor.id,
                        status="ACTIVE",
                        notes="Complete 5-day course",
                    )
                    db.add(rx)
                    db.flush()

                    rx_item1 = PrescriptionItem(
                        prescription_id=rx.id,
                        medicine_name="Paracetamol",
                        form="Tablet",
                        dosage="650 mg",
                        route="Oral",
                        frequency="TID",
                        duration_days=3,
                        timing="After Food",
                        instructions="Take only when throat discomfort or headache is present",
                    )
                    rx_item2 = PrescriptionItem(
                        prescription_id=rx.id,
                        medicine_name="Cetirizine",
                        form="Tablet",
                        dosage="10 mg",
                        route="Oral",
                        frequency="OD",
                        duration_days=5,
                        timing="Bedtime",
                        instructions="May cause mild drowsiness",
                    )
                    db.add(rx_item1)
                    db.add(rx_item2)

                # Add Waiting patient visit (UHID-2026-00002 Priya Sharma)
                elif uhid == "UHID-2026-00002":
                    visit2 = OPDVisit(
                        visit_number="VIS-20261012-0002",
                        patient_id=pat.id,
                        doctor_id=doctor.id,
                        department_id=departments["MED"].id,
                        queue_token=2,
                        triage_priority="NORMAL",
                        status="TRIAGED",
                        consultation_fee=500.0,
                        payment_status="PAID",
                        notes="Waiting in Queue",
                    )
                    db.add(visit2)
                    db.flush()

                    vitals2 = VitalSigns(
                        visit_id=visit2.id,
                        systolic_bp=118,
                        diastolic_bp=76,
                        pulse_rate=72,
                        temperature_f=98.4,
                        spo2_percent=99.0,
                        respiratory_rate=16,
                        weight_kg=58.0,
                        height_cm=162.0,
                        bmi=22.1,
                    )
                    db.add(vitals2)

                # Add In-Consultation patient visit (UHID-2026-00003 Robert Miller)
                elif uhid == "UHID-2026-00003":
                    from app.models.laboratory import LabOrder
                    visit3 = OPDVisit(
                        visit_number="VIS-20261012-0003",
                        patient_id=pat.id,
                        doctor_id=doctor.id,
                        department_id=departments["MED"].id,
                        queue_token=3,
                        triage_priority="PRIORITY",
                        status="IN_CONSULTATION",
                        consultation_fee=500.0,
                        payment_status="PAID",
                        notes="Under Consultation",
                    )
                    db.add(visit3)
                    db.flush()

                    vitals3 = VitalSigns(
                        visit_id=visit3.id,
                        systolic_bp=142,
                        diastolic_bp=90,
                        pulse_rate=82,
                        temperature_f=98.6,
                        spo2_percent=98.0,
                        respiratory_rate=18,
                        weight_kg=86.0,
                        height_cm=178.0,
                        bmi=27.1,
                        blood_glucose_mg_dl=185.0,
                    )
                    db.add(vitals3)

                    # Pending & Active Laboratory Investigations from OPD Booklet
                    lab_order = LabOrder(
                        visit_id=visit3.id,
                        patient_id=pat.id,
                        ordered_by_doctor_id=doctor.id,
                        order_number="LAB-20261012-0001",
                        specimen_id="SPEC-20261012-0001",
                        test_name="Glucose Fasting",
                        test_category="BIOCHEMISTRY",
                        specimen_type="Plasma (Fluoride / Grey Top)",
                        specimen_status="PENDING_COLLECTION",
                        clinical_indication="Type 2 Diabetes Mellitus glycemic follow-up",
                        status="ORDERED",
                    )
                    db.add(lab_order)

                    # Sample 2: Haematology Haemoglobin (Hb) Collected
                    lab_order2 = LabOrder(
                        visit_id=visit3.id,
                        patient_id=pat.id,
                        ordered_by_doctor_id=doctor.id,
                        order_number="LAB-20261012-0002",
                        specimen_id="SPEC-20261012-0002",
                        test_name="Haemoglobin (Hb)",
                        test_category="HAEMATOLOGY",
                        specimen_type="Whole Blood (EDTA / Lavender Top)",
                        specimen_status="COLLECTED",
                        collected_at=datetime.utcnow(),
                        collected_by_name="Marcus Vance",
                        clinical_indication="Routine anaemic screening",
                        status="COLLECTED",
                    )
                    db.add(lab_order2)

                    # Sample 3: Urine Routine - Processing with results entered
                    lab_order3 = LabOrder(
                        visit_id=visit3.id,
                        patient_id=pat.id,
                        ordered_by_doctor_id=doctor.id,
                        order_number="LAB-20261012-0003",
                        specimen_id="SPEC-20261012-0003",
                        test_name="Urine Routine",
                        test_category="HAEMATOLOGY",
                        specimen_type="Clean Catch Midstream Urine",
                        specimen_status="PROCESSING",
                        collected_at=datetime.utcnow(),
                        collected_by_name="Marcus Vance",
                        received_at=datetime.utcnow(),
                        received_by_name="Marcus Vance",
                        status="PROCESSING",
                        requires_review=True,
                    )
                    db.add(lab_order3)
                    db.flush()

                    from app.models.laboratory import LabResult
                    r1 = LabResult(
                        lab_order_id=lab_order3.id,
                        parameter_name="Albumin / Protein",
                        result_value="Nil",
                        flag="NORMAL",
                    )
                    r2 = LabResult(
                        lab_order_id=lab_order3.id,
                        parameter_name="Pus Cells (Microscopy)",
                        result_value="8-10 / HPF",
                        is_abnormal=True,
                        flag="ABNORMAL",
                        notes="Mild pyuria noted",
                    )
                    db.add_all([r1, r2])

                    # Sample 4: Completed Urea
                    lab_order4 = LabOrder(
                        visit_id=visit3.id,
                        patient_id=pat.id,
                        ordered_by_doctor_id=doctor.id,
                        order_number="LAB-20261012-0004",
                        specimen_id="SPEC-20261012-0004",
                        test_name="Urea",
                        test_category="BIOCHEMISTRY",
                        specimen_type="Serum (Clotted / Red Top)",
                        specimen_status="COMPLETED",
                        collected_at=datetime.utcnow(),
                        collected_by_name="Marcus Vance",
                        received_at=datetime.utcnow(),
                        received_by_name="Marcus Vance",
                        verified_by_user_id=lab_user.id,
                        verified_by_name="Marcus Vance",
                        verified_at=datetime.utcnow(),
                        status="COMPLETED",
                        completed_at=datetime.utcnow(),
                        published_to_visit=True,
                    )
                    db.add(lab_order4)
                    db.flush()
                    r4 = LabResult(
                        lab_order_id=lab_order4.id,
                        parameter_name="Blood Urea",
                        result_value="28",
                        unit="mg/dL",
                        flag="NORMAL",
                        verified_at=datetime.utcnow(),
                    )
                    db.add(r4)

                    # Sample 5: Sensitive HIV test
                    lab_order5 = LabOrder(
                        visit_id=visit3.id,
                        patient_id=pat.id,
                        ordered_by_doctor_id=doctor.id,
                        order_number="LAB-20261012-0005",
                        specimen_id="SPEC-20261012-0005",
                        test_name="HIV",
                        test_category="MICROBIOLOGY",
                        specimen_type="Serum (Red Top)",
                        specimen_status="PENDING_COLLECTION",
                        is_sensitive=True,
                        status="ORDERED",
                    )
                    db.add(lab_order5)

        # 5. Patient Users & Dependents
        p1 = db.query(Patient).filter(Patient.uhid == "UHID-2026-00001").first()
        if p1:
            pat_user = db.query(User).filter(User.email == "patient@opdconnect.com").first()
            if not pat_user:
                pat_user = User(
                    email="patient@opdconnect.com",
                    full_name=p1.full_name,
                    phone=p1.phone,
                    hashed_password=get_password_hash("Patient@123456"),
                    role_id=roles["patient"].id,
                    patient_id=p1.id,
                    is_active=True,
                    is_verified=True,
                )
                db.add(pat_user)
            else:
                pat_user.hashed_password = get_password_hash("Patient@123456")
                pat_user.patient_id = p1.id
                pat_user.role_id = roles["patient"].id
                pat_user.is_active = True
                db.flush()

            # Create dependent child for Johnathan
            dep = db.query(Patient).filter(Patient.uhid == "UHID-2026-00004").first()
            if not dep:
                dep = Patient(
                    uhid="UHID-2026-00004",
                    full_name="Tommy Reynolds",
                    date_of_birth=date(2020, 6, 10),
                    age_years=6,
                    gender="MALE",
                    phone=p1.phone,
                    blood_group="O+",
                    guardian_id=p1.id,
                    emergency_contact_name=p1.full_name,
                    emergency_contact_phone=p1.phone,
                    emergency_contact_relation="Father",
                )
                db.add(dep)
                db.flush()

        p2 = db.query(Patient).filter(Patient.uhid == "UHID-2026-00002").first()
        if p2:
            pat2_user = db.query(User).filter(User.email == "patient2@opdconnect.com").first()
            if not pat2_user:
                pat2_user = User(
                    email="patient2@opdconnect.com",
                    full_name=p2.full_name,
                    phone=p2.phone,
                    hashed_password=get_password_hash("Patient@123456"),
                    role_id=roles["patient"].id,
                    patient_id=p2.id,
                    is_active=True,
                    is_verified=True,
                )
                db.add(pat2_user)
            else:
                pat2_user.hashed_password = get_password_hash("Patient@123456")
                pat2_user.patient_id = p2.id
                pat2_user.role_id = roles["patient"].id
                pat2_user.is_active = True
                db.flush()

        # Seed Medicine Inventory (with clearly labeled synthetic prices in development)
        medicines_data = [
            {
                "medicine_code": "MED-PCM-650-01",
                "name": "Paracetamol",
                "generic_name": "Paracetamol",
                "strength": "650 mg",
                "dosage_form": "Tablet",
                "batch_number": "BAT-2026-001",
                "expiry_date": date(2027, 12, 31),
                "available_quantity": 250,
                "reorder_level": 30,
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
                "available_quantity": 180,
                "reorder_level": 25,
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
                "available_quantity": 150,
                "reorder_level": 20,
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
                "available_quantity": 200,
                "reorder_level": 25,
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
                "available_quantity": 300,
                "reorder_level": 40,
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
                "expiry_date": date(2026, 11, 15), # Expiring soon
                "available_quantity": 12, # Low stock alert (< 20)
                "reorder_level": 20,
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
                "available_quantity": 40,
                "reorder_level": 15,
                "unit_price": 120.00,
                "tax_classification": "GST_12",
            },
            {
                "medicine_code": "MED-TET-250-99",
                "name": "Tetracycline (Demo Expired Batch)",
                "generic_name": "Tetracycline Hydrochloride",
                "strength": "250 mg",
                "dosage_form": "Capsule",
                "batch_number": "BAT-2025-999",
                "expiry_date": date(2025, 1, 1), # Expired batch
                "available_quantity": 30,
                "reorder_level": 10,
                "unit_price": 5.00,
                "tax_classification": "GST_5",
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
                    is_synthetic_price=True,
                    tax_classification=m_data["tax_classification"],
                    supplier_name="National Medical Depots Ltd.",
                )
                db.add(med)
                db.flush()

                movement = StockMovement(
                    inventory_id=med.id,
                    movement_type="PURCHASE_RECEIPT",
                    quantity=med.available_quantity,
                    balance_after=med.available_quantity,
                    reference_number=f"INIT-{med.batch_number}",
                    reason="Initial stock baseline seed",
                )
                db.add(movement)

        db.commit()
        print("Database seeded successfully with initial synthetic OPD data.")
    except Exception as e:
        db.rollback()
        print(f"Error seeding database: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()
