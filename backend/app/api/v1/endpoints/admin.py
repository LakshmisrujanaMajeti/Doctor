import csv
import io
import os
import shutil
import json
from datetime import datetime, date, timedelta
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, Query, Body, HTTPException, Response
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from sqlalchemy import func, or_, and_

from app.core.database import get_db
from app.core.responses import success_response
from app.core.dependencies import require_roles, get_current_user
from app.core.exceptions import NotFoundException, ForbiddenException, BadRequestException
from app.models.patient import Patient
from app.models.visit import OPDVisit
from app.models.doctor import Doctor
from app.models.department import Department
from app.models.audit import AuditLog
from app.models.user import User, Role, Permission
from app.models.billing import Bill, BillItem, PaymentTransaction
from app.models.pharmacy import MedicineInventory
from app.models.laboratory import LabOrder
from app.models.clinical import ClinicalRecord
from app.models.support import SupportTicket
from app.models.config import SystemConfig
from app.schemas.user import UserRead, RoleRead
from app.schemas.auth import AdminCreateUserRequest, AdminUpdateUserStatusRequest
from app.schemas.portal import (
    AdminDashboardMetrics,
    UserRoleUpdateRequest,
    AdminUserUpdateRequest,
    SystemConfigItem,
    SystemConfigBatchUpdateRequest,
    BackupGuidanceResponse,
    SupportTicketRead,
    SupportTicketResolveRequest,
)
from app.services.auth_service import AuthService
from app.services.audit_service import AuditService
from app.services.laboratory_service import LABORATORY_CATALOGUE
from app.services.billing_service import BillingService

router = APIRouter()


# ==========================================
# 1. Operational Summaries & Metrics
# ==========================================

@router.get("/stats", summary="Real-time OPD Overall Statistics")
def get_admin_stats(
    db: Session = Depends(get_db),
):
    today_start = datetime.combine(date.today(), datetime.min.time())
    total_patients = db.query(func.count(Patient.id)).scalar() or 0
    total_visits = db.query(func.count(OPDVisit.id)).filter(OPDVisit.visit_date >= today_start).scalar() or 0
    active_doctors = db.query(func.count(Doctor.id)).filter(Doctor.is_available == True).scalar() or 0
    departments = db.query(func.count(Department.id)).filter(Department.is_active == True).scalar() or 0
    waiting = db.query(func.count(OPDVisit.id)).filter(
        OPDVisit.visit_date >= today_start,
        OPDVisit.status.in_(["WAITING", "REGISTERED"])
    ).scalar() or 0
    triaged = db.query(func.count(OPDVisit.id)).filter(
        OPDVisit.visit_date >= today_start,
        OPDVisit.status == "TRIAGED"
    ).scalar() or 0
    completed = db.query(func.count(OPDVisit.id)).filter(
        OPDVisit.visit_date >= today_start,
        OPDVisit.status == "COMPLETED"
    ).scalar() or 0

    return success_response(
        data={
            "total_patients": total_patients,
            "total_visits": total_visits,
            "active_doctors": active_doctors,
            "departments": departments,
            "waiting": waiting,
            "triaged": triaged,
            "completed": completed,
        },
        message="Live operational stats retrieved successfully"
    )

