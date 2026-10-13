import json
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.responses import success_response
from app.core.dependencies import get_current_user, require_roles, verify_patient_access
from app.core.exceptions import NotFoundException, ForbiddenException, ConflictException, BadRequestException
from app.models.clinical import ClinicalRecord, ClinicalAmendment
from app.models.visit import OPDVisit
from app.models.audit import AuditLog
from app.schemas.clinical import (
    ClinicalRecordCreate,
    ClinicalRecordUpdate,
    ClinicalRecordRead,
    ClinicalRecordAmendRequest,
    ClinicalAmendmentRead,
)
from app.models.user import User

router = APIRouter()


def snapshot_clinical_record(record: ClinicalRecord) -> str:
    """Serialize the clinical record to a non-repudiation JSON snapshot."""
    return json.dumps({
        "version": record.version,
        "status": record.status,
        "presenting_complaint": record.presenting_complaint,
        "history_of_present_illness": record.history_of_present_illness,
        "allergies": record.allergies,
        "past_medical_history": record.past_medical_history,
        "prior_hospitalization": record.prior_hospitalization,
        "hypertension_history": record.hypertension_history,
        "diabetes_history": record.diabetes_history,
        "asthma_history": record.asthma_history,
        "tuberculosis_history": record.tuberculosis_history,
        "smoking_history": record.smoking_history,
        "alcohol_history": record.alcohol_history,
        "family_history": record.family_history,
        "general_examination": record.general_examination,
        "respiratory_examination": record.respiratory_examination,
        "cardiovascular_examination": record.cardiovascular_examination,
        "gastrointestinal_examination": record.gastrointestinal_examination,
        "cns_examination": record.cns_examination,
        "other_examination_findings": record.other_examination_findings,
        "provisional_diagnosis": record.provisional_diagnosis,
        "final_diagnosis": record.final_diagnosis,
        "icd10_code": record.icd10_code,
        "care_plan": record.care_plan,
        "investigations_requested": record.investigations_requested,
        "dietary_advice": record.dietary_advice,
        "follow_up_date": str(record.follow_up_date) if record.follow_up_date else None,
        "referral_department": record.referral_department,
        "signed_by_user_id": record.signed_by_user_id,
        "signed_at": record.signed_at.isoformat() if record.signed_at else None,
    })


