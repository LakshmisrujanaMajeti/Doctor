from fastapi import APIRouter
from app.api.v1.endpoints import (
    health,
    auth,
    users,
    patients,
    departments,
    doctors,
    visits,
    clinical_records,
    prescriptions,
    laboratory,
    pharmacy,
    billing,
    documents,
    admin,
    patient_portal,
)

api_router = APIRouter()

api_router.include_router(health.router, prefix="/health", tags=["Health"])
api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(users.router, prefix="/users", tags=["Users & Roles"])
api_router.include_router(patients.router, prefix="/patients", tags=["Patients"])
api_router.include_router(departments.router, prefix="/departments", tags=["Departments"])
api_router.include_router(doctors.router, prefix="/doctors", tags=["Doctors"])
api_router.include_router(visits.router, prefix="/visits", tags=["OPD Visits & Triage"])
api_router.include_router(clinical_records.router, prefix="/clinical-records", tags=["Clinical Records (OPD Booklet)"])
api_router.include_router(prescriptions.router, prefix="/prescriptions", tags=["Prescriptions"])
api_router.include_router(laboratory.router, prefix="/laboratory", tags=["Laboratory"])
api_router.include_router(pharmacy.router, prefix="/pharmacy", tags=["Pharmacy"])
api_router.include_router(billing.router, prefix="/billing", tags=["Billing & Invoicing"])
api_router.include_router(documents.router, prefix="/documents", tags=["Medical Documents"])
api_router.include_router(admin.router, prefix="/admin", tags=["Administration & Audit"])
api_router.include_router(patient_portal.router, prefix="/patient-portal", tags=["Patient Portal"])

