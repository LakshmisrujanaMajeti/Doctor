from datetime import datetime
from typing import List, Optional, Dict, Any
from app.schemas.common import BaseSchema


class LabCatalogueItem(BaseSchema):
    test_name: str
    category: str
    specimen_type: str
    tube_color: str
    is_sensitive: bool = False
    parameters: List[str]
    default_unit: Optional[str] = None


class LabResultBase(BaseSchema):
    parameter_name: str
    result_value: str
    unit: Optional[str] = None
    reference_range: Optional[str] = None
    is_abnormal: bool = False
    is_critical: bool = False
    notes: Optional[str] = None


class LabResultCreate(LabResultBase):
    lab_order_id: Optional[str] = None


class LabResultBatchCreate(BaseSchema):
    results: List[LabResultCreate]


class LabResultRead(LabResultBase):
    id: str
    lab_order_id: str
    flag: str = "NORMAL"
    reported_at: datetime
    verified_at: Optional[datetime] = None


class LabOrderBase(BaseSchema):
    test_name: str
    test_category: Optional[str] = "HAEMATOLOGY"
    clinical_indication: Optional[str] = None


class LabOrderCreate(LabOrderBase):
    visit_id: str
    priority: Optional[str] = "ROUTINE"


class SpecimenCollectionRequest(BaseSchema):
    specimen_type: Optional[str] = None
    collector_name: Optional[str] = None
    collection_time: Optional[datetime] = None


class SpecimenReceiveRequest(BaseSchema):
    receiver_name: Optional[str] = None


class SpecimenRejectRequest(BaseSchema):
    rejection_reason: str


class LabOrderVerifyRequest(BaseSchema):
    verification_notes: Optional[str] = None


class LabOrderRead(LabOrderBase):
    id: str
    order_number: Optional[str] = None
    visit_id: str
    patient_id: str
    patient_name: Optional[str] = None
    patient_uhid: Optional[str] = None
    patient_age: Optional[int] = None
    patient_gender: Optional[str] = None
    ordered_by_doctor_id: str
    doctor_name: Optional[str] = None
    status: str
    specimen_id: Optional[str] = None
    specimen_type: Optional[str] = None
    specimen_status: str = "PENDING_COLLECTION"
    collected_at: Optional[datetime] = None
    collected_by_name: Optional[str] = None
    received_at: Optional[datetime] = None
    received_by_name: Optional[str] = None
    rejection_reason: Optional[str] = None
    is_sensitive: bool = False
    requires_review: bool = False
    verified_by_user_id: Optional[str] = None
    verified_by_name: Optional[str] = None
    verified_at: Optional[datetime] = None
    verification_notes: Optional[str] = None
    published_to_visit: bool = False
    ordered_at: datetime
    completed_at: Optional[datetime] = None
    results: List[LabResultRead] = []


class LabReportData(BaseSchema):
    order: LabOrderRead
    patient: Dict[str, Any]
    doctor: Dict[str, Any]
    hospital_name: str = "OPD Connect+ Central Diagnostic Laboratory"
    accreditation_info: str = "NABL Accredited Hospital Laboratory"
    report_generated_at: datetime
    verification_seal: Dict[str, Any]


class LabDashboardStats(BaseSchema):
    pending_collection_count: int = 0
    received_processing_count: int = 0
    pending_verification_count: int = 0
    completed_today_count: int = 0
    rejected_count: int = 0
    sensitive_tests_count: int = 0
