import json
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, Body
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.responses import success_response
from app.core.dependencies import get_current_user, require_roles, verify_patient_access
from app.core.exceptions import NotFoundException, ForbiddenException, BadRequestException
from app.models.prescription import Prescription, PrescriptionItem, PrescriptionAmendment
from app.models.visit import OPDVisit
from app.models.clinical import ClinicalRecord
from app.models.patient import Patient
from app.schemas.prescription import (
    PrescriptionCreate,
    PrescriptionRead,
    PrescriptionAmendRequest,
    AllergyCheckRequest,
    AllergyCheckResponse,
    AllergyWarning,
    MedicineCatalogItem,
)
from app.core.medicines import MEDICINE_CATALOG, check_medication_allergies
from app.models.user import User

router = APIRouter()


def snapshot_prescription(rx: Prescription) -> str:
    """Capture non-repudiation JSON snapshot of prescription before amendment."""
    return json.dumps({
        "version": rx.version,
        "status": rx.status,
        "notes": rx.notes,
        "signed_by_user_id": rx.signed_by_user_id,
        "signed_at": rx.signed_at.isoformat() if rx.signed_at else None,
        "items": [
            {
                "medicine_name": it.medicine_name,
                "form": it.form,
                "dosage": it.dosage,
                "route": it.route,
                "frequency": it.frequency,
                "duration_days": it.duration_days,
                "quantity": it.quantity,
                "timing": it.timing,
                "instructions": it.instructions,
            }
            for it in rx.items
        ],
    })


def get_patient_allergies_text(db: Session, patient_id: str) -> str:
    """Extract allergy history from clinical records or patient notes."""
    recent_records = (
        db.query(ClinicalRecord)
        .filter(ClinicalRecord.patient_id == patient_id)
        .order_by(ClinicalRecord.created_at.desc())
        .all()
    )
    for cr in recent_records:
        if cr.allergies and cr.allergies.strip():
            return cr.allergies.strip()
    return ""


@router.get("/medicines", summary="Search Configured Medicine Catalog")
def search_medicines(
    q: Optional[str] = Query(None, description="Search term for medicine name or category")
):
    """Returns curated medicine catalog items matching query."""
    if not q or not q.strip():
        items = MEDICINE_CATALOG[:25]
    else:
        query_str = q.lower().strip()
        items = [
            m for m in MEDICINE_CATALOG
            if query_str in m["name"].lower() or query_str in m["category"].lower()
        ]
    return success_response(
        data=[MedicineCatalogItem.model_validate(m).model_dump() for m in items],
        message="Medicine catalog retrieved successfully"
    )


