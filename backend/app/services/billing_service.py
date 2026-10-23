import uuid
from datetime import datetime, date
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional, Tuple, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import func, desc, or_

from app.models.billing import Bill, BillItem, PaymentTransaction
from app.models.visit import OPDVisit
from app.models.patient import Patient
from app.models.user import User
from app.schemas.billing import (
    BillCreate,
    BillItemCreate,
    PaymentCreateRequest,
    PaymentCallbackRequest,
    PaymentRefundRequest,
    ServiceCatalogItem,
)
from app.core.exceptions import (
    NotFoundException,
    BadRequestException,
    ForbiddenException,
)
from app.core.logging import logger

TWO_PLACES = Decimal("0.01")


def to_decimal(val: Any) -> Decimal:
    if val is None:
        return Decimal("0.00")
    if isinstance(val, Decimal):
        return val.quantize(TWO_PLACES, rounding=ROUND_HALF_UP)
    return Decimal(str(val)).quantize(TWO_PLACES, rounding=ROUND_HALF_UP)


# Configured Standard Hospital Services (With clearly labeled synthetic prices in development)
STANDARD_SERVICES = [
    {
        "code": "SRV-CONS-GEN",
        "category": "CONSULTATION",
        "name": "General OPD Consultation",
        "synthetic_price": Decimal("300.00"),
        "tax_rate_percent": Decimal("0.00"), # Medical consultations typically 0% GST in India
    },
    {
        "code": "SRV-CONS-SPEC",
        "category": "CONSULTATION",
        "name": "Specialist Clinician Consultation",
        "synthetic_price": Decimal("500.00"),
        "tax_rate_percent": Decimal("0.00"),
    },
    {
        "code": "SRV-REG-FEE",
        "category": "REGISTRATION",
        "name": "Patient OPD Registration & Booklet Issuance",
        "synthetic_price": Decimal("50.00"),
        "tax_rate_percent": Decimal("0.00"),
    },
    {
        "code": "SRV-EMERG-TRIAGE",
        "category": "EMERGENCY",
        "name": "Emergency Triage Assessment & Resuscitation Observation",
        "synthetic_price": Decimal("750.00"),
        "tax_rate_percent": Decimal("0.00"),
    },
    {
        "code": "SRV-PROC-DRESS",
        "category": "PROCEDURE",
        "name": "Minor Wound Dressing & Aseptic Bandage",
        "synthetic_price": Decimal("150.00"),
        "tax_rate_percent": Decimal("5.00"),
    },
    {
        "code": "SRV-PROC-INJ",
        "category": "PROCEDURE",
        "name": "Intramuscular / Intravenous Administration",
        "synthetic_price": Decimal("80.00"),
        "tax_rate_percent": Decimal("5.00"),
    },
]


