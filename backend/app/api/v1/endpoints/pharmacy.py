from datetime import datetime
from typing import Optional, List
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.responses import success_response
from app.core.dependencies import require_roles, get_current_user
from app.core.exceptions import NotFoundException, BadRequestException
from app.models.user import User
from app.schemas.pharmacy import (
    StockReceiptRequest,
    StockAdjustmentRequest,
    DispensePrescriptionRequest,
    PharmacyOrderCreate,
    PharmacyOrderRead,
)
from app.services.pharmacy_service import PharmacyService
from app.models.pharmacy import PharmacyOrder
from app.models.prescription import Prescription, PrescriptionItem

router = APIRouter()


@router.get("/inventory/stats", summary="Get Pharmacy Inventory Statistics")
def get_inventory_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["pharmacist", "admin"])),
):
    stats = PharmacyService.get_inventory_stats(db)
    return success_response(data=stats.model_dump(), message="Inventory stats retrieved")


@router.get("/inventory", summary="Search Pharmacy Inventory")
def search_inventory(
    query: Optional[str] = Query(None, description="Search by name, generic name, code, or batch"),
    dosage_form: Optional[str] = Query(None, description="Dosage form filter"),
    low_stock: Optional[bool] = Query(None, description="Filter for low stock items"),
    expiring_soon: Optional[bool] = Query(None, description="Filter for items expiring within 60 days"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["pharmacist", "admin", "doctor"])),
):
    results = PharmacyService.search_inventory(
        db,
        query=query,
        dosage_form=dosage_form,
        low_stock=low_stock,
        expiring_soon=expiring_soon,
        limit=limit,
        offset=offset,
    )
    return success_response(data=results, message="Inventory retrieved successfully")


@router.post("/inventory/receive", status_code=201, summary="Receive Stock into Inventory (Pharmacist/Admin Only)")
def receive_stock(
    payload: StockReceiptRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["pharmacist", "admin"])),
):
    inv = PharmacyService.receive_stock(db, payload, performed_by_user_id=current_user.id)
    return success_response(
        data={"id": inv.id, "medicine_code": inv.medicine_code, "available_quantity": inv.available_quantity},
        message=f"Received {payload.quantity} units of {inv.name} (Batch: {inv.batch_number})",
        status_code=201,
    )


@router.post("/inventory/adjust", summary="Adjust Stock Levels (Pharmacist/Admin Only)")
def adjust_stock(
    payload: StockAdjustmentRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["pharmacist", "admin"])),
):
    inv = PharmacyService.adjust_stock(db, payload, performed_by_user_id=current_user.id)
    return success_response(
        data={"id": inv.id, "name": inv.name, "available_quantity": inv.available_quantity},
        message=f"Stock adjusted for {inv.name}. New balance: {inv.available_quantity}",
    )


@router.get("/inventory/movements", summary="Get Stock Movement Audit Trail")
def get_stock_movements(
    inventory_id: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["pharmacist", "admin"])),
):
    movements = PharmacyService.get_stock_movements(db, inventory_id=inventory_id, limit=limit, offset=offset)
    return success_response(data=movements, message="Stock movements audit trail retrieved")


@router.get("/prescriptions", summary="Get Prescriptions Ready for Dispensing")
def get_prescriptions_for_dispensing(
    patient_id: Optional[str] = Query(None),
    visit_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["pharmacist", "admin"])),
):
    prescriptions = PharmacyService.get_prescriptions_for_dispensing(
        db, patient_id=patient_id, visit_id=visit_id
    )
    return success_response(data=prescriptions, message="Prescriptions retrieved for dispensing")


@router.post("/dispense", status_code=201, summary="Dispense Prescription Items with Real-time Stock Deduction")
def dispense_prescription(
    payload: DispensePrescriptionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["pharmacist", "admin"])),
):
    dispense = PharmacyService.dispense_prescription(db, payload, current_user=current_user)
    data = PharmacyService.get_dispense_by_id(db, dispense.id)
    return success_response(
        data=data,
        message=f"Dispensing {dispense.dispense_number} completed successfully",
        status_code=201,
    )


@router.get("/dispenses", summary="Get Traceable Dispensing History")
def get_dispenses(
    patient_id: Optional[str] = Query(None),
    visit_id: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["pharmacist", "admin"])),
):
    history = PharmacyService.get_dispenses(db, patient_id=patient_id, visit_id=visit_id, limit=limit, offset=offset)
    return success_response(data=history, message="Dispensing history retrieved")


@router.get("/dispenses/{dispense_id}", summary="Get Single Dispensing Record")
def get_dispense_detail(
    dispense_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["pharmacist", "admin", "doctor"])),
):
    data = PharmacyService.get_dispense_by_id(db, dispense_id)
    if not data:
        raise NotFoundException(f"Dispensing record '{dispense_id}' not found")
    return success_response(data=data, message="Dispensing record retrieved")


# Backwards compatibility endpoints
@router.post("/orders", summary="Create Pharmacy Dispensing Order")
def create_pharmacy_order(
    order_in: PharmacyOrderCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["pharmacist", "admin"])),
):
    rx = db.query(Prescription).filter(Prescription.id == order_in.prescription_id).first()
    if not rx:
        raise NotFoundException(f"Prescription '{order_in.prescription_id}' not found")

    order = PharmacyOrder(
        prescription_id=rx.id,
        dispensed_by_user_id=current_user.id,
        status="PENDING",
        total_amount=0.0,
        notes=order_in.notes,
    )
    db.add(order)
    db.commit()
    db.refresh(order)
    return success_response(
        data=PharmacyOrderRead.model_validate(order).model_dump(),
        message="Pharmacy dispensing order created",
        status_code=201,
    )


@router.patch("/orders/{order_id}/dispense", summary="Mark Pharmacy Order as Dispensed")
def dispense_order(
    order_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["pharmacist", "admin"])),
):
    order = db.query(PharmacyOrder).filter(PharmacyOrder.id == order_id).first()
    if not order:
        raise NotFoundException(f"Pharmacy order '{order_id}' not found")

    order.status = "DISPENSED"
    order.dispensed_by_user_id = current_user.id
    order.dispensed_at = datetime.utcnow()

    db.query(PrescriptionItem).filter(
        PrescriptionItem.prescription_id == order.prescription_id
    ).update({"is_dispensed": True})

    db.commit()
    db.refresh(order)
    return success_response(
        data=PharmacyOrderRead.model_validate(order).model_dump(),
        message="Medicines marked as dispensed",
    )
