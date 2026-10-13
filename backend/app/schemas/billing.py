from datetime import datetime
from typing import List, Optional
from decimal import Decimal
from pydantic import Field
from app.schemas.common import BaseSchema


class BillItemBase(BaseSchema):
    item_type: str = "CONSULTATION" # CONSULTATION, LAB, PHARMACY, PROCEDURE, REGISTRATION, EMERGENCY
    item_code: Optional[str] = None
    description: str
    unit_price: Decimal = Field(default=Decimal("0.00"), ge=0)
    quantity: int = Field(default=1, gt=0)
    tax_rate_percent: Decimal = Field(default=Decimal("0.00"), ge=0)
    tax_amount: Decimal = Field(default=Decimal("0.00"), ge=0)
    total_price: Decimal = Field(default=Decimal("0.00"), ge=0)
    reference_id: Optional[str] = None


class BillItemCreate(BillItemBase):
    pass


class BillItemRead(BillItemBase):
    id: str


class BillCreate(BaseSchema):
    visit_id: str
    patient_id: Optional[str] = None
    discount_type: str = "NONE" # NONE, PERCENTAGE, FIXED
    discount_rate: Decimal = Field(default=Decimal("0.00"), ge=0)
    discount_amount: Decimal = Field(default=Decimal("0.00"), ge=0)
    discount_reason: Optional[str] = None
    paid_amount: Decimal = Field(default=Decimal("0.00"), ge=0)
    payment_method: str = "CASH"
    notes: Optional[str] = None
    items: List[BillItemCreate] = []


class PaymentCreateRequest(BaseSchema):
    amount: Decimal = Field(gt=0)
    payment_method: str = "CASH" # CASH, UPI, CARD, ONLINE, INSURANCE
    is_online: bool = False
    notes: Optional[str] = None


class PaymentCallbackRequest(BaseSchema):
    gateway_order_id: str
    gateway_payment_id: str
    amount: Decimal = Field(gt=0)
    idempotency_key: str
    status: str = "SUCCESS" # SUCCESS, FAILED
    signature: Optional[str] = None
    notes: Optional[str] = None


class PaymentRefundRequest(BaseSchema):
    refund_amount: Decimal = Field(gt=0)
    reason: str


class PaymentReceiptRead(BaseSchema):
    id: str
    receipt_number: str
    bill_id: str
    patient_id: str
    amount: Decimal
    payment_method: str
    payment_status: str
    is_online: bool
    online_provider: Optional[str] = None
    gateway_order_id: Optional[str] = None
    gateway_payment_id: Optional[str] = None
    refund_amount: Decimal = Decimal("0.00")
    refund_reason: Optional[str] = None
    refunded_at: Optional[datetime] = None
    created_at: datetime
    received_by_name: Optional[str] = None
    notes: Optional[str] = None


class BillRead(BaseSchema):
    id: str
    visit_id: str
    patient_id: str
    patient_name: Optional[str] = None
    patient_uhid: Optional[str] = None
    invoice_number: str
    subtotal: Decimal
    discount_type: str
    discount_rate: Decimal
    discount_amount: Decimal
    discount_reason: Optional[str] = None
    taxable_amount: Decimal
    cgst_amount: Decimal
    sgst_amount: Decimal
    igst_amount: Decimal
    total_tax_amount: Decimal
    total_amount: Decimal
    paid_amount: Decimal
    outstanding_balance: Decimal
    status: str
    payment_status: str
    payment_method: str
    billed_at: datetime
    billed_by_name: Optional[str] = None
    cancellation_reason: Optional[str] = None
    cancelled_at: Optional[datetime] = None
    notes: Optional[str] = None
    is_synthetic_pricing: bool = True
    items: List[BillItemRead] = []
    payments: List[PaymentReceiptRead] = []


class BillCancellationRequest(BaseSchema):
    reason: str


class ServiceCatalogItem(BaseSchema):
    code: str
    category: str
    name: str
    synthetic_price: Decimal
    tax_rate_percent: Decimal
    is_synthetic: bool = True
