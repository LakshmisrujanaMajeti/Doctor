from datetime import datetime
from typing import Optional, List
from fastapi import APIRouter, Depends, Query, Header
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.responses import success_response
from app.core.dependencies import require_roles, get_current_user, verify_patient_access
from app.core.exceptions import NotFoundException, BadRequestException
from app.core.idempotency import idempotency_manager
from app.models.user import User
from app.models.billing import Bill
from app.schemas.billing import (
    BillCreate,
    PaymentCreateRequest,
    PaymentCallbackRequest,
    PaymentRefundRequest,
    BillCancellationRequest,
)
from app.services.billing_service import BillingService

router = APIRouter()


@router.get("/services-catalogue", summary="Get Configured Hospital Services Catalogue")
def get_services_catalogue(
    current_user: User = Depends(get_current_user),
):
    catalogue = BillingService.get_services_catalogue()
    return success_response(
        data=[c.model_dump() for c in catalogue],
        message="Hospital services catalogue retrieved",
    )


@router.post("", status_code=201, summary="Generate Itemized Bill (Billing/Receptionist/Pharmacist/Admin)")
def create_bill(
    payload: BillCreate,
    x_idempotency_key: Optional[str] = Header(None, alias="X-Idempotency-Key"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["receptionist", "pharmacist", "admin", "billing"])),
):
    can_proceed, cached_resp, status_code = idempotency_manager.acquire(
        key=x_idempotency_key,
        user_id=str(current_user.id),
        endpoint="/api/v1/billing",
        payload=payload.model_dump(),
    )
    if not can_proceed and cached_resp is not None:
        return JSONResponse(content=cached_resp, status_code=status_code)

    try:
        bill = BillingService.create_bill(db, payload, current_user=current_user)
        serialized = BillingService.serialize_bill(bill)
        resp_body = {
            "status": "success",
            "data": serialized,
            "message": f"Invoice {bill.invoice_number} created successfully",
            "error": None,
        }
        idempotency_manager.store_result(
            key=x_idempotency_key,
            user_id=str(current_user.id),
            response_data=resp_body,
            status_code=201,
        )
        return success_response(
            data=serialized,
            message=resp_body["message"],
            status_code=201,
        )
    except Exception:
        idempotency_manager.mark_failed(key=x_idempotency_key, user_id=str(current_user.id))
        raise