@router.post("", summary="Create or Save Draft of OPD Clinical Consultation Sheet (Doctor/Admin)")
def create_clinical_record(
    record_in: ClinicalRecordCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["doctor", "admin"])),
):
    visit = db.query(OPDVisit).filter(OPDVisit.id == record_in.visit_id).first()
    if not visit:
        raise NotFoundException(f"Visit '{record_in.visit_id}' not found")

    existing = db.query(ClinicalRecord).filter(ClinicalRecord.visit_id == record_in.visit_id).first()
    target_status = (record_in.status or "DRAFT").upper()

    if existing:
        if existing.status in ["FINALIZED", "AMENDED"]:
            raise ConflictException(
                "This clinical record has already been finalized/signed and cannot be overwritten. "
                "Use the amendment endpoint POST /api/v1/clinical-records/{id}/amend to record auditable corrections."
            )

        # Update draft
        for field, value in record_in.model_dump(exclude_unset=True).items():
            if field not in ["visit_id", "status"] and hasattr(existing, field):
                setattr(existing, field, value)

        existing.status = target_status
        existing.updated_by_user_id = current_user.id
        if target_status == "FINALIZED":
            existing.signed_by_user_id = current_user.id
            existing.signed_at = datetime.utcnow()
            visit.status = "COMPLETED"

        db.commit()
        db.refresh(existing)
        record = existing
    else:
        complaint = record_in.presenting_complaint or record_in.chief_complaint or "Routine consultation"
        record = ClinicalRecord(
            visit_id=visit.id,
            patient_id=visit.patient_id,
            doctor_id=visit.doctor_id,
            presenting_complaint=complaint,
            history_of_present_illness=record_in.history_of_present_illness,
            allergies=record_in.allergies,
            past_medical_history=record_in.past_medical_history or record_in.past_history,
            prior_hospitalization=record_in.prior_hospitalization,
            hypertension_history=record_in.hypertension_history,
            diabetes_history=record_in.diabetes_history,
            asthma_history=record_in.asthma_history,
            tuberculosis_history=record_in.tuberculosis_history,
            smoking_history=record_in.smoking_history,
            alcohol_history=record_in.alcohol_history,
            family_history=record_in.family_history,
            general_examination=record_in.general_examination,
            respiratory_examination=record_in.respiratory_examination,
            cardiovascular_examination=record_in.cardiovascular_examination,
            gastrointestinal_examination=record_in.gastrointestinal_examination,
            cns_examination=record_in.cns_examination,
            other_examination_findings=record_in.other_examination_findings or record_in.physical_examination,
            provisional_diagnosis=record_in.provisional_diagnosis,
            final_diagnosis=record_in.final_diagnosis,
            icd10_code=record_in.icd10_code,
            care_plan=record_in.care_plan or record_in.clinical_notes,
            investigations_requested=record_in.investigations_requested,
            dietary_advice=record_in.dietary_advice,
            follow_up_date=record_in.follow_up_date,
            referral_department=record_in.referral_department,
            status=target_status,
            version=1,
            created_by_user_id=current_user.id,
            updated_by_user_id=current_user.id,
            signed_by_user_id=current_user.id if target_status == "FINALIZED" else None,
            signed_at=datetime.utcnow() if target_status == "FINALIZED" else None,
        )
        db.add(record)
        if target_status == "FINALIZED":
            visit.status = "COMPLETED"
        db.commit()
        db.refresh(record)

    # Audit
    db.add(
        AuditLog(
            user_id=current_user.id,
            action="SAVE_CLINICAL_RECORD",
            entity_type="ClinicalRecord",
            entity_id=record.id,
            details_json=f'{{"status": "{record.status}", "visit_id": "{record.visit_id}", "version": {record.version}}}',
        )
    )
    db.commit()

    return success_response(
        data=ClinicalRecordRead.model_validate(record).model_dump(),
        message=f"Clinical record {'draft saved' if record.status == 'DRAFT' else 'finalized and signed'}",
        status_code=201,
    )


@router.post("/{record_id}/sign", summary="Sign and Finalize Clinical Record")
def sign_clinical_record(
    record_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["doctor", "admin"])),
):
    record = db.query(ClinicalRecord).filter(ClinicalRecord.id == record_id).first()
    if not record:
        raise NotFoundException(f"Clinical record '{record_id}' not found")

    if record.status in ["FINALIZED", "AMENDED"]:
        return success_response(
            data=ClinicalRecordRead.model_validate(record).model_dump(),
            message="Record is already signed and finalized",
        )

    record.status = "FINALIZED"
    record.signed_by_user_id = current_user.id
    record.signed_at = datetime.utcnow()
    record.updated_by_user_id = current_user.id

    visit = db.query(OPDVisit).filter(OPDVisit.id == record.visit_id).first()
    if visit:
        visit.status = "COMPLETED"

    db.add(
        AuditLog(
            user_id=current_user.id,
            action="SIGN_CLINICAL_RECORD",
            entity_type="ClinicalRecord",
            entity_id=record.id,
            details_json=f'{{"version": {record.version}, "signed_at": "{record.signed_at.isoformat()}"}}',
        )
    )
    db.commit()
    db.refresh(record)

    return success_response(
        data=ClinicalRecordRead.model_validate(record).model_dump(),
        message="Clinical record successfully signed and finalized",
    )


