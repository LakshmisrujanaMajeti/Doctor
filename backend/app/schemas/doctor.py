from typing import Optional
from app.schemas.common import BaseSchema
from app.schemas.user import UserRead
from app.schemas.department import DepartmentRead


class DoctorBase(BaseSchema):
    qualification: str
    specialization: str
    registration_number: str
    room_number: Optional[str] = None
    consultation_fee: str = "500.00"
    is_available: bool = True


class DoctorCreate(DoctorBase):
    user_id: str
    department_id: str


class DoctorRead(DoctorBase):
    id: str
    user_id: str
    department_id: str
    user: Optional[UserRead] = None
    department: Optional[DepartmentRead] = None


class DoctorDashboardStats(BaseSchema):
    today_appointments: int = 0
    waiting_patients: int = 0
    under_consultation: int = 0
    completed_consultations: int = 0
    pending_investigations: int = 0
    follow_up_appointments: int = 0


class FollowUpItem(BaseSchema):
    patient_id: str
    patient_name: str
    uhid: str
    visit_id: str
    follow_up_date: str
    final_diagnosis: Optional[str] = None
    care_plan: Optional[str] = None


class RecentAuthorizedPatientItem(BaseSchema):
    patient_id: str
    uhid: str
    full_name: str
    age_display: str
    gender: str
    phone_number: str
    last_visit_date: Optional[str] = None
    last_diagnosis: Optional[str] = None