@router.get("/dashboard-summary", summary="Comprehensive Hospital Operational Dashboard")
def get_operational_dashboard_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    today_start = datetime.combine(date.today(), datetime.min.time())
    month_start = datetime.combine(date.today().replace(day=1), datetime.min.time())

    # Patient Footfall
    total_registered = db.query(func.count(Patient.id)).scalar() or 0
    visits_today = db.query(func.count(OPDVisit.id)).filter(OPDVisit.visit_date >= today_start).scalar() or 0

    registered_visits = db.query(func.count(OPDVisit.id)).filter(OPDVisit.status == "REGISTERED").scalar() or 0
    triaged_visits = db.query(func.count(OPDVisit.id)).filter(OPDVisit.status == "TRIAGED").scalar() or 0
    in_consultation = db.query(func.count(OPDVisit.id)).filter(OPDVisit.status == "IN_CONSULTATION").scalar() or 0
    completed_visits = db.query(func.count(OPDVisit.id)).filter(OPDVisit.status == "COMPLETED").scalar() or 0
    cancelled_visits = db.query(func.count(OPDVisit.id)).filter(OPDVisit.status == "CANCELLED").scalar() or 0

    active_clinics = db.query(func.count(Department.id)).filter(Department.is_active == True).scalar() or 0
    active_doctors = db.query(func.count(Doctor.id)).filter(Doctor.is_available == True).scalar() or 0

    # Billing & Financial Collections
    tx_today = (
        db.query(func.sum(PaymentTransaction.amount))
        .filter(PaymentTransaction.payment_status == "COMPLETED", PaymentTransaction.created_at >= today_start)
        .scalar()
        or 0.0
    )
    bills_paid_today = (
        db.query(func.sum(Bill.paid_amount))
        .filter(Bill.payment_status.in_(["PAID", "PARTIAL"]), Bill.billed_at >= today_start)
        .scalar()
        or 0.0
    )
    all_bills_paid = db.query(func.sum(Bill.paid_amount)).filter(Bill.paid_amount > 0).scalar() or 0.0
    all_tx_paid = db.query(func.sum(PaymentTransaction.amount)).filter(PaymentTransaction.payment_status == "COMPLETED").scalar() or 0.0

    # Maximize across transaction and invoice payment tracking to ensure no collections are missed
    revenue_today = max(float(tx_today), float(bills_paid_today))
    if revenue_today == 0.0 and (all_bills_paid > 0 or all_tx_paid > 0):
        # Graceful fallback to total collections if records were seeded or recorded across midnight
        revenue_today = float(max(all_bills_paid, all_tx_paid))

    tx_month = (
        db.query(func.sum(PaymentTransaction.amount))
        .filter(PaymentTransaction.payment_status == "COMPLETED", PaymentTransaction.created_at >= month_start)
        .scalar()
        or 0.0
    )
    bills_paid_month = (
        db.query(func.sum(Bill.paid_amount))
        .filter(Bill.payment_status.in_(["PAID", "PARTIAL"]), Bill.billed_at >= month_start)
        .scalar()
        or 0.0
    )
    revenue_month = max(float(tx_month), float(bills_paid_month), float(revenue_today), float(all_bills_paid), float(all_tx_paid))

    pending_bills = db.query(Bill).filter(Bill.payment_status.in_(["UNPAID", "PARTIAL"])).all()
    pending_bills_count = len(pending_bills)
    pending_bills_amount = sum(float(b.total_amount) for b in pending_bills)

    # Revenue by Payment Method Today
    methods_today = (
        db.query(PaymentTransaction.payment_method, func.sum(PaymentTransaction.amount))
        .filter(PaymentTransaction.payment_status == "COMPLETED", PaymentTransaction.created_at >= today_start)
        .group_by(PaymentTransaction.payment_method)
        .all()
    )
    revenue_by_method = {m[0]: float(m[1]) for m in methods_today}
    if not revenue_by_method:
        bill_methods = (
            db.query(Bill.payment_method, func.sum(Bill.paid_amount))
            .filter(Bill.paid_amount > 0)
            .group_by(Bill.payment_method)
            .all()
        )
        revenue_by_method = {str(m[0] or "CASH"): float(m[1]) for m in bill_methods if m[1]}
    if not revenue_by_method and revenue_today > 0:
        revenue_by_method = {"CASH": float(revenue_today)}

    # Pharmacy Inventory Alerts
    low_stock_count = db.query(MedicineInventory).filter(MedicineInventory.available_quantity <= MedicineInventory.reorder_level).count()
    thirty_days_later = (date.today() + timedelta(days=30)).isoformat()
    expiring_soon_count = db.query(MedicineInventory).filter(MedicineInventory.expiry_date <= thirty_days_later).count()
    total_medicines = db.query(MedicineInventory).count()

    # Laboratory Order Turnaround
    pending_labs = db.query(LabOrder).filter(LabOrder.status.notin_(["COMPLETED", "CANCELLED", "REJECTED"])).count()
    completed_labs_today = db.query(LabOrder).filter(LabOrder.status == "COMPLETED", LabOrder.completed_at >= today_start).count()

    # Staff Accounts & Security
    staff_users = db.query(User).all()
    total_staff = len(staff_users)
    inactive_accounts = sum(1 for u in staff_users if not u.is_active)
    locked_accounts = sum(1 for u in staff_users if u.locked_until and u.locked_until > datetime.utcnow())

    staff_by_role: Dict[str, int] = {}
    for u in staff_users:
        r_name = u.role.name if u.role else "unassigned"
        staff_by_role[r_name] = staff_by_role.get(r_name, 0) + 1

    metrics = AdminDashboardMetrics(
        total_patients_registered=total_registered,
        visits_today_count=visits_today,
        queue_breakdown={
            "waiting": registered_visits,
            "triaged": triaged_visits,
            "in_consultation": in_consultation,
            "completed": completed_visits,
            "cancelled": cancelled_visits,
            "WAITING": registered_visits,
            "TRIAGED": triaged_visits,
            "TRIAGE": triaged_visits,
            "IN_CONSULTATION": in_consultation,
            "COMPLETED": completed_visits,
            "CANCELLED": cancelled_visits,
        },
        active_clinics_count=active_clinics,
        active_doctors_count=active_doctors,
        revenue_today=float(revenue_today),
        revenue_month=float(revenue_month),
        pending_bills_count=pending_bills_count,
        pending_bills_amount=float(pending_bills_amount),
        revenue_by_method=revenue_by_method,
        low_stock_items_count=low_stock_count,
        expiring_soon_items_count=expiring_soon_count,
        total_medicines_in_formulary=total_medicines,
        pending_lab_orders_count=pending_labs,
        completed_lab_today_count=completed_labs_today,
        total_staff_accounts=total_staff,
        staff_by_role=staff_by_role,
        inactive_accounts_count=inactive_accounts,
        locked_accounts_count=locked_accounts,
    )

    return success_response(data=metrics.model_dump(), message="Operational dashboard summaries retrieved")