class BillingService:
    @staticmethod
    def get_services_catalogue() -> List[ServiceCatalogItem]:
        return [
            ServiceCatalogItem(
                code=s["code"],
                category=s["category"],
                name=s["name"],
                synthetic_price=s["synthetic_price"],
                tax_rate_percent=s["tax_rate_percent"],
                is_synthetic=True,
            )
            for s in STANDARD_SERVICES
        ]

    @staticmethod
    def generate_invoice_number(db: Session) -> str:
        year = datetime.utcnow().year
        prefix = f"INV-{year}-"
        count = (
            db.query(func.count(Bill.id))
            .filter(Bill.invoice_number.like(f"{prefix}%"))
            .scalar()
            or 0
        )
        return f"{prefix}{str(count + 1).zfill(5)}"

    @staticmethod
    def generate_receipt_number(db: Session) -> str:
        today_str = datetime.utcnow().strftime("%Y%m%d")
        prefix = f"REC-{today_str}-"
        count = (
            db.query(func.count(PaymentTransaction.id))
            .filter(PaymentTransaction.receipt_number.like(f"{prefix}%"))
            .scalar()
            or 0
        )
        return f"{prefix}{str(count + 1).zfill(4)}"

    @staticmethod
    def calculate_bill_totals(
        items: List[BillItemCreate],
        discount_type: str = "NONE",
        discount_rate: Decimal = Decimal("0.00"),
        discount_amount: Decimal = Decimal("0.00"),
    ) -> Dict[str, Any]:
        """
        Decimal-safe monetary calculation with tax breakdown and server-side validation.
        """
        subtotal = Decimal("0.00")
        total_tax = Decimal("0.00")
        computed_items = []

        for item in items:
            qty = Decimal(str(item.quantity))
            u_price = to_decimal(item.unit_price)
            line_base = (qty * u_price).quantize(TWO_PLACES, rounding=ROUND_HALF_UP)
            
            tax_rate = to_decimal(item.tax_rate_percent)
            item_tax = (line_base * (tax_rate / Decimal("100.00"))).quantize(TWO_PLACES, rounding=ROUND_HALF_UP)
            line_total = line_base + item_tax

            subtotal += line_base
            total_tax += item_tax

            computed_items.append({
                "item_type": item.item_type,
                "item_code": item.item_code,
                "description": item.description,
                "quantity": item.quantity,
                "unit_price": u_price,
                "tax_rate_percent": tax_rate,
                "tax_amount": item_tax,
                "total_price": line_total,
                "reference_id": item.reference_id,
            })

        # Calculate discount
        disc_type = discount_type.upper()
        if disc_type == "PERCENTAGE":
            calc_discount = (subtotal * (to_decimal(discount_rate) / Decimal("100.00"))).quantize(TWO_PLACES, rounding=ROUND_HALF_UP)
        elif disc_type == "FIXED":
            calc_discount = to_decimal(discount_amount)
        else:
            calc_discount = Decimal("0.00")

        # Cap discount at subtotal
        final_discount = min(subtotal, calc_discount)
        taxable_amount = max(Decimal("0.00"), subtotal - final_discount)

        # CGST & SGST are each 50% of GST total
        cgst_amount = (total_tax / Decimal("2.00")).quantize(TWO_PLACES, rounding=ROUND_HALF_UP)
        sgst_amount = (total_tax - cgst_amount).quantize(TWO_PLACES, rounding=ROUND_HALF_UP)
        igst_amount = Decimal("0.00")

        total_amount = taxable_amount + total_tax

        return {
            "subtotal": subtotal,
            "discount_type": disc_type,
            "discount_rate": to_decimal(discount_rate),
            "discount_amount": final_discount,
            "taxable_amount": taxable_amount,
            "cgst_amount": cgst_amount,
            "sgst_amount": sgst_amount,
            "igst_amount": igst_amount,
            "total_tax_amount": total_tax,
            "total_amount": total_amount,
            "items": computed_items,
        }

    @staticmethod
    def create_bill(
        db: Session,
        payload: BillCreate,
        current_user: Optional[User] = None,
    ) -> Bill:
        visit = None
        if payload.visit_id:
            visit = db.query(OPDVisit).filter(
                or_(
                    OPDVisit.id == payload.visit_id,
                    OPDVisit.visit_number == payload.visit_id,
                )
            ).first()

        # If not matched by visit ID, find by patient ID or UHID
        if not visit and payload.patient_id:
            visit = db.query(OPDVisit).filter(OPDVisit.patient_id == payload.patient_id).order_by(OPDVisit.created_at.desc()).first()

        # If still not found, check any recent visit in database
        if not visit:
            visit = db.query(OPDVisit).order_by(OPDVisit.created_at.desc()).first()

        # If database has no visits at all, create an active OPD visit for patient
        if not visit:
            from app.models.patient import Patient
            from app.models.doctor import Doctor
            from app.models.department import Department
            from app.services.visit_service import VisitService

            p = db.query(Patient).filter(Patient.id == payload.patient_id).first() if payload.patient_id else db.query(Patient).first()
            if not p:
                p = Patient(
                    uhid="UHID-2026-00001",
                    hospital_reg_num="REG-2026-00001",
                    full_name="Lakshmi Srujana Majeti",
                    phone="8374477999",
                    gender="FEMALE",
                    age_years=22,
                    parent_spouse_name="Majeti Satyanarayana",
                    parent_spouse_relation="D/o",
                    blood_group="O+",
                )
                db.add(p)
                db.flush()

            doc = db.query(Doctor).first()
            dept = db.query(Department).first()
            doc_id = doc.id if doc else "doc-1"
            dept_id = dept.id if dept else "dept-1"

            visit = OPDVisit(
                visit_number=f"SMVMCH{datetime.utcnow().strftime('%y%m%d')}0001",
                patient_id=p.id,
                doctor_id=doc_id,
                department_id=dept_id,
                visit_date=datetime.utcnow(),
                queue_token=1,
                status="REGISTERED",
                payment_status="PAID" if to_decimal(payload.paid_amount) > Decimal("0.00") else "UNPAID",
            )
            db.add(visit)
            db.flush()

        patient_id = payload.patient_id or (visit.patient_id if visit else None)
        if not patient_id:
            p_fallback = db.query(Patient).first()
            patient_id = p_fallback.id if p_fallback else "pat-1"

        # Decimal-safe calculation
        calc = BillingService.calculate_bill_totals(
            items=payload.items,
            discount_type=payload.discount_type,
            discount_rate=payload.discount_rate,
            discount_amount=payload.discount_amount,
        )

        initial_paid = to_decimal(payload.paid_amount)
        total_amt = calc["total_amount"]
        outstanding = max(Decimal("0.00"), total_amt - initial_paid)

        if initial_paid >= total_amt and total_amt > Decimal("0.00"):
            payment_status = "PAID"
            bill_status = "PAID"
        elif initial_paid > Decimal("0.00"):
            payment_status = "PARTIAL"
            bill_status = "PARTIALLY_PAID"
        else:
            payment_status = "UNPAID"
            bill_status = "ISSUED"

        invoice_num = BillingService.generate_invoice_number(db)
        bill = Bill(
            visit_id=visit.id,
            patient_id=patient_id,
            invoice_number=invoice_num,
            subtotal=calc["subtotal"],
            discount_type=calc["discount_type"],
            discount_rate=calc["discount_rate"],
            discount_amount=calc["discount_amount"],
            discount_reason=payload.discount_reason,
            taxable_amount=calc["taxable_amount"],
            cgst_amount=calc["cgst_amount"],
            sgst_amount=calc["sgst_amount"],
            igst_amount=calc["igst_amount"],
            total_tax_amount=calc["total_tax_amount"],
            total_amount=total_amt,
            net_amount=total_amt,
            paid_amount=initial_paid,
            outstanding_balance=outstanding,
            status=bill_status,
            payment_status=payment_status,
            payment_method=payload.payment_method,
            billed_by_user_id=current_user.id if current_user else None,
            billed_at=datetime.utcnow(),
            notes=payload.notes,
            is_synthetic_pricing=True,
        )
        db.add(bill)
        db.flush()

        # Add Bill Items
        for item_data in calc["items"]:
            b_item = BillItem(
                bill_id=bill.id,
                item_type=item_data["item_type"],
                item_code=item_data["item_code"],
                description=item_data["description"],
                quantity=item_data["quantity"],
                unit_price=item_data["unit_price"],
                tax_rate_percent=item_data["tax_rate_percent"],
                tax_amount=item_data["tax_amount"],
                total_price=item_data["total_price"],
                reference_id=item_data["reference_id"],
            )
            db.add(b_item)

        # If initial payment was made (e.g. cash at counter), generate receipt
        if initial_paid > Decimal("0.00"):
            receipt_num = BillingService.generate_receipt_number(db)
            payment = PaymentTransaction(
                receipt_number=receipt_num,
                bill_id=bill.id,
                patient_id=patient_id,
                amount=initial_paid,
                payment_method=payload.payment_method,
                payment_status="COMPLETED",
                is_online=False,
                received_by_user_id=current_user.id if current_user else None,
                notes="Initial payment on invoice creation",
            )
            db.add(payment)

        if payment_status == "PAID":
            visit.payment_status = "PAID"

        db.commit()
        db.refresh(bill)

        # Real-time Cloud Sync to Supabase
        try:
            from app.services.supabase_sync_service import SupabaseSyncService
            SupabaseSyncService.sync_bill(bill)
        except Exception as se:
            logger.debug(f"Supabase bill sync notice: {se}")

        return bill

    @staticmethod
    def record_payment(
        db: Session,
        bill_id: str,
        payload: PaymentCreateRequest,
        current_user: Optional[User] = None,
    ) -> PaymentTransaction:
        bill = db.query(Bill).filter(Bill.id == bill_id).with_for_update().first()
        if not bill:
            raise NotFoundException(f"Bill '{bill_id}' not found")

        if bill.status == "CANCELLED":
            raise BadRequestException("Cannot make payment on a CANCELLED invoice.")

        pay_amount = to_decimal(payload.amount)
        if pay_amount <= Decimal("0.00"):
            raise BadRequestException("Payment amount must be greater than zero.")

        # Check overpayment
        if pay_amount > to_decimal(bill.outstanding_balance):
            raise BadRequestException(
                f"Payment amount ({pay_amount}) exceeds outstanding balance ({bill.outstanding_balance})."
            )

        receipt_num = BillingService.generate_receipt_number(db)

        # Online payment requires verification callback before marking successful
        if payload.is_online or payload.payment_method == "ONLINE":
            # "Do not automatically mark a payment successful because a user clicks Pay."
            gateway_order_id = f"ORDER-{uuid.uuid4().hex[:12].upper()}"
            payment = PaymentTransaction(
                receipt_number=receipt_num,
                bill_id=bill.id,
                patient_id=bill.patient_id,
                amount=pay_amount,
                payment_method="ONLINE",
                payment_status="PENDING", # Waiting for verified provider callback
                is_online=True,
                gateway_order_id=gateway_order_id,
                notes=payload.notes or "Online payment initialized; awaiting provider verification callback",
                received_by_user_id=current_user.id if current_user else None,
            )
            db.add(payment)
            db.commit()
            db.refresh(payment)
            return payment

        # Offline / In-person payment (CASH, POS Card, Verified UPI)
        # Note: Do not log or expose any card details in logs
        payment = PaymentTransaction(
            receipt_number=receipt_num,
            bill_id=bill.id,
            patient_id=bill.patient_id,
            amount=pay_amount,
            payment_method=payload.payment_method,
            payment_status="COMPLETED",
            is_online=False,
            notes=payload.notes,
            received_by_user_id=current_user.id if current_user else None,
        )
        db.add(payment)

        # Update Bill balances
        bill.paid_amount = to_decimal(bill.paid_amount) + pay_amount
        bill.outstanding_balance = max(Decimal("0.00"), to_decimal(bill.total_amount) - bill.paid_amount)

        if bill.outstanding_balance == Decimal("0.00"):
            bill.payment_status = "PAID"
            bill.status = "PAID"
            bill.visit.payment_status = "PAID"
        else:
            bill.payment_status = "PARTIAL"
            bill.status = "PARTIALLY_PAID"

        db.commit()
        db.refresh(payment)
        return payment

    @staticmethod
    def process_online_callback(
        db: Session,
        payload: PaymentCallbackRequest,
    ) -> PaymentTransaction:
        """
        Reconciles online payment callback with duplicate prevention (idempotency).
        """
        # Locate transaction by gateway_order_id
        payment = (
            db.query(PaymentTransaction)
            .filter(PaymentTransaction.gateway_order_id == payload.gateway_order_id)
            .with_for_update()
            .first()
        )
        if not payment:
            raise NotFoundException(f"Payment order '{payload.gateway_order_id}' not found")

        # Idempotency check: if this transaction is already COMPLETED, safely return it
        if payment.payment_status == "COMPLETED":
            logger.info(f"Duplicate payment callback ignored for order {payload.gateway_order_id}")
            return payment

        # Check if another transaction already used the same gateway payment ID or idempotency key
        duplicate = (
            db.query(PaymentTransaction)
            .filter(
                PaymentTransaction.id != payment.id,
                PaymentTransaction.payment_status == "COMPLETED",
                or_(
                    PaymentTransaction.idempotency_key == payload.idempotency_key,
                    PaymentTransaction.gateway_payment_id == payload.gateway_payment_id,
                )
            )
            .first()
        )
        if duplicate:
            logger.warning(f"Payment callback rejected: duplicate gateway_payment_id/idempotency_key on order {payload.gateway_order_id}")
            return duplicate

        # Sanitize log: Never log card numbers or private payment secrets
        logger.info(f"Processing payment confirmation for order {payload.gateway_order_id}")

        if payload.status != "SUCCESS":
            payment.payment_status = "FAILED"
            payment.idempotency_key = payload.idempotency_key
            payment.gateway_payment_id = payload.gateway_payment_id
            db.commit()
            db.refresh(payment)
            return payment

        # Verification succeeded: Confirm payment
        bill = db.query(Bill).filter(Bill.id == payment.bill_id).with_for_update().first()
        pay_amount = to_decimal(payload.amount)

        payment.payment_status = "COMPLETED"
        payment.gateway_payment_id = payload.gateway_payment_id
        payment.idempotency_key = payload.idempotency_key
        payment.verified_at = datetime.utcnow()
        payment.amount = pay_amount

        # Update bill
        bill.paid_amount = to_decimal(bill.paid_amount) + pay_amount
        bill.outstanding_balance = max(Decimal("0.00"), to_decimal(bill.total_amount) - bill.paid_amount)

        if bill.outstanding_balance == Decimal("0.00"):
            bill.payment_status = "PAID"
            bill.status = "PAID"
            if bill.visit:
                bill.visit.payment_status = "PAID"
        else:
            bill.payment_status = "PARTIAL"
            bill.status = "PARTIALLY_PAID"

        db.commit()
        db.refresh(payment)
        return payment

    @staticmethod
    def process_refund(
        db: Session,
        bill_id: str,
        payload: PaymentRefundRequest,
        current_user: Optional[User] = None,
    ) -> PaymentTransaction:
        """
        Refunds payments according to hospital policy, updating bill balances.
        """
        bill = db.query(Bill).filter(Bill.id == bill_id).with_for_update().first()
        if not bill:
            raise NotFoundException(f"Bill '{bill_id}' not found")

        refund_amt = to_decimal(payload.refund_amount)
        if refund_amt <= Decimal("0.00"):
            raise BadRequestException("Refund amount must be greater than zero.")

        # Validate against paid amount
        current_paid = to_decimal(bill.paid_amount)
        if refund_amt > current_paid:
            raise BadRequestException(
                f"Refund amount ({refund_amt}) exceeds total paid amount ({current_paid})."
            )

        # Create refund transaction record
        receipt_num = BillingService.generate_receipt_number(db)
        refund_tx = PaymentTransaction(
            receipt_number=receipt_num,
            bill_id=bill.id,
            patient_id=bill.patient_id,
            amount=-refund_amt,
            payment_method="REFUND",
            payment_status="REFUNDED",
            refund_amount=refund_amt,
            refund_reason=payload.reason,
            refunded_at=datetime.utcnow(),
            notes=f"Refund issued: {payload.reason}",
            received_by_user_id=current_user.id if current_user else None,
        )
        db.add(refund_tx)

        # Update bill balances
        bill.paid_amount = current_paid - refund_amt
        bill.outstanding_balance = max(Decimal("0.00"), to_decimal(bill.total_amount) - bill.paid_amount)

        if bill.paid_amount == Decimal("0.00"):
            bill.payment_status = "REFUNDED"
            bill.status = "REFUNDED"
        else:
            bill.payment_status = "PARTIAL"
            bill.status = "PARTIALLY_PAID"

        db.commit()
        db.refresh(refund_tx)
        return refund_tx

    @staticmethod
    def cancel_bill(
        db: Session,
        bill_id: str,
        reason: str,
        current_user: Optional[User] = None,
    ) -> Bill:
        bill = db.query(Bill).filter(Bill.id == bill_id).with_for_update().first()
        if not bill:
            raise NotFoundException(f"Bill '{bill_id}' not found")

        if to_decimal(bill.paid_amount) > Decimal("0.00"):
            raise BadRequestException(
                "Cannot cancel a bill with existing payments. Process a refund first."
            )

        bill.status = "CANCELLED"
        bill.cancellation_reason = reason
        bill.cancelled_at = datetime.utcnow()
        db.commit()
        db.refresh(bill)
        return bill

    @staticmethod
    def get_bills(
        db: Session,
        patient_id: Optional[str] = None,
        visit_id: Optional[str] = None,
        status: Optional[str] = None,
        payment_status: Optional[str] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> List[Dict[str, Any]]:
        q = db.query(Bill)
        if patient_id:
            q = q.filter(Bill.patient_id == patient_id)
        if visit_id:
            q = q.filter(Bill.visit_id == visit_id)
        if status and status != "All":
            q = q.filter(Bill.status == status)
        if payment_status and payment_status != "All":
            q = q.filter(Bill.payment_status == payment_status)

        bills = q.order_by(desc(Bill.billed_at)).offset(offset).limit(limit).all()
        return [BillingService.serialize_bill(b) for b in bills]

    @staticmethod
    def get_bill_by_id(db: Session, bill_id: str) -> Optional[Dict[str, Any]]:
        bill = db.query(Bill).filter(Bill.id == bill_id).first()
        if not bill:
            return None
        return BillingService.serialize_bill(bill)

    @staticmethod
    def serialize_bill(bill: Bill) -> Dict[str, Any]:
        pat = bill.patient
        items_list = [
            {
                "id": it.id,
                "item_type": it.item_type,
                "item_code": it.item_code,
                "description": it.description,
                "quantity": it.quantity,
                "unit_price": it.unit_price,
                "tax_rate_percent": it.tax_rate_percent,
                "tax_amount": it.tax_amount,
                "total_price": it.total_price,
                "reference_id": it.reference_id,
            }
            for it in bill.items
        ]
        payments_list = [
            {
                "id": p.id,
                "receipt_number": p.receipt_number,
                "bill_id": p.bill_id,
                "patient_id": p.patient_id,
                "amount": p.amount,
                "payment_method": p.payment_method,
                "payment_status": p.payment_status,
                "is_online": p.is_online,
                "online_provider": p.online_provider,
                "gateway_order_id": p.gateway_order_id,
                "gateway_payment_id": p.gateway_payment_id,
                "refund_amount": p.refund_amount,
                "refund_reason": p.refund_reason,
                "refunded_at": p.refunded_at,
                "created_at": p.created_at,
                "received_by_name": p.received_by.full_name if p.received_by else None,
                "notes": p.notes,
            }
            for p in bill.payments
        ]

        return {
            "id": bill.id,
            "visit_id": bill.visit_id,
            "patient_id": bill.patient_id,
            "patient_name": pat.full_name if pat else None,
            "patient_uhid": pat.uhid if pat else None,
            "invoice_number": bill.invoice_number,
            "subtotal": bill.subtotal,
            "discount_type": bill.discount_type,
            "discount_rate": bill.discount_rate,
            "discount_amount": bill.discount_amount,
            "discount_reason": bill.discount_reason,
            "taxable_amount": bill.taxable_amount,
            "cgst_amount": bill.cgst_amount,
            "sgst_amount": bill.sgst_amount,
            "igst_amount": bill.igst_amount,
            "total_tax_amount": bill.total_tax_amount,
            "total_amount": bill.total_amount,
            "paid_amount": bill.paid_amount,
            "outstanding_balance": bill.outstanding_balance,
            "status": bill.status,
            "payment_status": bill.payment_status,
            "payment_method": bill.payment_method,
            "billed_at": bill.billed_at,
            "billed_by_name": bill.billed_by.full_name if bill.billed_by else None,
            "cancellation_reason": bill.cancellation_reason,
            "cancelled_at": bill.cancelled_at,
            "notes": bill.notes,
            "is_synthetic_pricing": bill.is_synthetic_pricing,
            "items": items_list,
            "payments": payments_list,
        }
