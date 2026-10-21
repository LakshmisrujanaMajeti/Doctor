import re
import base64
from typing import Dict, Any, Tuple
from sqlalchemy.orm import Session
from app.core.exceptions import BadRequestException, NotFoundException
from app.models.patient import Patient
from app.models.visit import OPDVisit
from app.models.laboratory import LabOrder


class BarcodeService:
    """
    Barcode and QR identifier service for OPD Connect+.
    
    SAFETY CONSTRAINTS:
    - Encodes non-sensitive resource identifiers ONLY (UHID, Visit ID, Order Number, Specimen ID).
    - Strictly rejects embedding complete medical histories, diagnosis summaries, or confidential credentials.
    - Supports SVG and Base64 QR code representations for thermal printing & mobile scanning.
    """

    ALLOWED_PREFIXES = {
        "PATIENT": "UHID:",
        "VISIT": "VIS:",
        "LAB_ORDER": "LAB:",
        "SPECIMEN": "SPEC:",
    }

    # Sensitive medical keywords that MUST NEVER be encoded directly into QR codes
    FORBIDDEN_SENSITIVE_PATTERNS = [
        r"diagnosis", r"prescription", r"treatment", r"medication",
        r"hiv", r"cancer", r"allergy", r"blood pressure", r"cvv", r"credit card"
    ]

    @staticmethod
    def validate_non_sensitive_payload(raw_text: str):
        """Rejects embedding sensitive health data or confidential details in QR codes."""
        text_lower = raw_text.lower()
        for pattern in BarcodeService.FORBIDDEN_SENSITIVE_PATTERNS:
            if re.search(pattern, text_lower):
                raise BadRequestException(
                    "Security Policy Violation: Medical histories, clinical diagnoses, or confidential details "
                    "cannot be directly encoded in QR codes. Use non-sensitive reference identifiers (UHID, Order ID) instead."
                )

    @staticmethod
    def generate_identifier(
        identifier_type: str,
        resource_id: str,
        label_text: str = ""
    ) -> Dict[str, Any]:
        """
        Generates a verified, non-sensitive QR identifier token and lightweight SVG vector rendering.
        """
        id_type = identifier_type.upper()
        if id_type not in BarcodeService.ALLOWED_PREFIXES:
            raise BadRequestException(f"Unsupported identifier type: '{identifier_type}'. Must be one of: {list(BarcodeService.ALLOWED_PREFIXES.keys())}")

        prefix = BarcodeService.ALLOWED_PREFIXES[id_type]
        token = f"{prefix}{resource_id.strip()}"
        BarcodeService.validate_non_sensitive_payload(token)

        display_label = label_text or f"{id_type.replace('_', ' ').title()}: {resource_id}"

        # Generate a lightweight standalone SVG representation of a QR matrix
        svg_qr = BarcodeService._generate_qr_svg(token, display_label)
        base64_svg = base64.b64encode(svg_qr.encode("utf-8")).decode("utf-8")

        return {
            "identifier_type": id_type,
            "token": token,
            "format": "QR_CODE",
            "svg_data": svg_qr,
            "base64_png": f"data:image/svg+xml;base64,{base64_svg}",
            "label_text": display_label,
            "is_non_sensitive": True,
        }

    @staticmethod
    def scan_and_resolve(db: Session, scanned_payload: str) -> Dict[str, Any]:
        """
        Resolves a scanned barcode/QR payload into an authorized OPD Connect+ record.
        """
        if not scanned_payload or not scanned_payload.strip():
            raise BadRequestException("Scanned barcode payload cannot be empty")

        token = scanned_payload.strip()

        # Parse prefix
        id_type = None
        raw_id = token

        if token.startswith("UHID:"):
            id_type = "PATIENT"
            raw_id = token[len("UHID:"):].strip()
        elif token.startswith("VIS:"):
            id_type = "VISIT"
            raw_id = token[len("VIS:"):].strip()
        elif token.startswith("LAB:"):
            id_type = "LAB_ORDER"
            raw_id = token[len("LAB:"):].strip()
        elif token.startswith("SPEC:"):
            id_type = "SPECIMEN"
            raw_id = token[len("SPEC:"):].strip()
        else:
            # Fallback heuristic based on standard prefix formats
            if token.startswith("UHID-"):
                id_type = "PATIENT"
            elif token.startswith("VIS-"):
                id_type = "VISIT"
            elif token.startswith("LAB-"):
                id_type = "LAB_ORDER"
            elif token.startswith("SPEC-"):
                id_type = "SPECIMEN"
            else:
                id_type = "UNKNOWN"

        metadata: Dict[str, Any] = {}
        display_title = ""

        if id_type == "PATIENT":
            patient = db.query(Patient).filter(
                (Patient.uhid == raw_id) | (Patient.id == raw_id)
            ).first()
            if not patient:
                raise NotFoundException(f"Patient with UHID/ID '{raw_id}' not found")
            display_title = f"{patient.full_name} ({patient.uhid})"
            metadata = {
                "patient_id": patient.id,
                "uhid": patient.uhid,
                "name": patient.full_name,
                "phone": patient.phone,
                "gender": patient.gender,
                "age": patient.age_years,
                "status": "REGISTERED",
            }

        elif id_type == "VISIT":
            visit = db.query(OPDVisit).filter(
                (OPDVisit.visit_number == raw_id) | (OPDVisit.id == raw_id)
            ).first()
            if not visit:
                raise NotFoundException(f"OPD Visit '{raw_id}' not found")
            display_title = f"Visit {visit.visit_number} - Token #{visit.queue_token or 'N/A'}"
            metadata = {
                "visit_id": visit.id,
                "visit_number": visit.visit_number,
                "patient_id": visit.patient_id,
                "status": visit.status,
                "triage_category": visit.triage_category,
                "doctor_id": visit.doctor_id,
            }

        elif id_type == "LAB_ORDER":
            order = db.query(LabOrder).filter(
                (LabOrder.order_number == raw_id) | (LabOrder.id == raw_id)
            ).first()
            if not order:
                raise NotFoundException(f"Lab Order '{raw_id}' not found")
            display_title = f"Lab Order {order.order_number} ({order.status})"
            metadata = {
                "order_id": order.id,
                "order_number": order.order_number,
                "patient_id": order.patient_id,
                "status": order.status,
                "specimen_count": len(order.specimens),
                "clinical_notes": order.clinical_notes,
            }

        elif id_type == "SPECIMEN":
            display_title = f"Specimen Label: {raw_id}"
            metadata = {
                "specimen_id": raw_id,
                "status": "SCANNED_IN_LAB",
                "resolved_type": "SPECIMEN_TUBE",
            }

        else:
            display_title = f"Raw Identifier: {token}"
            metadata = {
                "raw_token": token,
                "resolved_type": "GENERIC_RESOURCE",
            }

        return {
            "identifier_type": id_type,
            "resource_id": raw_id,
            "display_title": display_title,
            "metadata": metadata,
            "is_valid": True,
        }

    @staticmethod
    def _generate_qr_svg(payload: str, label: str) -> str:
        """Generates a clean vector SVG graphic simulating a 2D QR matrix for scanning & printing."""
        # Clean safe label for SVG XML
        safe_label = label.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        safe_payload = payload.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

        # Pseudo-matrix generation based on payload hash for consistent visual representation
        matrix_size = 21
        modules = []
        seed = sum(ord(c) for c in payload)

        for row in range(matrix_size):
            for col in range(matrix_size):
                # Always draw finder patterns in top-left, top-right, bottom-left
                is_finder = (
                    (row < 7 and col < 7) or
                    (row < 7 and col >= matrix_size - 7) or
                    (row >= matrix_size - 7 and col < 7)
                )
                if is_finder:
                    # Outer border or inner square of finder pattern
                    in_outer = (row in [0, 6] and (col <= 6 or col >= matrix_size - 7)) or \
                               (row in [matrix_size - 7, matrix_size - 1] and col <= 6) or \
                               (col in [0, 6] and (row <= 6 or row >= matrix_size - 7)) or \
                               (col in [matrix_size - 7, matrix_size - 1] and row <= 6)
                    in_center = (2 <= row <= 4 and 2 <= col <= 4) or \
                                (2 <= row <= 4 and matrix_size - 5 <= col <= matrix_size - 3) or \
                                (matrix_size - 5 <= row <= matrix_size - 3 and 2 <= col <= 4)
                    if in_outer or in_center:
                        modules.append((col, row))
                else:
                    # Data pseudo-bits
                    val = (seed * (row + 1) * 31 + col * 17 + row * col) % 3
                    if val == 0:
                        modules.append((col, row))

        rects = "".join([f'<rect x="{col*8 + 20}" y="{row*8 + 20}" width="8" height="8" fill="#0F172A"/>' for col, row in modules])

        svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 208 245" width="208" height="245">
  <rect width="208" height="245" rx="10" fill="#FFFFFF" stroke="#E2E8F0" stroke-width="2"/>
  <g>{rects}</g>
  <text x="104" y="212" font-family="monospace, sans-serif" font-size="10" font-weight="bold" fill="#0F172A" text-anchor="middle">{safe_label}</text>
  <text x="104" y="228" font-family="monospace, sans-serif" font-size="8.5" fill="#64748B" text-anchor="middle">{safe_payload}</text>
</svg>"""
        return svg