@router.post("/check-allergies", summary="Evaluate Medication Allergy Warnings")
def check_allergies_endpoint(
    req: AllergyCheckRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Checks prescribed medicines against reliable patient allergy history."""
    patient = db.query(Patient).filter(Patient.id == req.patient_id).first()
    if not patient:
        raise NotFoundException(f"Patient '{req.patient_id}' not found")

    allergies_text = get_patient_allergies_text(db, patient.id)
    warnings = check_medication_allergies(allergies_text, req.medicines)

    res = AllergyCheckResponse(
        has_warnings=len(warnings) > 0,
        warnings=[AllergyWarning.model_validate(w) for w in warnings]
    )
    return success_response(
        data=res.model_dump(),
        message="Medication allergy check completed"
    )


@router.post("", summary="Create Prescription (Doctor/Admin Only)")
def create_prescription(
    prescription_in: PrescriptionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["doctor", "admin"])),
):
    visit = db.query(OPDVisit).filter(OPDVisit.id == prescription_in.visit_id).first()
    if not visit:
        raise NotFoundException(f"Visit '{prescription_in.visit_id}' not found")

    target_status = (prescription_in.status or "SIGNED").upper()

    # Safety: OCR-extracted prescription cannot be signed without clinician verification
    is_ocr = prescription_in.is_ocr_extracted or False
    is_verified = prescription_in.is_verified_by_clinician
    if is_ocr and not is_verified:
        target_status = "DRAFT"

    # Safety: Allergy warnings check
    patient_allergies = get_patient_allergies_text(db, visit.patient_id)
    med_names = [it.medicine_name for it in prescription_in.items]
    allergy_warnings = check_medication_allergies(patient_allergies, med_names)

    if allergy_warnings and target_status == "SIGNED" and not prescription_in.allergy_warning_acknowledged:
        warning_msg = allergy_warnings[0]["warning_message"]
        raise BadRequestException(
            f"Allergy Safety Alert: {warning_msg} You must explicitly confirm acknowledgement before signing."
        )

    rx = Prescription(
        visit_id=visit.id,
        patient_id=visit.patient_id,
        doctor_id=visit.doctor_id,
        notes=prescription_in.notes,
        status=target_status,
        version=1,
        is_ocr_extracted=is_ocr,
        is_verified_by_clinician=is_verified if is_verified is not None else True,
        allergy_warning_acknowledged=prescription_in.allergy_warning_acknowledged or False,
        signed_by_user_id=current_user.id if target_status == "SIGNED" else None,
        signed_at=datetime.utcnow() if target_status == "SIGNED" else None,
    )
    db.add(rx)
    db.flush()

    for item_in in prescription_in.items:
        rx_item = PrescriptionItem(
            prescription_id=rx.id,
            medicine_name=item_in.medicine_name,
            form=item_in.form,
            dosage=item_in.dosage,
            route=item_in.route,
            frequency=item_in.frequency,
            duration_days=item_in.duration_days,
            quantity=item_in.quantity,
            timing=item_in.timing,
            instructions=item_in.instructions,
            is_dispensed=False,
        )
        db.add(rx_item)

    db.commit()
    db.refresh(rx)
    return success_response(
        data=PrescriptionRead.model_validate(rx).model_dump(),
        message="Prescription created successfully",
        status_code=201
    )


@router.post("/{prescription_id}/sign", summary="Sign and Finalize Draft Prescription (Doctor/Admin)")
def sign_prescription(
    prescription_id: str,
    allergy_warning_acknowledged: bool = Body(False, embed=True),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["doctor", "admin"])),
):
    rx = db.query(Prescription).filter(Prescription.id == prescription_id).first()
    if not rx:
        raise NotFoundException(f"Prescription '{prescription_id}' not found")

    if rx.status in ["CANCELLED"]:
        raise BadRequestException(f"Cannot sign cancelled prescription")

    # Safety: Allergy warnings check
    patient_allergies = get_patient_allergies_text(db, rx.patient_id)
    med_names = [it.medicine_name for it in rx.items]
    warnings = check_medication_allergies(patient_allergies, med_names)

    if warnings and not (allergy_warning_acknowledged or rx.allergy_warning_acknowledged):
        raise BadRequestException(
            f"Allergy Alert: {warnings[0]['warning_message']} Acknowledge to confirm signing."
        )

    rx.status = "SIGNED"
    rx.is_verified_by_clinician = True
    rx.allergy_warning_acknowledged = True if warnings else rx.allergy_warning_acknowledged
    rx.signed_by_user_id = current_user.id
    rx.signed_at = datetime.utcnow()

    db.commit()
    db.refresh(rx)
    return success_response(
        data=PrescriptionRead.model_validate(rx).model_dump(),
        message="Prescription signed and finalized successfully"
    )


@router.post("/{prescription_id}/amend", summary="Amend Signed Prescription with Audit Log (Doctor/Admin)")
def amend_prescription(
    prescription_id: str,
    amend_in: PrescriptionAmendRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["doctor", "admin"])),
):
    rx = db.query(Prescription).filter(Prescription.id == prescription_id).first()
    if not rx:
        raise NotFoundException(f"Prescription '{prescription_id}' not found")

    if rx.status == "CANCELLED":
        raise BadRequestException("Cannot amend a cancelled prescription")

    if not amend_in.amendment_reason or not amend_in.amendment_reason.strip():
        raise BadRequestException("A valid amendment reason is required to preserve clinical audit trail")

    # Snapshot current state before changes
    snapshot_json = snapshot_prescription(rx)
    amendment = PrescriptionAmendment(
        prescription_id=rx.id,
        amended_by_user_id=current_user.id,
        amended_at=datetime.utcnow(),
        reason=amend_in.amendment_reason.strip(),
        previous_snapshot_json=snapshot_json,
    )
    db.add(amendment)

    # Delete existing items and add new items
    for it in list(rx.items):
        db.delete(it)
    db.flush()

    for item_in in amend_in.items:
        rx_item = PrescriptionItem(
            prescription_id=rx.id,
            medicine_name=item_in.medicine_name,
            form=item_in.form,
            dosage=item_in.dosage,
            route=item_in.route,
            frequency=item_in.frequency,
            duration_days=item_in.duration_days,
            quantity=item_in.quantity,
            timing=item_in.timing,
            instructions=item_in.instructions,
            is_dispensed=False,
        )
        db.add(rx_item)

    rx.version += 1
    rx.status = "AMENDED"
    rx.amendment_reason = amend_in.amendment_reason.strip()
    if amend_in.notes:
        rx.notes = amend_in.notes

    db.commit()
    db.refresh(rx)
    return success_response(
        data=PrescriptionRead.model_validate(rx).model_dump(),
        message="Prescription amended successfully and audit trail preserved"
    )


@router.post("/{prescription_id}/cancel", summary="Cancel Prescription (Doctor/Admin)")
def cancel_prescription(
    prescription_id: str,
    reason: str = Body("Clinician cancelled prescription", embed=True),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["doctor", "admin"])),
):
    rx = db.query(Prescription).filter(Prescription.id == prescription_id).first()
    if not rx:
        raise NotFoundException(f"Prescription '{prescription_id}' not found")

    rx.status = "CANCELLED"
    rx.amendment_reason = reason
    db.commit()
    db.refresh(rx)
    return success_response(
        data=PrescriptionRead.model_validate(rx).model_dump(),
        message="Prescription cancelled"
    )


@router.get("/visit/{visit_id}", summary="Get Prescriptions for Visit")
def get_prescriptions_by_visit(
    visit_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    visit = db.query(OPDVisit).filter(OPDVisit.id == visit_id).first()
    if not visit:
        raise NotFoundException(f"Visit '{visit_id}' not found")

    user_role = (current_user.role.name if current_user.role else "").lower()

    if user_role in ["receptionist", "lab_tech", "laboratory"]:
        raise ForbiddenException("Access to clinical prescriptions is not permitted for this role")

    if user_role == "patient":
        verify_patient_access(patient_id=visit.patient_id, current_user=current_user, db=db)

    rxs = db.query(Prescription).filter(Prescription.visit_id == visit_id).all()
    return success_response(
        data=[PrescriptionRead.model_validate(rx).model_dump() for rx in rxs],
        message="Prescriptions retrieved successfully"
    )