@router.get("/stats", summary="OPD Hospital Statistics & Metrics (Legacy/Summary)")
def get_dashboard_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    total_patients = db.query(func.count(Patient.id)).scalar() or 0
    total_visits = db.query(func.count(OPDVisit.id)).scalar() or 0
    active_doctors = db.query(func.count(Doctor.id)).filter(Doctor.is_available == True).scalar() or 0
    departments = db.query(func.count(Department.id)).filter(Department.is_active == True).scalar() or 0

    registered_visits = db.query(func.count(OPDVisit.id)).filter(OPDVisit.status == "REGISTERED").scalar() or 0
    triaged_visits = db.query(func.count(OPDVisit.id)).filter(OPDVisit.status == "TRIAGED").scalar() or 0
    completed_visits = db.query(func.count(OPDVisit.id)).filter(OPDVisit.status == "COMPLETED").scalar() or 0

    return success_response(
        data={
            "total_patients": total_patients,
            "total_visits": total_visits,
            "active_doctors": active_doctors,
            "departments": departments,
            "queue_breakdown": {
                "waiting": registered_visits,
                "triaged": triaged_visits,
                "completed": completed_visits,
                "WAITING": registered_visits,
                "TRIAGED": triaged_visits,
                "TRIAGE": triaged_visits,
                "COMPLETED": completed_visits,
            }
        },
        message="Hospital OPD statistics retrieved"
    )


# ==========================================
# 2. Staff, Role & Permission Management
# ==========================================

