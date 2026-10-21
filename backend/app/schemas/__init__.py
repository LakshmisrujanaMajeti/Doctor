from app.schemas.common import BaseSchema, TimestampedSchema
from app.schemas.auth import LoginRequest, RefreshTokenRequest, TokenData, RegisterRequest
from app.schemas.user import UserBase, UserCreate, UserRead, RoleRead, PermissionRead
from app.schemas.department import DepartmentBase, DepartmentCreate, DepartmentRead
from app.schemas.doctor import DoctorBase, DoctorCreate, DoctorRead
from app.schemas.patient import PatientBase, PatientCreate, PatientUpdate, PatientRead
from app.schemas.visit import VitalSignsBase, VitalSignsCreate, VitalSignsRead, OPDVisitBase, OPDVisitCreate, OPDVisitUpdate, OPDVisitRead
from app.schemas.clinical import ClinicalRecordBase, ClinicalRecordCreate, ClinicalRecordRead
from app.schemas.prescription import PrescriptionItemBase, PrescriptionItemCreate, PrescriptionItemRead, PrescriptionCreate, PrescriptionRead
from app.schemas.laboratory import LabResultBase, LabResultCreate, LabResultRead, LabOrderBase, LabOrderCreate, LabOrderRead
from app.schemas.pharmacy import PharmacyOrderCreate, PharmacyOrderRead
from app.schemas.billing import BillItemBase, BillItemCreate, BillItemRead, BillCreate, BillRead
from app.schemas.document import MedicalDocumentBase, MedicalDocumentCreate, MedicalDocumentRead

__all__ = [
    "BaseSchema",
    "TimestampedSchema",
    "LoginRequest",
    "RefreshTokenRequest",
    "TokenData",
    "RegisterRequest",
    "UserBase",
    "UserCreate",
    "UserRead",
    "RoleRead",
    "PermissionRead",
    "DepartmentBase",
    "DepartmentCreate",
    "DepartmentRead",
    "DoctorBase",
    "DoctorCreate",
    "DoctorRead",
    "PatientBase",
    "PatientCreate",
    "PatientUpdate",
    "PatientRead",
    "VitalSignsBase",
    "VitalSignsCreate",
    "VitalSignsRead",
    "OPDVisitBase",
    "OPDVisitCreate",
    "OPDVisitUpdate",
    "OPDVisitRead",
    "ClinicalRecordBase",
    "ClinicalRecordCreate",
    "ClinicalRecordRead",
    "PrescriptionItemBase",
    "PrescriptionItemCreate",
    "PrescriptionItemRead",
    "PrescriptionCreate",
    "PrescriptionRead",
    "LabResultBase",
    "LabResultCreate",
    "LabResultRead",
    "LabOrderBase",
    "LabOrderCreate",
    "LabOrderRead",
    "PharmacyOrderCreate",
    "PharmacyOrderRead",
    "BillItemBase",
    "BillItemCreate",
    "BillItemRead",
    "BillCreate",
    "BillRead",
    "MedicalDocumentBase",
    "MedicalDocumentCreate",
    "MedicalDocumentRead",
]
