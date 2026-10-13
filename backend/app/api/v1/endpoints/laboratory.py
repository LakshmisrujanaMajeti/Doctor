from datetime import datetime, date
from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func

from app.core.database import get_db
from app.core.responses import success_response
from app.core.dependencies import get_current_user, require_roles, verify_patient_access
from app.core.exceptions import NotFoundException, ForbiddenException, BadRequestException
from app.models.laboratory import LabOrder, LabResult
from app.models.visit import OPDVisit
from app.models.patient import Patient
from app.models.user import User
from app.schemas.laboratory import (
    LabCatalogueItem,
    LabOrderCreate,
    LabOrderRead,
    LabResultCreate,
    LabResultBatchCreate,
    LabResultRead,
    SpecimenCollectionRequest,
    SpecimenReceiveRequest,
    SpecimenRejectRequest,
    LabOrderVerifyRequest,
    LabReportData,
    LabDashboardStats,
)
from app.services.laboratory_service import LaboratoryService, LABORATORY_CATALOGUE

router = APIRouter()


@router.get("/catalogue", summary="Get Laboratory Test Catalogue (Strictly from OPD Booklet)")
def get_laboratory_catalogue(
    category: Optional[str] = Query(None, description="Optional category filter (BIOCHEMISTRY, HAEMATOLOGY, MICROBIOLOGY)"),
    current_user: User = Depends(get_current_user),
):
    catalogue = LaboratoryService.get_catalogue(category=category)
    return success_response(
        data=catalogue,
        message="Laboratory catalogue retrieved successfully"
    )


@router.get("/dashboard-stats", summary="Get Laboratory Queue Dashboard Metrics")
def get_laboratory_dashboard_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["laboratory", "lab_tech", "admin", "doctor"])),
):
    today_start = datetime.combine(date.today(), datetime.min.time())

    pending_collection = db.query(LabOrder).filter(
        LabOrder.specimen_status == "PENDING_COLLECTION",
        LabOrder.status.notin_(["CANCELLED", "REJECTED"])
    ).count()

    received_processing = db.query(LabOrder).filter(
        LabOrder.specimen_status.in_(["RECEIVED", "PROCESSING"]),
        LabOrder.status.notin_(["CANCELLED", "REJECTED", "COMPLETED"])
    ).count()

    pending_verification = db.query(LabOrder).filter(
        LabOrder.status == "PROCESSING",
        LabOrder.results.any()
    ).count()

    completed_today = db.query(LabOrder).filter(
        LabOrder.status == "COMPLETED",
        LabOrder.completed_at >= today_start
    ).count()

    rejected_count = db.query(LabOrder).filter(
        LabOrder.status == "REJECTED"
    ).count()

    sensitive_tests_count = db.query(LabOrder).filter(
        LabOrder.is_sensitive == True
    ).count()

    stats = {
        "pending_collection_count": pending_collection,
        "received_processing_count": received_processing,
        "pending_verification_count": pending_verification,
        "completed_today_count": completed_today,
        "rejected_count": rejected_count,
        "sensitive_tests_count": sensitive_tests_count,
    }
    return success_response(data=stats, message="Laboratory dashboard stats retrieved")


