from datetime import datetime
from sqlalchemy import Column, String, Float, Integer, DateTime, ForeignKey, Text, Boolean, Numeric
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import TimestampMixin, generate_uuid


class Bill(Base, TimestampMixin):
    __tablename__ = "bills"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    visit_id = Column(String(36), ForeignKey("opd_visits.id", ondelete="CASCADE"), nullable=False, index=True)
    patient_id = Column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, index=True)
    invoice_number = Column(String(50), unique=True, nullable=False, index=True)

    # Itemized Breakdown & Decimal-Safe Monetary Totals
    subtotal = Column(Numeric(10, 2), default=0.0, nullable=False)
    discount_type = Column(String(20), default="NONE", nullable=False) # NONE, PERCENTAGE, FIXED
    discount_rate = Column(Numeric(5, 2), default=0.0, nullable=False) # e.g. 10.00 for 10%
    discount_amount = Column(Numeric(10, 2), default=0.0, nullable=False)
    discount_reason = Column(String(150), nullable=True)

    taxable_amount = Column(Numeric(10, 2), default=0.0, nullable=False) # subtotal - discount_amount
    cgst_amount = Column(Numeric(10, 2), default=0.0, nullable=False)
    sgst_amount = Column(Numeric(10, 2), default=0.0, nullable=False)
    igst_amount = Column(Numeric(10, 2), default=0.0, nullable=False)
    total_tax_amount = Column(Numeric(10, 2), default=0.0, nullable=False)

    total_amount = Column(Numeric(10, 2), default=0.0, nullable=False) # taxable_amount + total_tax_amount
    net_amount = Column(Numeric(10, 2), default=0.0, nullable=False) # Backwards compatible net amount
    paid_amount = Column(Numeric(10, 2), default=0.0, nullable=False)
    outstanding_balance = Column(Numeric(10, 2), default=0.0, nullable=False)

    # Status: DRAFT, ISSUED, PAID, PARTIALLY_PAID, CANCELLED, REFUNDED
    status = Column(String(30), default="ISSUED", nullable=False, index=True)
    payment_status = Column(String(20), default="UNPAID", nullable=False, index=True) # UNPAID, PARTIAL, PAID, REFUNDED
    payment_method = Column(String(30), default="CASH", nullable=False) # CASH, UPI, CARD, ONLINE, INSURANCE

    # Auditing & Safety
    billed_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    billed_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    cancellation_reason = Column(Text, nullable=True)
    cancelled_at = Column(DateTime, nullable=True)
    notes = Column(Text, nullable=True)
    is_synthetic_pricing = Column(Boolean, default=True, nullable=False)

    # Relationships
    visit = relationship("OPDVisit", back_populates="bills")
    patient = relationship("Patient", back_populates="bills")
    billed_by = relationship("User", foreign_keys=[billed_by_user_id])
    items = relationship("BillItem", back_populates="bill", cascade="all, delete-orphan")
    payments = relationship("PaymentTransaction", back_populates="bill", cascade="all, delete-orphan", order_by="desc(PaymentTransaction.created_at)")


class BillItem(Base, TimestampMixin):
    __tablename__ = "bill_items"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    bill_id = Column(String(36), ForeignKey("bills.id", ondelete="CASCADE"), nullable=False, index=True)

    # Categories: CONSULTATION, LAB, PHARMACY, PROCEDURE, REGISTRATION, EMERGENCY
    item_type = Column(String(30), default="CONSULTATION", nullable=False)
    item_code = Column(String(50), nullable=True)
    description = Column(String(200), nullable=False)
    quantity = Column(Integer, default=1, nullable=False)
    unit_price = Column(Numeric(10, 2), default=0.0, nullable=False)
    tax_rate_percent = Column(Numeric(5, 2), default=0.0, nullable=False)
    tax_amount = Column(Numeric(10, 2), default=0.0, nullable=False)
    total_price = Column(Numeric(10, 2), default=0.0, nullable=False)
    reference_id = Column(String(60), nullable=True) # Linked dispense_id, lab_order_id, etc.

    bill = relationship("Bill", back_populates="items")


class PaymentTransaction(Base, TimestampMixin):
    __tablename__ = "payment_transactions"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    receipt_number = Column(String(50), unique=True, nullable=False, index=True)
    bill_id = Column(String(36), ForeignKey("bills.id", ondelete="CASCADE"), nullable=False, index=True)
    patient_id = Column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, index=True)

    amount = Column(Numeric(10, 2), nullable=False)
    payment_method = Column(String(30), default="CASH", nullable=False) # CASH, UPI, CARD, ONLINE, INSURANCE
    payment_status = Column(String(20), default="COMPLETED", nullable=False, index=True) # PENDING, COMPLETED, FAILED, REFUNDED

    # Online gateway reconciliation
    is_online = Column(Boolean, default=False, nullable=False)
    online_provider = Column(String(50), default="MOCK_PAYMENT_GATEWAY", nullable=False)
    gateway_order_id = Column(String(100), nullable=True, index=True)
    gateway_payment_id = Column(String(100), nullable=True, index=True)
    idempotency_key = Column(String(100), unique=True, nullable=True, index=True)
    verified_at = Column(DateTime, nullable=True)

    # Refunds
    refund_amount = Column(Numeric(10, 2), default=0.0, nullable=False)
    refund_reason = Column(Text, nullable=True)
    refunded_at = Column(DateTime, nullable=True)

    notes = Column(Text, nullable=True)
    received_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)

    bill = relationship("Bill", back_populates="payments")
    patient = relationship("Patient")
    received_by = relationship("User", foreign_keys=[received_by_user_id])