@router.get("", summary="List Invoices with Filters")
def get_bills(
    patient_id: Optional[str] = Query(None),
    visit_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    payment_status: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user_role = (current_user.role.name if current_user.role else "").lower()
    if user_role == "patient":
        # Patients can only see their own bills
        patient_id = current_user.id # or verify_patient_access

    bills = BillingService.get_bills(
        db,
        patient_id=patient_id,
        visit_id=visit_id,
        status=status,
        payment_status=payment_status,
        limit=limit,
        offset=offset,
    )
    return success_response(data=bills, message="Bills retrieved successfully")


@router.get("/{bill_id}", summary="Get Bill Details with Items and Receipts")
def get_bill_detail(
    bill_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    bill_data = BillingService.get_bill_by_id(db, bill_id)
    if not bill_data:
        raise NotFoundException(f"Bill '{bill_id}' not found")

    user_role = (current_user.role.name if current_user.role else "").lower()
    if user_role == "patient":
        verify_patient_access(patient_id=bill_data["patient_id"], current_user=current_user, db=db)

    return success_response(data=bill_data, message="Bill details retrieved")


@router.get("/visit/{visit_id}", summary="Get Bills for OPD Visit")
def get_bills_by_visit(
    visit_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    bills = BillingService.get_bills(db, visit_id=visit_id)
    if bills and (current_user.role.name if current_user.role else "").lower() == "patient":
        verify_patient_access(patient_id=bills[0]["patient_id"], current_user=current_user, db=db)
    return success_response(data=bills, message="Invoices retrieved for visit")


@router.post("/{bill_id}/payments", status_code=201, summary="Record Payment on Invoice")
def record_payment(
    bill_id: str,
    payload: PaymentCreateRequest,
    x_idempotency_key: Optional[str] = Header(None, alias="X-Idempotency-Key"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["receptionist", "pharmacist", "admin", "patient", "billing"])),
):
    can_proceed, cached_resp, status_code = idempotency_manager.acquire(
        key=x_idempotency_key,
        user_id=str(current_user.id),
        endpoint=f"/api/v1/billing/{bill_id}/payments",
        payload=payload.model_dump(),
    )
    if not can_proceed and cached_resp is not None:
        return JSONResponse(content=cached_resp, status_code=status_code)

    try:
        payment = BillingService.record_payment(db, bill_id, payload, current_user=current_user)
        bill_data = BillingService.get_bill_by_id(db, bill_id)
        resp_data = {
            "receipt_number": payment.receipt_number,
            "payment_status": payment.payment_status,
            "amount": float(payment.amount),
            "is_online": payment.is_online,
            "gateway_order_id": payment.gateway_order_id,
            "bill": bill_data,
        }
        msg = "Payment processed" if payment.payment_status == "COMPLETED" else "Online payment initiated"
        resp_body = {
            "status": "success",
            "data": resp_data,
            "message": msg,
            "error": None,
        }
        idempotency_manager.store_result(
            key=x_idempotency_key,
            user_id=str(current_user.id),
            response_data=resp_body,
            status_code=201,
        )
        return success_response(
            data=resp_data,
            message=msg,
            status_code=201,
        )
    except Exception:
        idempotency_manager.mark_failed(key=x_idempotency_key, user_id=str(current_user.id))
        raise


@router.post("/payments/callback", summary="Confirm Online Payment via Webhook/Callback")
def payment_callback(
    payload: PaymentCallbackRequest,
    db: Session = Depends(get_db),
):
    # Public or signed webhook endpoint for payment gateway callbacks
    payment = BillingService.process_online_callback(db, payload)
    return success_response(
        data={
            "receipt_number": payment.receipt_number,
            "payment_status": payment.payment_status,
            "gateway_payment_id": payment.gateway_payment_id,
            "idempotency_key": payment.idempotency_key,
        },
        message="Payment callback reconciled successfully",
    )


@router.post("/{bill_id}/refund", summary="Process Refund according to Hospital Policy")
def process_refund(
    bill_id: str,
    payload: PaymentRefundRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin", "receptionist", "billing"])),
):
    refund_tx = BillingService.process_refund(db, bill_id, payload, current_user=current_user)
    bill_data = BillingService.get_bill_by_id(db, bill_id)
    return success_response(
        data={
            "refund_receipt": refund_tx.receipt_number,
            "refund_amount": float(refund_tx.refund_amount),
            "bill": bill_data,
        },
        message="Refund issued successfully",
    )


@router.post("/{bill_id}/cancel", summary="Cancel Invoice (Admin/Receptionist/Billing Only)")
def cancel_bill(
    bill_id: str,
    payload: BillCancellationRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["admin", "receptionist", "billing"])),
):
    bill = BillingService.cancel_bill(db, bill_id, reason=payload.reason, current_user=current_user)
    bill_data = BillingService.serialize_bill(bill)
    return success_response(
        data=bill_data,
        message=f"Invoice {bill.invoice_number} has been cancelled",
    )


@router.get("/{bill_id}/receipt", summary="Get Printable Itemized Invoice Receipt")
def get_printable_receipt(
    bill_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    bill_data = BillingService.get_bill_by_id(db, bill_id)
    if not bill_data:
        raise NotFoundException(f"Bill '{bill_id}' not found")

    receipt = {
        "hospital_name": "OPD CONNECT+ HOSPITAL",
        "hospital_tagline": "Connected Care. Smarter Health.",
        "hospital_address": "General Hospital Campus, Medical Enclave",
        "hospital_phone": "+1-555-OPD-CARE",
        "hospital_gstin": "36AAACH1234F1Z5",
        "is_synthetic_pricing": True,
        "pricing_disclaimer": "DEVELOPMENT DEMONSTRATION: Synthetic fee schedules and tax classification.",
        "bill": bill_data,
    }
    return success_response(data=receipt, message="Printable receipt generated")