@router.get("/orders", summary="Query Laboratory Orders (With Search, Department & Status Filters)")
def list_laboratory_orders(
    search: Optional[str] = Query(None, description="Search by patient name, UHID, order number, specimen ID, or test name"),
    category: Optional[str] = Query(None, description="Filter by BIOCHEMISTRY, HAEMATOLOGY, MICROBIOLOGY"),
    status: Optional[str] = Query(None, description="Filter by ORDERED, COLLECTED, RECEIVED, PROCESSING, COMPLETED, REJECTED"),
    specimen_status: Optional[str] = Query(None, description="Filter by specimen status"),
    date_from: Optional[str] = Query(None, description="Start date (YYYY-MM-DD)"),
    date_to: Optional[str] = Query(None, description="End date (YYYY-MM-DD)"),
    is_sensitive: Optional[bool] = Query(None, description="Filter for sensitive tests"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user_role = (current_user.role.name if current_user.role else "").lower()
    if user_role in ["receptionist", "pharmacist"]:
        raise ForbiddenException("Access to laboratory orders queue is restricted for this role")

    query = db.query(LabOrder).join(Patient, LabOrder.patient_id == Patient.id)

    # Patient role can only view their own non-rejected, published orders
    if user_role == "patient":
        query = query.filter(LabOrder.patient_id == current_user.patient_profile.id if current_user.patient_profile else False)
        query = query.filter(LabOrder.published_to_visit == True)

    if category and category.strip():
        query = query.filter(LabOrder.test_category == category.strip().upper())

    if status and status.strip():
        query = query.filter(LabOrder.status == status.strip().upper())

    if specimen_status and specimen_status.strip():
        query = query.filter(LabOrder.specimen_status == specimen_status.strip().upper())

    if is_sensitive is not None:
        query = query.filter(LabOrder.is_sensitive == is_sensitive)

    if date_from and date_from.strip():
        try:
            d_from = datetime.strptime(date_from.strip(), "%Y-%m-%d")
            query = query.filter(LabOrder.ordered_at >= d_from)
        except ValueError:
            pass

    if date_to and date_to.strip():
        try:
            d_to = datetime.strptime(date_to.strip(), "%Y-%m-%d")
            d_to_end = datetime.combine(d_to.date(), datetime.max.time())
            query = query.filter(LabOrder.ordered_at <= d_to_end)
        except ValueError:
            pass

    if search and search.strip():
        term = f"%{search.strip()}%"
        query = query.filter(
            or_(
                LabOrder.order_number.ilike(term),
                LabOrder.specimen_id.ilike(term),
                LabOrder.test_name.ilike(term),
                Patient.full_name.ilike(term),
                Patient.uhid.ilike(term),
            )
        )

    orders = query.order_by(LabOrder.ordered_at.desc()).all()

    # Filter out sensitive tests if unauthorized
    visible_orders = []
    for o in orders:
        if o.is_sensitive:
            try:
                LaboratoryService.enforce_sensitive_access(o, current_user)
                visible_orders.append(LaboratoryService.serialize_order(o))
            except ForbiddenException:
                continue
        else:
            visible_orders.append(LaboratoryService.serialize_order(o))

    return success_response(
        data=visible_orders,
        message=f"Retrieved {len(visible_orders)} laboratory orders"
    )


@router.post("/orders", summary="Create Lab Test Order (Doctor/Admin Only)")
def create_lab_order(
    order_in: LabOrderCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["doctor", "admin"])),
):
    order = LaboratoryService.create_order(
        db=db,
        visit_id=order_in.visit_id,
        test_name=order_in.test_name,
        test_category=order_in.test_category,
        clinical_indication=order_in.clinical_indication,
        priority=order_in.priority or "ROUTINE",
    )
    return success_response(
        data=LaboratoryService.serialize_order(order),
        message=f"Laboratory investigation '{order.test_name}' ordered successfully (Order #{order.order_number})",
        status_code=201
    )


@router.get("/orders/{id}", summary="Get Lab Order Details")
def get_lab_order_details(
    id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = db.query(LabOrder).filter(LabOrder.id == id).first()
    if not order:
        raise NotFoundException(f"Lab order '{id}' not found")

    LaboratoryService.enforce_sensitive_access(order, current_user)

    return success_response(
        data=LaboratoryService.serialize_order(order),
        message="Lab order details retrieved"
    )


@router.post("/orders/{id}/collect", summary="Record Specimen Collection (Lab Staff / Admin)")
def collect_specimen(
    id: str,
    specimen_in: SpecimenCollectionRequest = SpecimenCollectionRequest(),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["laboratory", "lab_tech", "admin"])),
):
    collector_name = specimen_in.collector_name or current_user.full_name or "Phlebotomist / Lab Staff"
    order = LaboratoryService.collect_specimen(
        db=db,
        order_id=id,
        specimen_type=specimen_in.specimen_type,
        collector_name=collector_name,
        collection_time=specimen_in.collection_time,
    )
    return success_response(
        data=LaboratoryService.serialize_order(order),
        message=f"Specimen collected for order #{order.order_number} ({order.specimen_id})"
    )


@router.post("/orders/{id}/receive", summary="Record Specimen Received in Lab (Lab Staff / Admin)")
def receive_specimen(
    id: str,
    receive_in: SpecimenReceiveRequest = SpecimenReceiveRequest(),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["laboratory", "lab_tech", "admin"])),
):
    receiver_name = receive_in.receiver_name or current_user.full_name or "Lab Reception / Technician"
    order = LaboratoryService.receive_specimen(
        db=db,
        order_id=id,
        receiver_name=receiver_name,
    )
    return success_response(
        data=LaboratoryService.serialize_order(order),
        message=f"Specimen received in lab for order #{order.order_number}"
    )


