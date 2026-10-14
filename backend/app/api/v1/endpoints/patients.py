from typing import Optional, List
from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session
from sqlalchemy import or_
from app.core.database import get_db
from app.core.responses import success_response
from app.core.exceptions import NotFoundException
from app.core.dependencies import get_current_user, require_roles, verify_patient_access
from app.schemas.patient import (
    PatientCreate,
    PatientUpdate,
    PatientRead,
    DuplicateCheckRequest,
    DuplicateCheckResponse,
)
from app.services.patient_service import PatientService
from app.services.pdf_booklet_service import PDFBookletService
from app.models.patient import Patient
from app.models.user import User
from app.models.visit import OPDVisit
from app.models.billing import Bill
from app.models.prescription import Prescription

router = APIRouter()


@router.post("/check-duplicate", summary="Check Potential Duplicate Registrations")
def check_duplicate_patient(
    check_in: DuplicateCheckRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["receptionist", "doctor", "admin", "nurse", "billing", "lab_tech", "pharmacist"])),
):
    result = PatientService.check_duplicates(
        db=db,
        phone=check_in.phone,
        full_name=check_in.full_name,
        hospital_reg_num=check_in.hospital_reg_num,
    )
    return success_response(
        data=result.model_dump(),
        message=result.message,
    )


@router.get("", summary="List or Search Patients")
def list_patients(
    query: Optional[str] = Query(None, description="Search by Name, UHID, Hospital Reg No, Phone, or Barcode"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user_role = (current_user.role.name if current_user.role else "").lower()

    if user_role == "patient":
        # Patients may access only their own records and authorized linked dependents
        if not current_user.patient:
            return success_response(data=[], message="No linked patient profile")

        patient_records = [current_user.patient]
        dependents = db.query(Patient).filter(Patient.guardian_id == current_user.patient_id).all()
        if dependents:
            patient_records.extend(dependents)

        return success_response(
            data=[PatientRead.model_validate(p).model_dump() for p in patient_records],
            message="Authorized patient records retrieved",
        )

    # Hospital Staff (Doctor, Receptionist, Nurse, Lab, Pharmacist, Admin)
    patients = PatientService.list_patients(db=db, query=query, skip=skip, limit=limit)
    return success_response(
        data=[PatientRead.model_validate(p).model_dump() for p in patients],
        message="Patients retrieved successfully",
    )


@router.post("", summary="Register New Patient (Staff: Receptionist/Doctor/Admin)")
def create_patient(
    patient_in: PatientCreate,
    allow_duplicate: bool = Query(False, description="Override warning if legitimate duplicate phone/name"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["receptionist", "doctor", "admin", "nurse", "billing", "lab_tech", "pharmacist"])),
):
    patient = PatientService.create_patient(
        db=db,
        patient_in=patient_in,
        current_user_id=current_user.id,
        prevent_duplicates=not allow_duplicate,
    )
    return success_response(
        data=PatientRead.model_validate(patient).model_dump(),
        message="Patient registered successfully",
        status_code=201,
    )


@router.get("/{patient_id}", summary="Get Patient by ID")
def get_patient(
    patient_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_patient_access(patient_id=patient_id, current_user=current_user, db=db)
    patient = PatientService.get_patient_by_id(db, patient_id)
    return success_response(
        data=PatientRead.model_validate(patient).model_dump(),
        message="Patient details retrieved",
    )


@router.get("/uhid/{uhid}", summary="Get Patient by UHID")
def get_patient_by_uhid(
    uhid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    patient = PatientService.get_patient_by_uhid(db, uhid)
    verify_patient_access(patient_id=patient.id, current_user=current_user, db=db)
    return success_response(
        data=PatientRead.model_validate(patient).model_dump(),
        message="Patient retrieved by UHID",
    )


@router.get("/reg/{reg_num}", summary="Get Patient by Hospital Registration Number")
def get_patient_by_reg_num(
    reg_num: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    patient = PatientService.get_patient_by_reg_num(db, reg_num)
    verify_patient_access(patient_id=patient.id, current_user=current_user, db=db)
    return success_response(
        data=PatientRead.model_validate(patient).model_dump(),
        message="Patient retrieved by Registration Number",
    )


@router.get("/barcode/{barcode}", summary="Get Patient by Barcode/QR Code")
def get_patient_by_barcode(
    barcode: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    patient = PatientService.get_patient_by_barcode(db, barcode)
    verify_patient_access(patient_id=patient.id, current_user=current_user, db=db)
    return success_response(
        data=PatientRead.model_validate(patient).model_dump(),
        message="Patient retrieved by Barcode/QR",
    )


@router.put("/{patient_id}", summary="Update Patient Demographics")
def update_patient(
    patient_id: str,
    update_in: PatientUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user_role = (current_user.role.name if current_user.role else "").lower()
    if user_role == "patient":
        verify_patient_access(patient_id=patient_id, current_user=current_user, db=db)
    elif user_role not in ["receptionist", "admin"]:
        require_roles(["receptionist", "admin"])(current_user)

    patient = PatientService.update_patient(db, patient_id, update_in, current_user_id=current_user.id)
    return success_response(
        data=PatientRead.model_validate(patient).model_dump(),
        message="Patient updated successfully",
    )


@router.delete("/{patient_id}", summary="Delete Patient Record (Admin or Receptionist)")
def delete_patient_record(
    patient_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["receptionist", "admin"])),
):
    PatientService.delete_patient(db, patient_id, current_user_id=current_user.id)
    return success_response(
        data={"deleted": True, "id": patient_id},
        message="Patient record deleted successfully",
    )


@router.get("/download-by-reg/{reg_id}", summary="Download Digital OPD Booklet by Registration ID")
def download_patient_booklet_by_reg_id(
    reg_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    clean_id = reg_id.strip()
    patient = db.query(Patient).filter(
        or_(
            Patient.id == clean_id,
            Patient.uhid == clean_id,
            Patient.hospital_reg_num == clean_id,
            Patient.phone == clean_id,
            Patient.barcode_value == clean_id,
        )
    ).first()
    if not patient:
        raise NotFoundException(f"Patient with Registration ID '{reg_id}' not found")

    verify_patient_access(patient_id=patient.id, current_user=current_user, db=db)

    # Fetch latest clinical visit, bills, prescriptions
    latest_visit = db.query(OPDVisit).filter(OPDVisit.patient_id == patient.id).order_by(OPDVisit.created_at.desc()).first()
    bills = db.query(Bill).filter(Bill.patient_id == patient.id).all()
    prescriptions = db.query(Prescription).filter(Prescription.patient_id == patient.id).all()

    pdf_bytes = PDFBookletService.generate_patient_booklet(
        patient=patient,
        visit=latest_visit,
        bills=bills,
        prescriptions=prescriptions,
    )

    filename = f"SMVMCH_OPD_Booklet_{patient.uhid or patient.hospital_reg_num or clean_id}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Access-Control-Expose-Headers": "Content-Disposition",
        },
    )


@router.get("/{patient_id}/download-booklet", summary="Download Digital OPD Booklet by Patient ID")
def download_patient_booklet(
    patient_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return download_patient_booklet_by_reg_id(reg_id=patient_id, db=db, current_user=current_user)


