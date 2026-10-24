from datetime import datetime, date
from typing import Optional, List, Dict, Any
from pydantic import Field, field_validator
from app.schemas.common import BaseSchema
from app.schemas.patient import PatientRead
from app.core.validators import validate_person_name, validate_indian_phone


# ==========================================
# Patient Portal Schemas
# ==========================================

class PatientDependentCreate(BaseSchema):
    full_name: str = Field(..., min_length=2, max_length=150)
    relation: str = Field(..., description="e.g. Son, Daughter, Mother, Father, Spouse, Ward")
    gender: str = Field(..., description="MALE, FEMALE, OTHER")
    date_of_birth: Optional[date] = None
    age_years: Optional[int] = Field(None, ge=0, le=130)
    age_months: Optional[int] = Field(None, ge=0, le=11)
    blood_group: Optional[str] = None
    emergency_contact_phone: Optional[str] = None

    @field_validator("full_name")
    def validate_dependent_name(cls, v: str) -> str:
        return validate_person_name(v, "Dependent Name", required=True)

    @field_validator("emergency_contact_phone")
    def validate_contact_phone(cls, v: Optional[str]) -> Optional[str]:
        return validate_indian_phone(v, "Emergency Contact Phone", required=False)


class DependentProfileItem(BaseSchema):
    id: str
    uhid: str
    full_name: str
    relation: str
    gender: str
    age_display: str
    blood_group: Optional[str] = None
    registration_date: datetime


class PatientQuickAccessRequest(BaseSchema):
    identifier: str = Field(..., description="UHID, Queue Token #, Phone, or Visit Number")


class PatientActiveVisitSummary(BaseSchema):
    id: str
    visit_number: str
    queue_token: int
    status: str
    triage_priority: str
    doctor_name: str
    department_name: str
    room_number: str
    patients_ahead: int
    visit_date: str
    payment_status: str
    consultation_fee: float


class PatientQuickAccessResponse(BaseSchema):
    access_token: str
    token_type: str = "bearer"
    expires_in: int = 86400
    patient: PatientRead
    active_visit: Optional[PatientActiveVisitSummary] = None


class PatientPortalProfileResponse(BaseSchema):
    patient: PatientRead
    dependents: List[DependentProfileItem]
    has_active_token: bool = False
    active_token_number: Optional[str] = None
    active_token_queue_status: Optional[str] = None


class PatientUpcomingAppointmentItem(BaseSchema):
    visit_id: str
    visit_number: str
    doctor_name: str
    department_name: str
    scheduled_date: str
    follow_up_reason: Optional[str] = None
    care_plan: Optional[str] = None
    is_completed: bool = False


class PatientPrescriptionItemDetail(BaseSchema):
    medicine_name: str
    form: str
    dosage: str
    route: str
    frequency: str
    duration_days: int
    quantity: int
    timing: Optional[str] = None
    instructions: Optional[str] = None
    is_dispensed: bool = False


class PatientPrescriptionSummaryItem(BaseSchema):
    id: str
    visit_id: str
    doctor_name: str
    department_name: str
    status: str
    signed_at: Optional[datetime] = None
    notes: Optional[str] = None
    items: List[PatientPrescriptionItemDetail]


class PatientLabResultDetail(BaseSchema):
    parameter_name: str
    result_value: str
    unit: Optional[str] = None
    reference_range: Optional[str] = None
    is_abnormal: bool = False


class PatientLabReportSummaryItem(BaseSchema):
    id: str
    order_number: Optional[str] = None
    test_name: str
    test_category: str
    status: str
    ordered_at: datetime
    completed_at: Optional[datetime] = None
    specimen_type: Optional[str] = None
    is_sensitive: bool = False
    results: List[PatientLabResultDetail] = []


class PatientBillSummaryItem(BaseSchema):
    id: str
    invoice_number: str
    visit_id: Optional[str] = None
    total_amount: float
    paid_amount: float
    discount_amount: float
    payment_status: str
    billed_at: datetime
    receipt_number: Optional[str] = None
    items_count: int


class SupportTicketCreate(BaseSchema):
    subject: str = Field(..., min_length=3, max_length=200)
    category: str = Field("GENERAL", description="GENERAL, APPOINTMENT, BILLING, MEDICAL_RECORDS, PHARMACY, TECHNICAL")
    priority: str = Field("NORMAL", description="LOW, NORMAL, HIGH, URGENT")
    message: str = Field(..., min_length=5)
    dependent_patient_id: Optional[str] = None


class SupportTicketRead(BaseSchema):
    id: str
    patient_id: str
    patient_name: str
    patient_uhid: str
    subject: str
    category: str
    priority: str
    message: str
    status: str
    admin_response: Optional[str] = None
    resolved_at: Optional[datetime] = None
    created_at: datetime


class SupportTicketResolveRequest(BaseSchema):
    admin_response: str = Field(..., min_length=2)
    status: str = Field("RESOLVED", description="IN_PROGRESS, RESOLVED, CLOSED")


# ==========================================
# Hospital Administrator Portal Schemas
# ==========================================

class AdminDashboardMetrics(BaseSchema):
    # Footfall & Queues
    total_patients_registered: int
    visits_today_count: int
    queue_breakdown: Dict[str, int]
    active_clinics_count: int
    active_doctors_count: int

    # Financial Summary
    revenue_today: float
    revenue_month: float
    pending_bills_count: int
    pending_bills_amount: float
    revenue_by_method: Dict[str, float]

    # Pharmacy & Inventory
    low_stock_items_count: int
    expiring_soon_items_count: int
    total_medicines_in_formulary: int

    # Laboratory
    pending_lab_orders_count: int
    completed_lab_today_count: int

    # Accounts & Security
    total_staff_accounts: int
    staff_by_role: Dict[str, int]
    inactive_accounts_count: int
    locked_accounts_count: int

    # Live Access & Audit Metrics
    total_signups: int = 0
    total_signins_today: int = 0
    active_sessions: int = 0


class UserRoleUpdateRequest(BaseSchema):
    role_name: str
    additional_permission_codes: Optional[List[str]] = None


class AdminUserUpdateRequest(BaseSchema):
    full_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    role_name: Optional[str] = None
    department_name: Optional[str] = None
    room_number: Optional[str] = None
    qualification: Optional[str] = None
    consultation_fee: Optional[str] = None
    is_active: Optional[bool] = None


class SystemConfigItem(BaseSchema):
    config_key: str
    config_value: str
    category: str
    description: Optional[str] = None
    updated_at: Optional[datetime] = None


class SystemConfigBatchUpdateRequest(BaseSchema):
    configs: Dict[str, str]


class BackupGuidanceResponse(BaseSchema):
    database_engine: str
    backup_schedule: str
    retention_period_days: int
    last_backup_status: str
    last_backup_time: str
    guidance_checklist: List[str]
    cron_specification: str
    restore_procedure_steps: List[str]


class AvailableSlotItem(BaseSchema):
    slot_time: str
    is_available: bool = True
    booked_count: int = 0
    max_capacity: int = 5


class BookSlotRequest(BaseSchema):
    patient_id: Optional[str] = None
    department_id: str
    doctor_id: Optional[str] = None
    slot_date: str
    slot_time: str
    chief_complaint: Optional[str] = None