@router.post("/orders/{id}/reject", summary="Reject Lab Specimen (Lab Staff / Admin)")
def reject_specimen(
    id: str,
    reject_in: SpecimenRejectRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["laboratory", "lab_tech", "admin"])),
):
    order = LaboratoryService.reject_specimen(
        db=db,
        order_id=id,
        reason=reject_in.rejection_reason,
    )
    return success_response(
        data=LaboratoryService.serialize_order(order),
        message=f"Specimen rejected for order #{order.order_number}. Reason: {reject_in.rejection_reason}"
    )


@router.post("/orders/{id}/results", summary="Record Test Results for Lab Order (Lab Staff / Admin)")
def record_results_for_order(
    id: str,
    results_in: LabResultBatchCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["laboratory", "lab_tech", "admin"])),
):
    results_list = [r.model_dump() for r in results_in.results]
    order = LaboratoryService.record_results(
        db=db,
        order_id=id,
        results_data=results_list,
        current_user=current_user,
    )
    return success_response(
        data=LaboratoryService.serialize_order(order),
        message=f"Results recorded for order #{order.order_number}. Status updated to {order.status}."
    )


@router.post("/orders/{id}/verify", summary="Verify and Authorize Lab Report (Lab Staff / Admin)")
def verify_lab_order(
    id: str,
    verify_in: LabOrderVerifyRequest = LabOrderVerifyRequest(),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["laboratory", "lab_tech", "admin"])),
):
    order = LaboratoryService.verify_results(
        db=db,
        order_id=id,
        current_user=current_user,
        notes=verify_in.verification_notes,
    )
    return success_response(
        data=LaboratoryService.serialize_order(order),
        message=f"Laboratory order #{order.order_number} verified and authorized for publishing!"
    )


@router.get("/orders/{id}/report", summary="Generate Printable Laboratory Report")
def get_printable_laboratory_report(
    id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    report_data = LaboratoryService.build_printable_report(
        db=db,
        order_id=id,
        current_user=current_user,
    )
    return success_response(
        data=report_data,
        message="Laboratory report data generated successfully"
    )


@router.get("/visit/{visit_id}", summary="Get Lab Orders for Patient Visit")
def get_lab_orders_by_visit(
    visit_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    visit = db.query(OPDVisit).filter(OPDVisit.id == visit_id).first()
    if not visit:
        raise NotFoundException(f"Visit '{visit_id}' not found")

    user_role = (current_user.role.name if current_user.role else "").lower()
    if user_role in ["receptionist", "pharmacist"]:
        raise ForbiddenException("Access to laboratory orders is restricted for this role")

    if user_role == "patient":
        verify_patient_access(patient_id=visit.patient_id, current_user=current_user, db=db)

    orders = db.query(LabOrder).filter(LabOrder.visit_id == visit_id).all()

    visible_orders = []
    for o in orders:
        if o.is_sensitive:
            try:
                LaboratoryService.enforce_sensitive_access(o, current_user)
                visible_orders.append(LaboratoryService.serialize_order(o))
            except ForbiddenException:
                continue
        else:
            visible_orders.append(LaboratoryService.serialize_order(o))

    return success_response(
        data=visible_orders,
        message="Lab orders retrieved successfully"
    )


@router.post("/results", summary="Single Result Entry (Backwards Compatibility)")
def record_lab_result(
    result_in: LabResultCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lab_tech", "laboratory", "admin"])),
):
    order = db.query(LabOrder).filter(LabOrder.id == result_in.lab_order_id).first()
    if not order:
        raise NotFoundException(f"Lab order '{result_in.lab_order_id}' not found")

    flag = "CRITICAL" if result_in.is_critical else ("ABNORMAL" if result_in.is_abnormal else "NORMAL")
    result = LabResult(
        lab_order_id=order.id,
        verified_by_user_id=current_user.id,
        parameter_name=result_in.parameter_name,
        result_value=result_in.result_value,
        unit=result_in.unit,
        reference_range=result_in.reference_range,
        is_abnormal=result_in.is_abnormal,
        is_critical=result_in.is_critical,
        flag=flag,
        notes=result_in.notes,
        reported_at=datetime.utcnow(),
    )
    db.add(result)
    order.status = "COMPLETED"
    order.completed_at = datetime.utcnow()
    order.published_to_visit = True
    db.commit()
    db.refresh(result)

    return success_response(
        data=LabResultRead.model_validate(result).model_dump(),
        message="Lab result recorded successfully",
        status_code=201
    )
