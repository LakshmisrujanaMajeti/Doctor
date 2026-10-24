from datetime import datetime, date
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func

from app.models.laboratory import LabOrder, LabResult
from app.models.visit import OPDVisit
from app.models.patient import Patient
from app.models.doctor import Doctor
from app.models.user import User
from app.core.exceptions import NotFoundException, ForbiddenException, BadRequestException

# Complete Laboratory Catalogue Strictly Based on the OPD Booklet
LABORATORY_CATALOGUE: List[Dict[str, Any]] = [
    # --- Biochemistry ---
    {
        "test_name": "Glucose Fasting",
        "category": "BIOCHEMISTRY",
        "specimen_type": "Plasma (Fluoride / Grey Top)",
        "tube_color": "#808080",
        "is_sensitive": False,
        "parameters": ["Fasting Blood Glucose"],
        "default_unit": "mg/dL",
    },
    {
        "test_name": "Glucose PP",
        "category": "BIOCHEMISTRY",
        "specimen_type": "Plasma (Fluoride / Grey Top)",
        "tube_color": "#808080",
        "is_sensitive": False,
        "parameters": ["Post Prandial Blood Glucose"],
        "default_unit": "mg/dL",
    },
    {
        "test_name": "Glucose Random",
        "category": "BIOCHEMISTRY",
        "specimen_type": "Plasma (Fluoride / Grey Top)",
        "tube_color": "#808080",
        "is_sensitive": False,
        "parameters": ["Random Blood Glucose"],
        "default_unit": "mg/dL",
    },
    {
        "test_name": "Urea",
        "category": "BIOCHEMISTRY",
        "specimen_type": "Serum (Clotted / Red Top)",
        "tube_color": "#DC2626",
        "is_sensitive": False,
        "parameters": ["Blood Urea"],
        "default_unit": "mg/dL",
    },
    {
        "test_name": "Creatinine",
        "category": "BIOCHEMISTRY",
        "specimen_type": "Serum (Clotted / Red Top)",
        "tube_color": "#DC2626",
        "is_sensitive": False,
        "parameters": ["Serum Creatinine"],
        "default_unit": "mg/dL",
    },
    {
        "test_name": "Cholesterol",
        "category": "BIOCHEMISTRY",
        "specimen_type": "Serum (Clotted / Red Top)",
        "tube_color": "#DC2626",
        "is_sensitive": False,
        "parameters": ["Total Cholesterol"],
        "default_unit": "mg/dL",
    },
    {
        "test_name": "Triglycerides",
        "category": "BIOCHEMISTRY",
        "specimen_type": "Serum (Clotted / Red Top)",
        "tube_color": "#DC2626",
        "is_sensitive": False,
        "parameters": ["Serum Triglycerides"],
        "default_unit": "mg/dL",
    },
    {
        "test_name": "Glucose Tolerance Test (routine)",
        "category": "BIOCHEMISTRY",
        "specimen_type": "Plasma (Fluoride / Serial Samples)",
        "tube_color": "#808080",
        "is_sensitive": False,
        "parameters": ["Fasting Blood Glucose", "1 Hour Blood Glucose", "2 Hour Blood Glucose"],
        "default_unit": "mg/dL",
    },
    {
        "test_name": "Glucose Tolerance Test (pregnancy)",
        "category": "BIOCHEMISTRY",
        "specimen_type": "Plasma (Fluoride / Serial Samples)",
        "tube_color": "#808080",
        "is_sensitive": False,
        "parameters": ["Fasting Blood Glucose", "1 Hour Blood Glucose", "2 Hour Blood Glucose", "3 Hour Blood Glucose"],
        "default_unit": "mg/dL",
    },
    {
        "test_name": "Glucose Challenge Test (GCT)",
        "category": "BIOCHEMISTRY",
        "specimen_type": "Plasma (Fluoride / Grey Top)",
        "tube_color": "#808080",
        "is_sensitive": False,
        "parameters": ["1 Hour Blood Glucose post 50g Glucose Load"],
        "default_unit": "mg/dL",
    },

    # --- Haematology ---
    {
        "test_name": "Haemoglobin (Hb)",
        "category": "HAEMATOLOGY",
        "specimen_type": "Whole Blood (EDTA / Lavender Top)",
        "tube_color": "#8B5CF6",
        "is_sensitive": False,
        "parameters": ["Haemoglobin"],
        "default_unit": "g/dL",
    },
    {
        "test_name": "Haematocrit (PCV)",
        "category": "HAEMATOLOGY",
        "specimen_type": "Whole Blood (EDTA / Lavender Top)",
        "tube_color": "#8B5CF6",
        "is_sensitive": False,
        "parameters": ["Packed Cell Volume (PCV)"],
        "default_unit": "%",
    },
    {
        "test_name": "RBC Count",
        "category": "HAEMATOLOGY",
        "specimen_type": "Whole Blood (EDTA / Lavender Top)",
        "tube_color": "#8B5CF6",
        "is_sensitive": False,
        "parameters": ["Total RBC Count"],
        "default_unit": "million/mcL",
    },
    {
        "test_name": "Total Leucocyte Count (TC)",
        "category": "HAEMATOLOGY",
        "specimen_type": "Whole Blood (EDTA / Lavender Top)",
        "tube_color": "#8B5CF6",
        "is_sensitive": False,
        "parameters": ["Total Leucocyte Count (TLC)"],
        "default_unit": "cells/mcL",
    },
    {
        "test_name": "Differential Count (DC)",
        "category": "HAEMATOLOGY",
        "specimen_type": "Whole Blood (EDTA / Lavender Top)",
        "tube_color": "#8B5CF6",
        "is_sensitive": False,
        "parameters": ["Polymorphs / Neutrophils", "Lymphocytes", "Eosinophils", "Monocytes", "Basophils"],
        "default_unit": "%",
    },
    {
        "test_name": "Platelet Count",
        "category": "HAEMATOLOGY",
        "specimen_type": "Whole Blood (EDTA / Lavender Top)",
        "tube_color": "#8B5CF6",
        "is_sensitive": False,
        "parameters": ["Platelet Count"],
        "default_unit": "lakhs/mcL",
    },
    {
        "test_name": "ESR",
        "category": "HAEMATOLOGY",
        "specimen_type": "Citrated Blood (Black Top) / EDTA",
        "tube_color": "#1F2937",
        "is_sensitive": False,
        "parameters": ["Erythrocyte Sedimentation Rate (Westergren)"],
        "default_unit": "mm/1st hr",
    },
    {
        "test_name": "Bleeding Time (BT)",
        "category": "HAEMATOLOGY",
        "specimen_type": "Capillary Blood (Duke method)",
        "tube_color": "#EF4444",
        "is_sensitive": False,
        "parameters": ["Bleeding Time"],
        "default_unit": "minutes",
    },
    {
        "test_name": "Clotting Time (CT)",
        "category": "HAEMATOLOGY",
        "specimen_type": "Venous Blood (Lee-White method)",
        "tube_color": "#EF4444",
        "is_sensitive": False,
        "parameters": ["Clotting Time"],
        "default_unit": "minutes",
    },
    {
        "test_name": "Urine Routine",
        "category": "HAEMATOLOGY",
        "specimen_type": "Clean Catch Midstream Urine",
        "tube_color": "#F59E0B",
        "is_sensitive": False,
        "parameters": [
            "Colour",
            "Appearance",
            "Reaction / pH",
            "Specific Gravity",
            "Albumin / Protein",
            "Sugar / Glucose",
            "Bile Salts",
            "Bile Pigments",
            "Pus Cells (Microscopy)",
            "Epithelial Cells (Microscopy)",
            "RBCs (Microscopy)",
            "Casts",
            "Crystals"
        ],
        "default_unit": "",
    },

    # --- Microbiology ---
    {
        "test_name": "Sputum AFB",
        "category": "MICROBIOLOGY",
        "specimen_type": "Early Morning Sputum (Sterile Container)",
        "tube_color": "#10B981",
        "is_sensitive": False,
        "parameters": ["Acid Fast Bacilli (Ziehl-Neelsen Stain)"],
        "default_unit": "",
    },
    {
        "test_name": "Stool Ova/Cyst",
        "category": "MICROBIOLOGY",
        "specimen_type": "Fresh Stool (Sterile Container)",
        "tube_color": "#D97706",
        "is_sensitive": False,
        "parameters": [
            "Colour",
            "Consistency",
            "Mucus",
            "Blood",
            "Protozoal Cysts (Microscopy)",
            "Helminthic Ova (Microscopy)",
            "Pus Cells"
        ],
        "default_unit": "",
    },
    {
        "test_name": "HIV",
        "category": "MICROBIOLOGY",
        "specimen_type": "Serum (Red Top)",
        "tube_color": "#DC2626",
        "is_sensitive": True,  # High privacy / strictly authorized
        "parameters": ["HIV-1 / HIV-2 Antibodies Screening"],
        "default_unit": "",
    },
    {
        "test_name": "VDRL",
        "category": "MICROBIOLOGY",
        "specimen_type": "Serum (Red Top)",
        "tube_color": "#DC2626",
        "is_sensitive": True,  # High privacy / strictly authorized
        "parameters": ["VDRL / RPR Flocculation Screening"],
        "default_unit": "Titre",
    },

    # --- Radiology & Diagnostic Scans ---
    {
        "test_name": "Brain MRI Scan with Contrast",
        "category": "RADIOLOGY",
        "specimen_type": "Diagnostic Imaging (1.5T MRI Scanner)",
        "tube_color": "#4338CA",
        "is_sensitive": False,
        "parameters": ["T1-Weighted Sequence", "T2-Weighted Sequence", "FLAIR Sequence", "DWI Sequence", "Contrast Enhancement Assessment"],
        "default_unit": "Radiological Finding",
    },
    {
        "test_name": "MRI Lumbar Spine / Knee Joint",
        "category": "RADIOLOGY",
        "specimen_type": "Diagnostic Imaging (1.5T MRI Scanner)",
        "tube_color": "#4338CA",
        "is_sensitive": False,
        "parameters": ["Sagittal T1/T2", "Axial Sequences", "Intervertebral Disc Status", "Spinal Canal / Neural Foramina"],
        "default_unit": "Radiological Finding",
    },
    {
        "test_name": "CT Scan Brain / Chest HRCT",
        "category": "RADIOLOGY",
        "specimen_type": "Diagnostic Imaging (128-Slice CT Scanner)",
        "tube_color": "#6366F1",
        "is_sensitive": False,
        "parameters": ["Axial Slices", "Parenchymal Window", "Mediastinal / Bone Window"],
        "default_unit": "Radiological Finding",
    },
    {
        "test_name": "Ultrasound Whole Abdomen (USG)",
        "category": "RADIOLOGY",
        "specimen_type": "Ultrasonography (3.5 MHz Curvilinear Probe)",
        "tube_color": "#0284C7",
        "is_sensitive": False,
        "parameters": ["Liver & Gallbladder", "Spleen & Pancreas", "Kidneys (B/L) & Urinary Bladder"],
        "default_unit": "Echotexture Finding",
    },
    {
        "test_name": "Chest X-Ray PA View",
        "category": "RADIOLOGY",
        "specimen_type": "Digital Radiography (PA Projection)",
        "tube_color": "#0EA5E9",
        "is_sensitive": False,
        "parameters": ["Lung Fields & Bronchovascular Markings", "Cardiothoracic Ratio", "Costophrenic & Cardiophrenic Angles", "Bony Thorax"],
        "default_unit": "Radiographic Impression",
    },
    {
        "test_name": "12-Lead Electrocardiogram (ECG)",
        "category": "CARDIOLOGY",
        "specimen_type": "Electrophysiology (12-Lead Recording)",
        "tube_color": "#E11D48",
        "is_sensitive": False,
        "parameters": ["Heart Rate & Rhythm", "PR & QRS Interval", "ST-Segment & T-Wave Morphology", "Axis Deviation"],
        "default_unit": "ms / mV",
    },
]

