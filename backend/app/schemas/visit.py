from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import Field
from app.schemas.common import BaseSchema
from app.schemas.patient import PatientRead
from app.schemas.doctor import DoctorRead, DoctorDashboardStats, FollowUpItem, RecentAuthorizedPatientItem
from app.schemas.department import DepartmentRead


class VitalSignsBase(BaseSchema):
    systolic_bp: Optional[int] = Field(None, ge=40, le=280)
    diastolic_bp: Optional[int] = Field(None, ge=30, le=180)
    pulse_rate: Optional[int] = Field(None, ge=30, le=250)
    temperature_f: Optional[float] = Field(None, ge=90.0, le=110.0)
    spo2_percent: Optional[float] = Field(None, ge=50.0, le=100.0)
    respiratory_rate: Optional[int] = Field(None, ge=6, le=60)
    weight_kg: Optional[float] = Field(None, ge=1.0, le=400.0)
    height_cm: Optional[float] = Field(None, ge=20.0, le=260.0)
    bmi: Optional[float] = None
    blood_glucose_mg_dl: Optional[float] = Field(None, ge=10.0, le=1000.0)
    recorded_by_user_id: Optional[str] = None
    notes: Optional[str] = None


class VitalSignsCreate(VitalSignsBase):
    visit_id: str


class VitalSignsRead(VitalSignsBase):
    id: str
    visit_id: str
    recorded_at: datetime


class OPDVisitBase(BaseSchema):
    patient_id: str
    doctor_id: str
    department_id: str
    triage_priority: str = "NORMAL" # NORMAL, PRIORITY, EMERGENCY
    consultation_fee: float = 500.0
    notes: Optional[str] = None


class OPDVisitCreate(OPDVisitBase):
    pass


class OPDVisitUpdate(BaseSchema):
    doctor_id: Optional[str] = None
    triage_priority: Optional[str] = None
    status: Optional[str] = None # REGISTERED, TRIAGED, IN_CONSULTATION, COMPLETED, CANCELLED
    payment_status: Optional[str] = None # UNPAID, PAID
    notes: Optional[str] = None


class OPDVisitRead(OPDVisitBase):
    id: str
    visit_number: str
    visit_date: datetime
    queue_token: int
    status: str
    payment_status: str

    patient: Optional[PatientRead] = None
    doctor: Optional[DoctorRead] = None
    department: Optional[DepartmentRead] = None
    vitals: Optional[VitalSignsRead] = None


class PreviousVisitSummary(BaseSchema):
    id: str
    visit_number: str
    visit_date: datetime
    doctor_name: Optional[str] = None
    department_name: Optional[str] = None
    provisional_diagnosis: Optional[str] = None
    final_diagnosis: Optional[str] = None
    chief_complaint: Optional[str] = None
    status: str = "COMPLETED"


class PatientMedicalHistorySummary(BaseSchema):
    allergies: Optional[str] = None
    past_medical_history: Optional[str] = None
    prior_hospitalization: Optional[str] = None
    hypertension_history: Optional[str] = None
    diabetes_history: Optional[str] = None
    asthma_history: Optional[str] = None
    tuberculosis_history: Optional[str] = None
    smoking_history: Optional[str] = None
    alcohol_history: Optional[str] = None
    family_history: Optional[str] = None


class ConsultationContextRead(BaseSchema):
    visit: OPDVisitRead
    patient: PatientRead
    medical_history: PatientMedicalHistorySummary
    previous_visits: List[PreviousVisitSummary] = []
    available_investigations: List[Dict[str, Any]] = []
    active_prescriptions: List[Dict[str, Any]] = []
    clinical_record: Optional[Dict[str, Any]] = None


class DoctorDashboardResponse(BaseSchema):
    doctor: DoctorRead
    stats: DoctorDashboardStats
    today_appointments: List[OPDVisitRead] = []
    waiting_patients: List[OPDVisitRead] = []
    under_consultation: List[OPDVisitRead] = []
    completed_consultations: List[OPDVisitRead] = []
    pending_investigations: List[Dict[str, Any]] = []
    follow_up_appointments: List[FollowUpItem] = []
    recent_authorized_patients: List[RecentAuthorizedPatientItem] = []