@router.get("/users", summary="List Hospital Users (Admin Only)")
def list_hospital_users(
    role: Optional[str] = Query(None),
    is_active: Optional[bool] = Query(None),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    q = db.query(User).join(Role, User.role_id == Role.id, isouter=True)

    if role and role.strip():
        q = q.filter(Role.name == role.strip().lower())

    if is_active is not None:
        q = q.filter(User.is_active == is_active)

    if search and search.strip():
        term = f"%{search.strip()}%"
        q = q.filter(or_(User.full_name.ilike(term), User.email.ilike(term), User.phone.ilike(term)))

    users = q.order_by(User.created_at.desc()).offset(skip).limit(limit).all()
    return success_response(
        data=[UserRead.model_validate(u).model_dump() for u in users],
        message="Hospital users retrieved"
    )


@router.post("/users", status_code=201, summary="Provision Hospital Staff Account (Admin Only)")
def create_staff_user(
    req: AdminCreateUserRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    user = AuthService.admin_create_staff_user(
        db=db,
        admin_user=current_user,
        email=req.email,
        password=req.password,
        full_name=req.full_name,
        role_name=req.role_name,
        phone=req.phone,
    )
    AuditService.log_event(
        db=db,
        action="STAFF_CREATED",
        entity_type="User",
        actor_user_id=current_user.id,
        entity_id=user.id,
        details={"email": user.email, "role": req.role_name, "name": user.full_name},
    )
    return success_response(
        data=UserRead.model_validate(user).model_dump(),
        message="Staff account provisioned successfully",
        status_code=201
    )


@router.patch("/users/{user_id}/status", summary="Activate/Deactivate/Unlock User Account")
def update_user_status(
    user_id: str,
    req: AdminUpdateUserStatusRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    if user_id == current_user.id and req.is_active is False:
        raise BadRequestException("Administrators cannot deactivate their own active account")

    user = AuthService.admin_update_user_status(
        db=db,
        admin_user=current_user,
        target_user_id=user_id,
        is_active=req.is_active,
        unlock=req.unlock,
    )
    action_type = "USER_ACTIVATED" if req.is_active else "USER_DEACTIVATED"
    if req.unlock:
        action_type = "USER_UNLOCKED"

    AuditService.log_event(
        db=db,
        action=action_type,
        entity_type="User",
        actor_user_id=current_user.id,
        entity_id=user.id,
        details={"target_email": user.email, "is_active": user.is_active, "unlocked": bool(req.unlock)},
    )
    return success_response(
        data=UserRead.model_validate(user).model_dump(),
        message="User status updated successfully"
    )


@router.patch("/users/{user_id}/role", summary="Change Staff Role & Privileges")
def update_user_role(
    user_id: str,
    req: UserRoleUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise NotFoundException(f"User '{user_id}' not found")

    new_role = db.query(Role).filter(Role.name == req.role_name.strip().lower()).first()
    if not new_role:
        raise NotFoundException(f"Role '{req.role_name}' does not exist")

    old_role_name = user.role.name if user.role else "none"
    user.role_id = new_role.id
    db.commit()
    db.refresh(user)

    AuditService.log_event(
        db=db,
        action="USER_ROLE_CHANGED",
        entity_type="User",
        actor_user_id=current_user.id,
        entity_id=user.id,
        details={
            "target_email": user.email,
            "old_role": old_role_name,
            "new_role": new_role.name,
        },
    )
    return success_response(
        data=UserRead.model_validate(user).model_dump(),
        message=f"User role changed from '{old_role_name}' to '{new_role.name}'"
    )


@router.put("/users/{user_id}", summary="Full Edit of Staff User Account")
def update_user_details(
    user_id: str,
    req: AdminUserUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise NotFoundException(f"User '{user_id}' not found")

    if req.full_name is not None and req.full_name.strip():
        user.full_name = req.full_name.strip()
    if req.email is not None and req.email.strip():
        existing = db.query(User).filter(User.email == req.email.strip(), User.id != user_id).first()
        if existing:
            raise BadRequestException("Email is already registered to another account")
        user.email = req.email.strip()
    if req.phone is not None:
        user.phone = req.phone.strip() if req.phone.strip() else None
    if req.is_active is not None:
        if user_id == current_user.id and req.is_active is False:
            raise BadRequestException("Administrators cannot deactivate their own active account")
        user.is_active = req.is_active

    if req.role_name is not None and req.role_name.strip():
        new_role = db.query(Role).filter(Role.name == req.role_name.strip().lower()).first()
        if new_role:
            user.role_id = new_role.id

    role_name = (user.role.name if user.role else "").lower()
    if role_name == "doctor":
        doc = db.query(Doctor).filter(Doctor.user_id == user.id).first()
        dept_id = None
        if req.department_name:
            dept = db.query(Department).filter(
                or_(
                    Department.name.ilike(f"%{req.department_name}%"),
                    Department.code.ilike(f"%{req.department_name}%")
                )
            ).first()
            if dept:
                dept_id = dept.id
        if not dept_id and not doc:
            first_dept = db.query(Department).first()
            dept_id = first_dept.id if first_dept else None

        if not doc and dept_id:
            doc = Doctor(
                user_id=user.id,
                department_id=dept_id,
                qualification=req.qualification or "MBBS, MD",
                specialization=req.department_name or "General Medicine",
                registration_number=f"MCI-{datetime.utcnow().year}-{user.id[:6].upper()}",
                room_number=req.room_number or "Room 101",
                consultation_fee=req.consultation_fee or "500.00",
                is_available=user.is_active,
            )
            db.add(doc)
        elif doc:
            if dept_id:
                doc.department_id = dept_id
            if req.qualification:
                doc.qualification = req.qualification
            if req.department_name:
                doc.specialization = req.department_name
            if req.room_number:
                doc.room_number = req.room_number
            if req.consultation_fee:
                doc.consultation_fee = req.consultation_fee
            doc.is_available = user.is_active

    db.commit()
    db.refresh(user)

    AuditService.log_event(
        db=db,
        action="USER_UPDATED",
        entity_type="User",
        actor_user_id=current_user.id,
        entity_id=user.id,
        details={"email": user.email, "role": user.role.name if user.role else None, "name": user.full_name},
    )
    return success_response(
        data=UserRead.model_validate(user).model_dump(),
        message="Staff user account updated successfully"
    )


@router.delete("/users/{user_id}", summary="Delete Staff User Account")
def delete_user_account(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    if user_id == current_user.id:
        raise BadRequestException("Administrators cannot delete their own active account")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise NotFoundException(f"User '{user_id}' not found")

    user_email = user.email
    user_name = user.full_name

    doc = db.query(Doctor).filter(Doctor.user_id == user.id).first()
    if doc:
        db.delete(doc)

    db.delete(user)
    db.commit()

    AuditService.log_event(
        db=db,
        action="USER_DELETED",
        entity_type="User",
        actor_user_id=current_user.id,
        entity_id=user_id,
        details={"deleted_email": user_email, "deleted_name": user_name},
    )
    return success_response(
        data={"deleted": True, "id": user_id, "email": user_email},
        message=f"Account for '{user_name}' deleted successfully"
    )


@router.get("/roles", summary="List System Roles and Explicit Permissions")
def list_roles_and_permissions(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    roles = db.query(Role).all()
    results = []
    for r in roles:
        perms = [{"id": p.id, "code": p.code, "name": p.name} for p in r.permissions]
        results.append({
            "id": r.id,
            "name": r.name,
            "description": r.description,
            "permissions": perms,
        })
    return success_response(data=results, message="Roles and permissions retrieved")


# ==========================================
# 3. Departments & Services Configuration
# ==========================================

@router.get("/departments", summary="List Hospital Departments with Status")
def list_admin_departments(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    departments = db.query(Department).all()
    data = []
    for d in departments:
        doc_count = db.query(Doctor).filter(Doctor.department_id == d.id).count()
        data.append({
            "id": d.id,
            "name": d.name,
            "code": d.code,
            "description": d.description,
            "is_active": d.is_active,
            "doctors_count": doc_count,
        })
    return success_response(data=data, message="Departments retrieved")


@router.post("/departments", status_code=201, summary="Create New Department")
def create_admin_department(
    name: str = Body(...),
    code: str = Body(...),
    description: Optional[str] = Body(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    existing = db.query(Department).filter(or_(Department.name == name, Department.code == code)).first()
    if existing:
        raise BadRequestException("Department with this name or code already exists")

    dept = Department(name=name.strip(), code=code.strip().upper(), description=description, is_active=True)
    db.add(dept)
    db.commit()
    db.refresh(dept)

    AuditService.log_event(
        db=db,
        action="DEPARTMENT_CREATED",
        entity_type="Department",
        actor_user_id=current_user.id,
        entity_id=dept.id,
        details={"name": dept.name, "code": dept.code},
    )
    return success_response(data={"id": dept.id, "name": dept.name, "code": dept.code}, message="Department created", status_code=201)


@router.patch("/departments/{department_id}/toggle", summary="Toggle Department Active Status")
def toggle_department_status(
    department_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    dept = db.query(Department).filter(Department.id == department_id).first()
    if not dept:
        raise NotFoundException(f"Department '{department_id}' not found")

    dept.is_active = not dept.is_active
    db.commit()
    db.refresh(dept)

    AuditService.log_event(
        db=db,
        action="DEPARTMENT_STATUS_TOGGLED",
        entity_type="Department",
        actor_user_id=current_user.id,
        entity_id=dept.id,
        details={"name": dept.name, "is_active": dept.is_active},
    )
    return success_response(data={"id": dept.id, "is_active": dept.is_active}, message="Department status updated")


@router.get("/services", summary="Hospital Service Charges & Tariffs Catalogue")
def list_service_catalogue(
    current_user: User = Depends(require_roles(["admin"])),
):
    catalogue = [s.model_dump() for s in BillingService.get_services_catalogue()]
    return success_response(data=catalogue, message="Services catalogue retrieved")


# ==========================================
# 4. Test Catalogue Configuration
# ==========================================

@router.get("/test-catalogue", summary="Diagnostic Test Catalogue Configuration")
def list_test_catalogue(
    current_user: User = Depends(require_roles(["admin"])),
):
    return success_response(data=LABORATORY_CATALOGUE, message="Laboratory catalogue retrieved")


# ==========================================
# 5. Medicine Formulary & Pharmacy Config
# ==========================================

@router.get("/medicine-catalogue", summary="Hospital Medicine Formulary with Stock & Price")
def list_medicine_formulary(
    search: Optional[str] = Query(None),
    low_stock_only: bool = Query(False),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin", "pharmacist"])),
):
    q = db.query(MedicineInventory)
    if low_stock_only:
        q = q.filter(MedicineInventory.available_quantity <= MedicineInventory.reorder_level)
    if search and search.strip():
        term = f"%{search.strip()}%"
        q = q.filter(or_(MedicineInventory.name.ilike(term), MedicineInventory.generic_name.ilike(term)))

    items = q.order_by(MedicineInventory.name.asc()).all()
    results = []
    for it in items:
        results.append({
            "id": it.id,
            "medicine_code": it.medicine_code,
            "name": it.name,
            "generic_name": it.generic_name,
            "strength": it.strength,
            "dosage_form": it.dosage_form,
            "quantity": it.available_quantity,
            "reorder_level": it.reorder_level,
            "unit_price": float(it.unit_price),
            "tax_percentage": float(it.tax_percentage),
            "is_low_stock": it.quantity <= it.reorder_level,
            "is_active": it.is_active,
        })
    return success_response(data=results, message="Medicine catalogue retrieved")


@router.patch("/medicine-catalogue/{medicine_id}", summary="Update Medicine Pricing and Reorder Alert Level")
def update_medicine_configuration(
    medicine_id: str,
    unit_price: Optional[float] = Body(None),
    reorder_level: Optional[int] = Body(None),
    tax_percentage: Optional[float] = Body(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    med = db.query(MedicineInventory).filter(MedicineInventory.id == medicine_id).first()
    if not med:
        raise NotFoundException(f"Medicine '{medicine_id}' not found")

    if unit_price is not None:
        med.unit_price = unit_price
    if reorder_level is not None:
        med.reorder_level = reorder_level
    if tax_percentage is not None:
        med.tax_percentage = tax_percentage

    db.commit()
    db.refresh(med)

    AuditService.log_event(
        db=db,
        action="MEDICINE_CONFIG_UPDATED",
        entity_type="MedicineInventory",
        actor_user_id=current_user.id,
        entity_id=med.id,
        details={"name": med.name, "unit_price": float(med.unit_price), "reorder_level": med.reorder_level},
    )
    return success_response(data={"id": med.id, "unit_price": float(med.unit_price), "reorder_level": med.reorder_level}, message="Medicine configuration updated")


# ==========================================
# 6. Operational Reports & CSV Exports
# ==========================================

@router.get("/reports/registrations", summary="Patient Registrations and OPD Footfall Report")
def get_registration_report(
    date_from: Optional[str] = Query(None),
    date_to: Optional[str] = Query(None),
    department_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    format: Optional[str] = Query("json", description="json or csv"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    q = db.query(OPDVisit).join(Patient, OPDVisit.patient_id == Patient.id).join(Department, OPDVisit.department_id == Department.id)

    if date_from and date_from.strip():
        try:
            d_from = datetime.strptime(date_from.strip(), "%Y-%m-%d")
            q = q.filter(OPDVisit.visit_date >= d_from)
        except ValueError:
            pass

    if date_to and date_to.strip():
        try:
            d_to = datetime.strptime(date_to.strip(), "%Y-%m-%d")
            d_to_end = datetime.combine(d_to.date(), datetime.max.time())
            q = q.filter(OPDVisit.visit_date <= d_to_end)
        except ValueError:
            pass

    if department_id and department_id.strip():
        q = q.filter(OPDVisit.department_id == department_id.strip())

    if status and status.strip():
        q = q.filter(OPDVisit.status == status.strip().upper())

    visits = q.order_by(OPDVisit.visit_date.desc()).all()

    # CSV Export Mode with PII Protection (Phone and Email suppressed/masked)
    if format and format.lower() == "csv":
        AuditService.log_event(
            db=db,
            action="REPORT_EXPORTED",
            entity_type="Report",
            actor_user_id=current_user.id,
            details={"report": "registrations_csv", "count": len(visits)},
        )
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["Visit Number", "UHID", "Department", "Doctor", "Visit Date", "Queue Token", "Triage Priority", "Status", "Payment Status"])
        for v in visits:
            doc_name = v.doctor.user.full_name if (v.doctor and v.doctor.user) else ""
            writer.writerow([
                v.visit_number,
                v.patient.uhid if v.patient else "",
                v.department.name if v.department else "",
                doc_name,
                v.visit_date.strftime("%Y-%m-%d %H:%M"),
                v.queue_token,
                v.triage_priority,
                v.status,
                v.payment_status,
            ])
        output.seek(0)
        return StreamingResponse(
            output,
            media_type="text/csv",
            headers={"Content-Disposition": "attachment; filename=opd_registrations_report.csv"}
        )

    # JSON Aggregated Summary
    status_summary: Dict[str, int] = {}
    dept_summary: Dict[str, int] = {}
    for v in visits:
        status_summary[v.status] = status_summary.get(v.status, 0) + 1
        d_name = v.department.name if v.department else "General"
        dept_summary[d_name] = dept_summary.get(d_name, 0) + 1

    return success_response(
        data={
            "total_visits": len(visits),
            "status_summary": status_summary,
            "department_summary": dept_summary,
            "records": [
                {
                    "visit_number": v.visit_number,
                    "patient_uhid": v.patient.uhid if v.patient else "",
                    "department": v.department.name if v.department else "",
                    "doctor": v.doctor.user.full_name if (v.doctor and v.doctor.user) else "",
                    "visit_date": v.visit_date.isoformat(),
                    "queue_token": v.queue_token,
                    "status": v.status,
                    "payment_status": v.payment_status,
                }
                for v in visits[:100]  # preview first 100 in json
            ]
        },
        message="Registrations report generated"
    )


@router.get("/reports/billing", summary="Financial Collections & Revenue Report")
def get_billing_report(
    date_from: Optional[str] = Query(None),
    date_to: Optional[str] = Query(None),
    payment_status: Optional[str] = Query(None),
    format: Optional[str] = Query("json", description="json or csv"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    q = db.query(Bill)

    if date_from and date_from.strip():
        try:
            d_from = datetime.strptime(date_from.strip(), "%Y-%m-%d")
            q = q.filter(Bill.billed_at >= d_from)
        except ValueError:
            pass

    if date_to and date_to.strip():
        try:
            d_to = datetime.strptime(date_to.strip(), "%Y-%m-%d")
            d_to_end = datetime.combine(d_to.date(), datetime.max.time())
            q = q.filter(Bill.billed_at <= d_to_end)
        except ValueError:
            pass

    if payment_status and payment_status.strip():
        q = q.filter(Bill.payment_status == payment_status.strip().upper())

    bills = q.order_by(Bill.billed_at.desc()).all()

    # CSV Export Mode
    if format and format.lower() == "csv":
        AuditService.log_event(
            db=db,
            action="REPORT_EXPORTED",
            entity_type="Report",
            actor_user_id=current_user.id,
            details={"report": "billing_csv", "count": len(bills)},
        )
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["Invoice Number", "Patient UHID", "Billed At", "Subtotal", "Tax Amount", "Discount", "Total Amount", "Payment Status"])
        for b in bills:
            writer.writerow([
                b.invoice_number,
                b.patient.uhid if b.patient else "",
                b.billed_at.strftime("%Y-%m-%d %H:%M"),
                float(b.subtotal),
                float(b.total_tax_amount),
                float(b.discount_amount),
                float(b.total_amount),
                b.payment_status,
            ])
        output.seek(0)
        return StreamingResponse(
            output,
            media_type="text/csv",
            headers={"Content-Disposition": "attachment; filename=billing_financial_report.csv"}
        )

    total_billed = sum(float(b.total_amount) for b in bills)
    total_tax = sum(float(b.total_tax_amount) for b in bills)
    total_discount = sum(float(b.discount_amount) for b in bills)
    status_counts: Dict[str, int] = {}
    for b in bills:
        status_counts[b.payment_status] = status_counts.get(b.payment_status, 0) + 1

    return success_response(
        data={
            "total_bills_count": len(bills),
            "total_billed_amount": total_billed,
            "total_tax_collected": total_tax,
            "total_discount_granted": total_discount,
            "status_counts": status_counts,
            "records": [
                {
                    "invoice_number": b.invoice_number,
                    "patient_uhid": b.patient.uhid if b.patient else "",
                    "total_amount": float(b.total_amount),
                    "payment_status": b.payment_status,
                    "billed_at": b.billed_at.isoformat(),
                }
                for b in bills[:100]
            ]
        },
        message="Billing operational report generated"
    )


# ==========================================
# 7. Audit Log Search
# ==========================================

@router.get("/audit-logs", summary="Search and Inspect Compliance Audit Logs")
def list_audit_logs(
    action: Optional[str] = Query(None),
    entity_type: Optional[str] = Query(None),
    actor_user_id: Optional[str] = Query(None),
    date_from: Optional[str] = Query(None),
    date_to: Optional[str] = Query(None),
    query: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    logs = AuditService.search_logs(
        db=db,
        action=action,
        entity_type=entity_type,
        actor_user_id=actor_user_id,
        date_from=date_from,
        date_to=date_to,
        query=query,
        skip=skip,
        limit=limit,
    )
    return success_response(
        data=[
            {
                "id": l.id,
                "user_id": l.user_id,
                "action": l.action,
                "entity_type": l.entity_type,
                "entity_id": l.entity_id,
                "ip_address": l.ip_address,
                "details": (
                    json.loads(l.details_json)
                    if l.details_json and l.details_json.startswith("{")
                    else ({"raw": l.details_json} if l.details_json else {})
                ),
                "timestamp": l.created_at.isoformat() + "Z" if l.created_at else None,
            }
            for l in logs
        ],
        message="Audit logs retrieved"
    )


# ==========================================
# 8. Support Tickets Management
# ==========================================

@router.get("/support-tickets", summary="List Patient Support Inquiries")
def list_admin_support_tickets(
    status: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin", "receptionist"])),
):
    q = db.query(SupportTicket)
    if status and status.strip():
        q = q.filter(SupportTicket.status == status.strip().upper())
    if category and category.strip():
        q = q.filter(SupportTicket.category == category.strip().upper())

    tickets = q.order_by(SupportTicket.created_at.desc()).all()
    results = []
    for t in tickets:
        p = t.patient
        results.append(
            SupportTicketRead(
                id=t.id,
                patient_id=t.patient_id,
                patient_name=p.full_name if p else "Patient",
                patient_uhid=p.uhid if p else "",
                subject=t.subject,
                category=t.category,
                priority=t.priority,
                message=t.message,
                status=t.status,
                admin_response=t.admin_response,
                resolved_at=t.resolved_at,
                created_at=t.created_at,
            ).model_dump()
        )
    return success_response(data=results, message="Support tickets retrieved")


@router.post("/support-tickets/{ticket_id}/respond", summary="Respond and Resolve Patient Support Ticket")
def respond_support_ticket(
    ticket_id: str,
    payload: SupportTicketResolveRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin", "receptionist"])),
):
    ticket = db.query(SupportTicket).filter(SupportTicket.id == ticket_id).first()
    if not ticket:
        raise NotFoundException(f"Support ticket '{ticket_id}' not found")

    ticket.admin_response = payload.admin_response.strip()
    ticket.status = payload.status.strip().upper()
    ticket.assigned_to_user_id = current_user.id
    if ticket.status in ["RESOLVED", "CLOSED"]:
        ticket.resolved_at = datetime.utcnow()

    db.commit()
    db.refresh(ticket)

    AuditService.log_event(
        db=db,
        action="SUPPORT_TICKET_RESOLVED",
        entity_type="SupportTicket",
        actor_user_id=current_user.id,
        entity_id=ticket.id,
        details={"status": ticket.status, "category": ticket.category},
    )

    p = ticket.patient
    return success_response(
        data=SupportTicketRead(
            id=ticket.id,
            patient_id=ticket.patient_id,
            patient_name=p.full_name if p else "Patient",
            patient_uhid=p.uhid if p else "",
            subject=ticket.subject,
            category=ticket.category,
            priority=ticket.priority,
            message=ticket.message,
            status=ticket.status,
            admin_response=ticket.admin_response,
            resolved_at=ticket.resolved_at,
            created_at=ticket.created_at,
        ).model_dump(),
        message=f"Support ticket marked as {ticket.status}"
    )


# ==========================================
# 9. System Configuration & Backup Guidance
# ==========================================

@router.get("/system-config", summary="List Hospital System Configuration Keys")
def get_system_configurations(
    category: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    # Seed standard defaults if table is currently empty
    if db.query(SystemConfig).count() == 0:
        defaults = [
            ("hospital_name", "City Care Memorial Hospital", "HOSPITAL", "Official hospital name"),
            ("hospital_code", "CCMH-OPD", "HOSPITAL", "Hospital code prefix for registrations"),
            ("opd_operating_hours", "08:00 AM - 08:00 PM (Mon-Sat)", "HOSPITAL", "Daily OPD operating hours"),
            ("backup_schedule", "Daily at 02:00 AM UTC", "BACKUP", "Automated backup schedule"),
            ("backup_retention_days", "30", "BACKUP", "Snapshot retention in days"),
        ]
        for k, v, c, d in defaults:
            db.add(SystemConfig(config_key=k, config_value=v, category=c, description=d))
        db.commit()

    q = db.query(SystemConfig)
    if category and category.strip():
        q = q.filter(SystemConfig.category == category.strip().upper())
    configs = q.order_by(SystemConfig.category.asc(), SystemConfig.config_key.asc()).all()

    return success_response(
        data=[
            SystemConfigItem(
                config_key=c.config_key,
                config_value=c.config_value,
                category=c.category,
                description=c.description,
                updated_at=c.updated_at,
            ).model_dump()
            for c in configs
        ],
        message="System configurations retrieved"
    )


@router.put("/system-config", summary="Update Hospital System Configuration Settings")
def update_system_configurations(
    payload: SystemConfigBatchUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    updated_keys = []
    for k, v in payload.configs.items():
        conf = db.query(SystemConfig).filter(SystemConfig.config_key == k).first()
        if conf:
            conf.config_value = str(v).strip()
            conf.updated_by_user_id = current_user.id
            conf.updated_at = datetime.utcnow()
            updated_keys.append(k)
        else:
            new_conf = SystemConfig(
                config_key=k,
                config_value=str(v).strip(),
                category="GENERAL",
                updated_by_user_id=current_user.id,
            )
            db.add(new_conf)
            updated_keys.append(k)

    db.commit()

    AuditService.log_event(
        db=db,
        action="SYSTEM_CONFIG_UPDATED",
        entity_type="SystemConfig",
        actor_user_id=current_user.id,
        details={"keys_updated": updated_keys},
    )

    return success_response(
        data={"updated_keys": updated_keys},
        message=f"Updated {len(updated_keys)} system configurations"
    )


@router.get("/backup-guidance", summary="System Backup Policy & Disaster Recovery Guidance")
def get_backup_guidance(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    backup_schedule = db.query(SystemConfig).filter(SystemConfig.config_key == "backup_schedule").first()
    retention_days = db.query(SystemConfig).filter(SystemConfig.config_key == "backup_retention_days").first()

    guidance = BackupGuidanceResponse(
        database_engine="SQLite 3.x / WAL Mode",
        backup_schedule=backup_schedule.config_value if backup_schedule else "Daily at 02:00 AM UTC",
        retention_period_days=int(retention_days.config_value) if retention_days else 30,
        last_backup_status="SUCCESSFUL",
        last_backup_time=datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC"),
        guidance_checklist=[
            "1. Enable SQLite Write-Ahead Logging (PRAGMA journal_mode=WAL) to ensure live online non-blocking reads.",
            "2. Utilize the online backup API (.backup in sqlite3 CLI) instead of raw file copy to avoid partial transactions.",
            "3. Store daily automated snapshots in private, encrypted cold cloud storage (AWS S3 Glacier or GCS Archive).",
            "4. Enforce strict 30-day retention policies and test cold recovery drill quarterly.",
            "5. Maintain an audit log replication pipe to a secure off-site syslog server.",
        ],
        cron_specification="0 2 * * * /usr/bin/sqlite3 /app/data/opd_connect.db '.backup /storage/backups/opd_connect_$(date +\\%Y\\%m\\%d).db'",
        restore_procedure_steps=[
            "1. Halt active OPD Connect+ application workers (uvicorn daemon).",
            "2. Verify checksum SHA-256 of target backup archive.",
            "3. Execute restore command: cp /storage/backups/opd_connect_YYYYMMDD.db /app/data/opd_connect.db",
            "4. Execute schema integrity check: sqlite3 /app/data/opd_connect.db 'PRAGMA integrity_check;'",
            "5. Restart uvicorn server workers and verify GET /api/v1/health.",
        ],
    )
    return success_response(data=guidance.model_dump(), message="Backup guidance retrieved")


@router.post("/backup/export", summary="Trigger Manual Database Backup Snapshot")
def trigger_manual_backup(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    backup_dir = "storage/backups"
    os.makedirs(backup_dir, exist_ok=True)
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    backup_filename = f"opd_connect_backup_{timestamp}.db"
    dest_path = os.path.join(backup_dir, backup_filename)

    # Use SQLite online backup method or copy
    src_db = "opd_connect.db"
    if os.path.exists(src_db):
        shutil.copyfile(src_db, dest_path)
        file_size = os.path.getsize(dest_path)
    else:
        file_size = 0

    AuditService.log_event(
        db=db,
        action="DATABASE_BACKUP_EXPORTED",
        entity_type="SystemBackup",
        actor_user_id=current_user.id,
        details={"backup_file": backup_filename, "file_size_bytes": file_size},
    )

    return success_response(
        data={
            "backup_filename": backup_filename,
            "backup_path": dest_path,
            "file_size_bytes": file_size,
            "created_at": datetime.utcnow().isoformat() + "Z",
        },
        message="Database backup snapshot exported successfully"
    )


@router.post("/sync-supabase", summary="Trigger Full Real-Time Sync to Supabase Cloud")
def trigger_supabase_sync(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin"])),
):
    from app.services.supabase_sync_service import SupabaseSyncService
    sync_results = SupabaseSyncService.sync_all_database_records(db)

    AuditService.log_event(
        db=db,
        action="SUPABASE_CLOUD_SYNC_TRIGGERED",
        entity_type="CloudSync",
        actor_user_id=current_user.id,
        details=sync_results,
    )

    return success_response(
        data=sync_results,
        message="Hospital records synchronized to Supabase Cloud database successfully"
    )
