import pytest
from pydantic import ValidationError
from datetime import date

from app.core.validators import (
    validate_person_name,
    validate_indian_phone,
    validate_pin_code,
    validate_email_address,
    validate_age_years,
    validate_date_of_birth,
    validate_address_text,
    validate_blood_pressure,
)
from app.schemas.patient import PatientCreate
from app.schemas.visit import VitalSignsCreate, OPDVisitCreate


def test_person_name_validation():
    # Valid names
    assert validate_person_name("Ravi Kumar", "Name") == "Ravi Kumar"
    assert validate_person_name("இரா. குமார்", "Name") == "இரா. குமார்"
    assert validate_person_name("Mary-Jane", "Name") == "Mary-Jane"
    assert validate_person_name("O'Connor", "Name") == "O'Connor"
    assert validate_person_name("M. K. Gandhi", "Name") == "M. K. Gandhi"
    assert validate_person_name("Dr. A. P. J. Abdul Kalam", "Name") == "Dr. A. P. J. Abdul Kalam"

    # Invalid names
    with pytest.raises(ValueError):
        validate_person_name("Ravi123", "Name")
    with pytest.raises(ValueError):
        validate_person_name("@@@", "Name")
    with pytest.raises(ValueError):
        validate_person_name("   ", "Name")
    with pytest.raises(ValueError):
        validate_person_name("", "Name", required=True)


def test_phone_validation():
    # Valid phones
    assert validate_indian_phone("9876543210", "Phone") == "9876543210"
    assert validate_indian_phone("+919876543210", "Phone") == "9876543210"
    assert validate_indian_phone("98765 43210", "Phone") == "9876543210"

    # Invalid phones
    with pytest.raises(ValueError):
        validate_indian_phone("1234567890", "Phone")  # Invalid starting digit
    with pytest.raises(ValueError):
        validate_indian_phone("987654321", "Phone")   # 9 digits
    with pytest.raises(ValueError):
        validate_indian_phone("987654321012", "Phone") # 12 digits
    with pytest.raises(ValueError):
        validate_indian_phone("98765ABCD0", "Phone")  # Contains letters


def test_pin_code_validation():
    # Valid PIN codes
    assert validate_pin_code("605107", "PIN Code") == "605107"
    assert validate_pin_code("600001", "PIN Code") == "600001"

    # Invalid PIN codes
    with pytest.raises(ValueError):
        validate_pin_code("012345", "PIN Code") # Starts with 0
    with pytest.raises(ValueError):
        validate_pin_code("60510", "PIN Code")  # 5 digits
    with pytest.raises(ValueError):
        validate_pin_code("6051078", "PIN Code")# 7 digits
    with pytest.raises(ValueError):
        validate_pin_code("60510A", "PIN Code") # Letters


def test_blood_pressure_validation():
    # Valid BP
    validate_blood_pressure(120, 80)
    validate_blood_pressure(140, 90)

    # Invalid BP (systolic <= diastolic)
    with pytest.raises(ValueError):
        validate_blood_pressure(80, 120)
    with pytest.raises(ValueError):
        validate_blood_pressure(100, 100)


def test_patient_create_schema_validation():
    # Valid patient payload
    payload = {
        "full_name": "இரா. குமார்",
        "gender": "MALE",
        "age_years": 32,
        "phone": "9876543210",
        "address": "45, Gandhi Street, Madagadipet",
        "postal_code": "605107",
    }
    patient = PatientCreate(**payload)
    assert patient.full_name == "இரா. குமார்"
    assert patient.postal_code == "605107"

    # Invalid patient payload (digits in name)
    with pytest.raises(ValidationError):
        PatientCreate(
            full_name="Ravi123",
            gender="MALE",
            age_years=32,
            phone="9876543210",
        )

    # Invalid patient payload (invalid phone)
    with pytest.raises(ValidationError):
        PatientCreate(
            full_name="Ravi Kumar",
            gender="MALE",
            age_years=32,
            phone="12345",
        )


def test_vital_signs_schema_validation():
    # Valid vitals
    vitals = VitalSignsCreate(
        visit_id="vis-123",
        systolic_bp=120,
        diastolic_bp=80,
        pulse_rate=72,
        temperature_f=98.6,
        spo2_percent=99.0,
        respiratory_rate=16,
        height_cm=172.0,
        weight_kg=68.5,
    )
    assert vitals.systolic_bp == 120

    # Inverted BP should raise ValidationError
    with pytest.raises(ValidationError):
        VitalSignsCreate(
            visit_id="vis-123",
            systolic_bp=80,
            diastolic_bp=120,
        )