@router.post("/{record_id}/amend", summary="Amend Finalized Clinical Record (Creates Audit Snapshot)")
def amend_clinical_record(
    record_id: str,
    amend_in: ClinicalRecordAmendRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["doctor", "admin"])),
):
    record = db.query(ClinicalRecord).filter(ClinicalRecord.id == record_id).first()
    if not record:
        raise NotFoundException(f"Clinical record '{record_id}' not found")

    if not amend_in.amendment_reason or not amend_in.amendment_reason.strip():
        raise BadRequestException("A valid clinical amendment reason is strictly required")

    # 1. Take snapshot of current state
    snapshot_json = snapshot_clinical_record(record)

    # 2. Store non-repudiation amendment entry
    amendment = ClinicalAmendment(
        clinical_record_id=record.id,
        amended_by_user_id=current_user.id,
        amended_at=datetime.utcnow(),
        reason=amend_in.amendment_reason.strip(),
        previous_snapshot_json=snapshot_json,
    )
    db.add(amendment)

    # 3. Update record with new values
    update_data = amend_in.model_dump(exclude_unset=True)
    update_data.pop("amendment_reason", None)
    for key, value in update_data.items():
        if hasattr(record, key) and value is not None:
            setattr(record, key, value)

    record.status = "AMENDED"
    record.version += 1
    record.updated_by_user_id = current_user.id
    record.amendment_reason = amend_in.amendment_reason.strip()

    db.add(
        AuditLog(
            user_id=current_user.id,
            action="AMEND_CLINICAL_RECORD",
            entity_type="ClinicalRecord",
            entity_id=record.id,
            details_json=f'{{"version": {record.version}, "reason": "{record.amendment_reason}"}}',
        )
    )
    db.commit()
    db.refresh(record)

    return success_response(
        data=ClinicalRecordRead.model_validate(record).model_dump(),
        message=f"Clinical record amended to version {record.version} with audit snapshot saved",
    )


@router.get("/{record_id}/amendments", summary="Get Audit Amendment History for Clinical Record")
def get_clinical_amendments(
    record_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    record = db.query(ClinicalRecord).filter(ClinicalRecord.id == record_id).first()
    if not record:
        raise NotFoundException(f"Clinical record '{record_id}' not found")

    user_role = (current_user.role.name if current_user.role else "").lower()
    if user_role == "patient":
        verify_patient_access(patient_id=record.patient_id, current_user=current_user, db=db)
    elif user_role in ["receptionist", "lab_tech", "laboratory", "pharmacist"]:
        raise ForbiddenException("Access to clinical amendment audit history is restricted")

    amendments = db.query(ClinicalAmendment).filter(
        ClinicalAmendment.clinical_record_id == record_id
    ).order_by(ClinicalAmendment.amended_at.desc()).all()

    return success_response(
        data=[ClinicalAmendmentRead.model_validate(a).model_dump() for a in amendments],
        message="Clinical amendments retrieved",
    )


@router.get("/{record_id}", summary="Get Clinical Record by ID")
def get_clinical_record(
    record_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    record = db.query(ClinicalRecord).filter(ClinicalRecord.id == record_id).first()
    if not record:
        raise NotFoundException(f"Clinical record '{record_id}' not found")

    user_role = (current_user.role.name if current_user.role else "").lower()
    if user_role in ["receptionist", "lab_tech", "laboratory", "pharmacist"]:
        raise ForbiddenException("Access to full clinical examination sheet is restricted for this role")

    if user_role == "patient":
        verify_patient_access(patient_id=record.patient_id, current_user=current_user, db=db)

    return success_response(
        data=ClinicalRecordRead.model_validate(record).model_dump(),
        message="Clinical record retrieved",
    )


@router.get("/visit/{visit_id}", summary="Get Clinical Record for Visit")
def get_clinical_record_by_visit(
    visit_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    visit = db.query(OPDVisit).filter(OPDVisit.id == visit_id).first()
    if not visit:
        raise NotFoundException(f"Visit '{visit_id}' not found")

    user_role = (current_user.role.name if current_user.role else "").lower()

    if user_role in ["receptionist", "lab_tech", "laboratory", "pharmacist"]:
        raise ForbiddenException("Access to full clinical examination sheet is restricted for this role")

    if user_role == "patient":
        verify_patient_access(patient_id=visit.patient_id, current_user=current_user, db=db)

    record = db.query(ClinicalRecord).filter(ClinicalRecord.visit_id == visit_id).first()
    if not record:
        raise NotFoundException(f"Clinical record for visit '{visit_id}' not found")

    return success_response(
        data=ClinicalRecordRead.model_validate(record).model_dump(),
        message="Clinical record retrieved",
    )