SENSITIVE_TEST_NAMES = {"HIV", "VDRL"}


class LaboratoryService:

    @staticmethod
    def get_catalogue(category: Optional[str] = None) -> List[Dict[str, Any]]:
        if category and category.strip():
            cat = category.strip().upper()
            return [t for t in LABORATORY_CATALOGUE if t["category"].upper() == cat]
        return LABORATORY_CATALOGUE

    @staticmethod
    def find_catalogue_item(test_name: str) -> Optional[Dict[str, Any]]:
        target = test_name.strip().lower()
        for item in LABORATORY_CATALOGUE:
            if item["test_name"].lower() == target:
                return item
        # Partial match fallback
        for item in LABORATORY_CATALOGUE:
            if target in item["test_name"].lower() or item["test_name"].lower() in target:
                return item
        return None

    @staticmethod
    def is_sensitive_test(test_name: str) -> bool:
        target = test_name.strip().upper()
        return any(s in target for s in SENSITIVE_TEST_NAMES)

    @staticmethod
    def generate_order_number(db: Session) -> str:
        today_str = datetime.utcnow().strftime("%Y%m%d")
        prefix = f"LAB-{today_str}-"
        count = db.query(LabOrder).filter(LabOrder.order_number.like(f"{prefix}%")).count()
        return f"{prefix}{count + 1:04d}"

    @staticmethod
    def generate_specimen_id(db: Session) -> str:
        today_str = datetime.utcnow().strftime("%Y%m%d")
        prefix = f"SPEC-{today_str}-"
        count = db.query(LabOrder).filter(LabOrder.specimen_id.like(f"{prefix}%")).count()
        return f"{prefix}{count + 1:04d}"

    @staticmethod
    def enforce_sensitive_access(order: LabOrder, current_user: User):
        """Enforces stricter authorization for sensitive laboratory tests (HIV, VDRL)."""
        if not order.is_sensitive:
            return

        user_role = (current_user.role.name if current_user.role else "").lower()
        # Authorized roles: laboratory staff, doctor, admin
        if user_role in ["laboratory", "lab_tech", "admin"]:
            return

        if user_role == "doctor":
            # Allowed if they ordered it or are the primary visit doctor
            if order.ordered_by_doctor and order.ordered_by_doctor.user_id == current_user.id:
                return
            if order.visit and order.visit.doctor and order.visit.doctor.user_id == current_user.id:
                return

        if user_role == "patient":
            # Patient can only view their own sensitive test if published/verified
            if order.patient and order.patient.user_id == current_user.id and order.published_to_visit:
                return

        raise ForbiddenException(
            f"Strict authorization required: Access to sensitive laboratory test '{order.test_name}' is restricted."
        )

    @staticmethod
    def create_order(
        db: Session,
        visit_id: str,
        test_name: str,
        test_category: Optional[str] = None,
        clinical_indication: Optional[str] = None,
        priority: str = "ROUTINE",
    ) -> LabOrder:
        visit = db.query(OPDVisit).filter(OPDVisit.id == visit_id).first()
        if not visit:
            raise NotFoundException(f"Visit '{visit_id}' not found")

        # Guard against duplicate orders on the same visit in active state
        existing_order = (
            db.query(LabOrder)
            .filter(
                LabOrder.visit_id == visit.id,
                LabOrder.test_name.ilike(test_name.strip()),
                LabOrder.status.in_(["ORDERED", "COLLECTED", "RECEIVED", "PROCESSING"]),
            )
            .first()
        )
        if existing_order:
            return existing_order

        catalogue_match = LaboratoryService.find_catalogue_item(test_name)
        category = catalogue_match["category"] if catalogue_match else (test_category or "HAEMATOLOGY")
        specimen_type = catalogue_match["specimen_type"] if catalogue_match else "Whole Blood / Specimen"
        is_sensitive = LaboratoryService.is_sensitive_test(test_name)

        order_no = LaboratoryService.generate_order_number(db)
        specimen_id = LaboratoryService.generate_specimen_id(db)

        order = LabOrder(
            visit_id=visit.id,
            patient_id=visit.patient_id,
            ordered_by_doctor_id=visit.doctor_id,
            order_number=order_no,
            specimen_id=specimen_id,
            test_name=test_name,
            test_category=category.upper(),
            clinical_indication=clinical_indication,
            specimen_type=specimen_type,
            specimen_status="PENDING_COLLECTION",
            status="ORDERED",
            is_sensitive=is_sensitive,
            ordered_at=datetime.utcnow(),
        )
        db.add(order)
        db.commit()
        db.refresh(order)
        return order

    @staticmethod
    def collect_specimen(
        db: Session,
        order_id: str,
        specimen_type: Optional[str] = None,
        collector_name: Optional[str] = None,
        collection_time: Optional[datetime] = None,
    ) -> LabOrder:
        order = db.query(LabOrder).filter(LabOrder.id == order_id).first()
        if not order:
            raise NotFoundException(f"Lab order '{order_id}' not found")

        if order.status in ["CANCELLED", "REJECTED"]:
            raise BadRequestException(f"Cannot collect specimen for an order that is {order.status}")

        order.specimen_status = "COLLECTED"
        order.status = "COLLECTED"
        order.collected_at = collection_time or datetime.utcnow()
        if collector_name:
            order.collected_by_name = collector_name
        if specimen_type:
            order.specimen_type = specimen_type

        db.commit()
        db.refresh(order)
        return order

    @staticmethod
    def receive_specimen(
        db: Session,
        order_id: str,
        receiver_name: Optional[str] = None,
    ) -> LabOrder:
        order = db.query(LabOrder).filter(LabOrder.id == order_id).first()
        if not order:
            raise NotFoundException(f"Lab order '{order_id}' not found")

        if order.specimen_status == "PENDING_COLLECTION":
            # Auto-record collection timestamp if received directly
            order.collected_at = order.collected_at or datetime.utcnow()
            order.collected_by_name = order.collected_by_name or receiver_name

        order.specimen_status = "RECEIVED"
        order.status = "RECEIVED"
        order.received_at = datetime.utcnow()
        if receiver_name:
            order.received_by_name = receiver_name

        db.commit()
        db.refresh(order)
        return order

    @staticmethod
    def reject_specimen(
        db: Session,
        order_id: str,
        reason: str,
    ) -> LabOrder:
        order = db.query(LabOrder).filter(LabOrder.id == order_id).first()
        if not order:
            raise NotFoundException(f"Lab order '{order_id}' not found")

        if not reason or not reason.strip():
            raise BadRequestException("Specimen rejection reason must be documented")

        order.specimen_status = "REJECTED"
        order.status = "REJECTED"
        order.rejection_reason = reason.strip()

        db.commit()
        db.refresh(order)
        return order

    @staticmethod
    def record_results(
        db: Session,
        order_id: str,
        results_data: List[Dict[str, Any]],
        current_user: User,
    ) -> LabOrder:
        order = db.query(LabOrder).filter(LabOrder.id == order_id).first()
        if not order:
            raise NotFoundException(f"Lab order '{order_id}' not found")

        if order.status == "REJECTED":
            raise BadRequestException("Cannot enter results for a rejected specimen")

        if not results_data:
            raise BadRequestException("At least one test parameter result is required")

        # Clear existing unverified results if updating draft results
        db.query(LabResult).filter(LabResult.lab_order_id == order.id).delete()

        has_abnormal = False
        has_critical = False

        for res in results_data:
            is_abn = bool(res.get("is_abnormal", False))
            is_crit = bool(res.get("is_critical", False))
            flag = "CRITICAL" if is_crit else ("ABNORMAL" if is_abn else "NORMAL")
            if is_abn:
                has_abnormal = True
            if is_crit:
                has_critical = True

            lab_res = LabResult(
                lab_order_id=order.id,
                parameter_name=res["parameter_name"],
                result_value=str(res["result_value"]),
                unit=res.get("unit"),
                reference_range=res.get("reference_range"),
                is_abnormal=is_abn,
                is_critical=is_crit,
                flag=flag,
                notes=res.get("notes"),
                reported_at=datetime.utcnow(),
            )
            db.add(lab_res)

        order.specimen_status = "PROCESSING"
        order.status = "PROCESSING"
        order.requires_review = has_abnormal or has_critical or order.is_sensitive

        db.commit()
        db.refresh(order)
        return order

    @staticmethod
    def verify_results(
        db: Session,
        order_id: str,
        current_user: User,
        notes: Optional[str] = None,
    ) -> LabOrder:
        order = db.query(LabOrder).filter(LabOrder.id == order_id).first()
        if not order:
            raise NotFoundException(f"Lab order '{order_id}' not found")

        results_count = db.query(LabResult).filter(LabResult.lab_order_id == order.id).count()
        if results_count == 0:
            raise BadRequestException("Cannot verify an order with no entered results")

        now = datetime.utcnow()
        order.verified_by_user_id = current_user.id
        order.verified_by_name = current_user.full_name or "Authorized Laboratory Personnel"
        order.verified_at = now
        order.verification_notes = notes
        order.status = "COMPLETED"
        order.completed_at = now
        order.specimen_status = "COMPLETED"
        order.published_to_visit = True

        # Timestamp results
        for r in order.results:
            r.verified_at = now
            r.verified_by_user_id = current_user.id

        db.commit()
        db.refresh(order)
        return order

    @staticmethod
    def build_printable_report(db: Session, order_id: str, current_user: User) -> Dict[str, Any]:
        order = db.query(LabOrder).filter(LabOrder.id == order_id).first()
        if not order:
            raise NotFoundException(f"Lab order '{order_id}' not found")

        LaboratoryService.enforce_sensitive_access(order, current_user)

        pat = order.patient
        patient_info = {
            "id": pat.id if pat else "",
            "uhid": pat.uhid if pat else "N/A",
            "full_name": pat.full_name if pat else "Patient",
            "age_years": pat.age_years if pat else None,
            "gender": pat.gender if pat else "Unknown",
            "phone": pat.phone if pat else "",
            "hospital_reg_num": pat.hospital_reg_num if pat else "",
        }

        doc = order.ordered_by_doctor
        doctor_info = {
            "id": doc.id if doc else "",
            "doctor_name": doc.user.full_name if (doc and doc.user) else "Attending Clinician",
            "department": doc.department.name if (doc and doc.department) else "General OPD",
        }

        seal = {
            "verified_by": order.verified_by_name or "Authorized Laboratory Personnel",
            "verified_at": order.verified_at.isoformat() if order.verified_at else None,
            "verification_status": "VERIFIED & SIGNED" if order.verified_at else "PRELIMINARY / UNVERIFIED",
            "digital_hash": f"OPDCONNECT-LAB-{order.id[:8]}-{order.order_number or 'ORD'}",
        }

        from app.schemas.laboratory import LabOrderRead
        order_read = LaboratoryService.serialize_order(order)

        return {
            "order": order_read,
            "patient": patient_info,
            "doctor": doctor_info,
            "hospital_name": "OPD Connect+ Central Diagnostic Laboratory",
            "accreditation_info": "Certified Clinical Pathology & Diagnostics",
            "report_generated_at": datetime.utcnow(),
            "verification_seal": seal,
        }

    @staticmethod
    def serialize_order(order: LabOrder) -> Dict[str, Any]:
        pat = order.patient
        doc = order.ordered_by_doctor

        res_list = []
        for r in (order.results or []):
            res_list.append({
                "id": r.id,
                "lab_order_id": r.lab_order_id,
                "parameter_name": r.parameter_name,
                "result_value": r.result_value,
                "unit": r.unit,
                "reference_range": r.reference_range,
                "is_abnormal": r.is_abnormal,
                "is_critical": r.is_critical,
                "flag": r.flag,
                "notes": r.notes,
                "reported_at": r.reported_at,
                "verified_at": r.verified_at,
            })

        return {
            "id": order.id,
            "order_number": order.order_number or f"LAB-{order.id[:8].upper()}",
            "visit_id": order.visit_id,
            "patient_id": order.patient_id,
            "patient_name": pat.full_name if pat else "Patient",
            "patient_uhid": pat.uhid if pat else "UHID",
            "patient_age": pat.age_years if pat else None,
            "patient_gender": pat.gender if pat else None,
            "ordered_by_doctor_id": order.ordered_by_doctor_id,
            "doctor_name": doc.user.full_name if (doc and doc.user) else "Doctor",
            "test_name": order.test_name,
            "test_category": order.test_category,
            "status": order.status,
            "specimen_id": order.specimen_id or f"SPEC-{order.id[:8].upper()}",
            "specimen_type": order.specimen_type,
            "specimen_status": order.specimen_status,
            "collected_at": order.collected_at,
            "collected_by_name": order.collected_by_name,
            "received_at": order.received_at,
            "received_by_name": order.received_by_name,
            "rejection_reason": order.rejection_reason,
            "is_sensitive": order.is_sensitive,
            "requires_review": order.requires_review,
            "verified_by_user_id": order.verified_by_user_id,
            "verified_by_name": order.verified_by_name,
            "verified_at": order.verified_at,
            "verification_notes": order.verification_notes,
            "published_to_visit": order.published_to_visit,
            "clinical_indication": order.clinical_indication,
            "ordered_at": order.ordered_at,
            "completed_at": order.completed_at,
            "results": res_list,
        }
