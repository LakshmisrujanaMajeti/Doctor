import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
import app.models  # Register all models for Base.metadata
from app.main import app

import sqlite3
from decimal import Decimal
sqlite3.register_adapter(Decimal, lambda d: str(d))

# In-memory SQLite for tests
TEST_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="session", autouse=True)
def setup_test_db():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="session", autouse=True)
def live_db_test_environment(setup_test_db):
    """Ensure test data exists for integration tests running against TestingSessionLocal and cleans up completely at teardown."""
    from datetime import date
    from decimal import Decimal
    from app.core.security import get_password_hash
    from app.models.user import User, Role
    from app.models.doctor import Doctor
    from app.models.department import Department
    from app.models.patient import Patient
    from app.models.visit import OPDVisit
    from app.models.pharmacy import MedicineInventory
    from app.models.clinical import ClinicalRecord
    from app.models.prescription import Prescription, PrescriptionItem
    from app.models.laboratory import LabOrder, LabResult
    from app.models.billing import Bill, BillItem, PaymentTransaction
    from app.models.document import MedicalDocument, DocumentPage, DocumentOCRExtraction

    db = TestingSessionLocal()
    try:
        all_roles = ["admin", "patient", "doctor", "nurse", "receptionist", "pharmacist", "laboratory", "lab_tech"]
        roles = {}
        for r_name in all_roles:
            r = db.query(Role).filter(Role.name == r_name).first()
            if not r:
                r = Role(name=r_name, description=r_name.capitalize())
                db.add(r)
                db.flush()
            roles[r_name] = r
        role_pat = roles["patient"]

        test_dept = db.query(Department).first()
        if not test_dept:
            test_dept = Department(name="General Medicine", code="MED", is_active=True)
            db.add(test_dept)
            db.flush()

        admin_user = db.query(User).filter(User.email == "admin@opdconnect.com").first()
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
            admin_user.hashed_password = get_password_hash("Admin@123456")
            admin_user.is_active = True
            db.flush()

        doc_user = db.query(User).filter(User.email == "dr.chen@opdconnect.com").first()
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
            doc_user.hashed_password = get_password_hash("Doctor@123456")
            doc_user.is_active = True
            db.flush()

        doc_profile = db.query(Doctor).filter(Doctor.user_id == doc_user.id).first()
        if not doc_profile:
            doc_profile = Doctor(
                user_id=doc_user.id,
                department_id=test_dept.id,
                qualification="MBBS, MD",
                specialization="Internal Medicine",
                registration_number="MED-12345",
                room_number="Room 101",
                consultation_fee=Decimal("500.00"),
                is_available=True,
            )
            db.add(doc_profile)
            db.flush()

        rec_user = db.query(User).filter(User.email == "receptionist@opdconnect.com").first()
        if not rec_user:
            rec_user = User(
                email="receptionist@opdconnect.com",
                full_name="Reception Staff",
                phone="+1555000003",
                hashed_password=get_password_hash("Reception@123456"),
                role_id=roles["receptionist"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(rec_user)
            db.flush()
        else:
            rec_user.hashed_password = get_password_hash("Reception@123456")
            rec_user.is_active = True
            db.flush()

        pharm_user = db.query(User).filter(User.email == "pharmacist@opdconnect.com").first()
        if not pharm_user:
            pharm_user = User(
                email="pharmacist@opdconnect.com",
                full_name="Pharmacist Staff",
                phone="+1555000005",
                hashed_password=get_password_hash("Pharmacy@123456"),
                role_id=roles["pharmacist"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(pharm_user)
            db.flush()
        else:
            pharm_user.hashed_password = get_password_hash("Pharmacy@123456")
            pharm_user.is_active = True
            db.flush()

        lab_user = db.query(User).filter(User.email == "lab@opdconnect.com").first()
        if not lab_user:
            lab_user = User(
                email="lab@opdconnect.com",
                full_name="Lab Technician",
                phone="+1555000004",
                hashed_password=get_password_hash("Lab@123456"),
                role_id=roles["lab_tech"].id,
                is_active=True,
                is_verified=True,
            )
            db.add(lab_user)
            db.flush()
        else:
            lab_user.hashed_password = get_password_hash("Lab@123456")
            lab_user.is_active = True
            db.flush()

        p1 = db.query(Patient).filter(Patient.uhid == "UHID-2026-00001").first()
        if not p1:
            p1 = Patient(
                uhid="UHID-2026-00001",
                full_name="Johnathan Reynolds",
                date_of_birth=date(1982, 3, 15),
                age_years=44,
                gender="MALE",
                phone="+1555000010",
                email="patient@opdconnect.com",
                blood_group="O+",
                address="452 Elm Street",
                city="Metropolis",
                state="NY",
                postal_code="10001",
            )
            db.add(p1)
            db.flush()

        p2 = db.query(Patient).filter(Patient.uhid == "UHID-2026-00002").first()
        if not p2:
            p2 = Patient(
                uhid="UHID-2026-00002",
                full_name="Jane Doe",
                date_of_birth=date(1990, 7, 22),
                age_years=35,
                gender="FEMALE",
                phone="+1555000011",
                email="jane.doe@opdconnect.com",
                blood_group="A+",
                address="742 Evergreen Terrace",
                city="Springfield",
                state="OR",
                postal_code="97477",
            )
            db.add(p2)
            db.flush()

        p3 = db.query(Patient).filter(Patient.uhid == "UHID-2026-00003").first()
        if not p3:
            p3 = Patient(
                uhid="UHID-2026-00003",
                full_name="Robert Smith",
                date_of_birth=date(1975, 11, 5),
                age_years=50,
                gender="MALE",
                phone="+1555000012",
                email="robert.smith@opdconnect.com",
                blood_group="B+",
                address="102 Lake View",
                city="Chicago",
                state="IL",
                postal_code="60601",
            )
            db.add(p3)
            db.flush()

        pat_user = db.query(User).filter(User.email == "patient@opdconnect.com").first()
        if not pat_user:
            pat_user = User(
                email="patient@opdconnect.com",
                full_name="Johnathan Reynolds",
                phone="+1555000010",
                hashed_password=get_password_hash("Patient@123456"),
                role_id=role_pat.id,
                patient_id=p1.id,
                is_active=True,
                is_verified=True,
            )
            db.add(pat_user)
            db.flush()
        else:
            pat_user.patient_id = p1.id
            pat_user.hashed_password = get_password_hash("Patient@123456")
            pat_user.is_active = True
            db.flush()

        exp_med = db.query(MedicineInventory).filter(MedicineInventory.batch_number == "BAT-2025-999").first()
        if not exp_med:
            exp_med = MedicineInventory(
                medicine_code="MED-TET-250-99",
                name="Tetracycline (Demo Expired Batch)",
                generic_name="Tetracycline Hydrochloride",
                strength="250 mg",
                dosage_form="Capsule",
                batch_number="BAT-2025-999",
                expiry_date=date(2025, 1, 1),
                available_quantity=30,
                reorder_level=10,
                unit_price=Decimal("5.00"),
                is_synthetic_price=True,
                tax_classification="GST_5",
                supplier_name="National Medical Depots Ltd.",
            )
            db.add(exp_med)
            db.flush()

        pcm = db.query(MedicineInventory).filter(MedicineInventory.batch_number == "BAT-2026-001").first()
        if pcm:
            pcm.is_synthetic_price = True

        azi = db.query(MedicineInventory).filter(MedicineInventory.batch_number == "BAT-2026-006").first()
        if azi:
            azi.available_quantity = 12
            azi.reorder_level = 20
            azi.is_synthetic_price = True

        doc = db.query(Doctor).first()
        dept = db.query(Department).first()
        if doc and dept:
            v1 = db.query(OPDVisit).filter(OPDVisit.visit_number == "VIS-TEST-AUTO-01").first()
            if not v1:
                v1 = OPDVisit(
                    visit_number="VIS-TEST-AUTO-01",
                    patient_id=p1.id,
                    doctor_id=doc.id,
                    department_id=dept.id,
                    queue_token=1,
                    triage_priority="NORMAL",
                    status="TRIAGED",
                )
                db.add(v1)
                db.flush()

            v2 = db.query(OPDVisit).filter(OPDVisit.visit_number == "VIS-TEST-AUTO-02").first()
            if not v2:
                v2 = OPDVisit(
                    visit_number="VIS-TEST-AUTO-02",
                    patient_id=p2.id,
                    doctor_id=doc.id,
                    department_id=dept.id,
                    queue_token=2,
                    triage_priority="NORMAL",
                    status="TRIAGED",
                )
                db.add(v2)
                db.flush()

        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()

    yield

    cleanup_db = TestingSessionLocal()
    try:
        cleanup_db.query(PaymentTransaction).delete()
        cleanup_db.query(BillItem).delete()
        cleanup_db.query(Bill).delete()
        cleanup_db.query(DocumentOCRExtraction).delete()
        cleanup_db.query(DocumentPage).delete()
        cleanup_db.query(MedicalDocument).delete()
        cleanup_db.query(LabResult).delete()
        cleanup_db.query(LabOrder).delete()
        cleanup_db.query(PrescriptionItem).delete()
        cleanup_db.query(Prescription).delete()
        cleanup_db.query(ClinicalRecord).delete()
        cleanup_db.query(User).filter(User.email.in_(["patient@opdconnect.com", "admin@opdconnect.com", "dr.chen@opdconnect.com", "receptionist@opdconnect.com"])).delete()
        cleanup_db.query(Patient).delete()
        cleanup_db.query(MedicineInventory).filter(MedicineInventory.batch_number == "BAT-2025-999").delete()
        pcm_clean = cleanup_db.query(MedicineInventory).filter(MedicineInventory.batch_number == "BAT-2026-001").first()
        if pcm_clean:
            pcm_clean.is_synthetic_price = False
        cleanup_db.commit()
    except Exception:
        cleanup_db.rollback()
    finally:
        cleanup_db.close()


@pytest.fixture
def db_session():
    connection = engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)

    yield session

    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
