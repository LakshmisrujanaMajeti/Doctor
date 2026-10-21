from datetime import datetime, date
from sqlalchemy import Column, String, Float, Integer, Date, DateTime, ForeignKey, Text, Boolean, Numeric
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import TimestampMixin, generate_uuid


class MedicineInventory(Base, TimestampMixin):
    __tablename__ = "medicine_inventory"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    medicine_code = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(150), nullable=False, index=True)
    generic_name = Column(String(150), nullable=True, index=True)
    strength = Column(String(50), nullable=False) # e.g. 650 mg, 500 mg, 5 ml
    dosage_form = Column(String(50), default="Tablet", nullable=False) # Tablet, Capsule, Syrup, Injection, Ointment, Inhaler, Drops
    batch_number = Column(String(50), nullable=False, index=True)
    expiry_date = Column(Date, nullable=False, index=True)
    available_quantity = Column(Integer, default=0, nullable=False, index=True)
    reorder_level = Column(Integer, default=20, nullable=False)
    
    # Pricing & Tax Classification (Clearly labeled synthetic prices in development)
    unit_price = Column(Numeric(10, 2), default=0.0, nullable=False)
    is_synthetic_price = Column(Boolean, default=True, nullable=False)
    tax_classification = Column(String(20), default="GST_5", nullable=False) # GST_0, GST_5, GST_12, GST_18
    tax_rate_percent = Column(Numeric(5, 2), default=5.0, nullable=False)

    supplier_name = Column(String(150), default="Standard Hospital Supply Co.", nullable=False)
    supplier_contact = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)

    stock_movements = relationship("StockMovement", back_populates="inventory", cascade="all, delete-orphan", order_by="desc(StockMovement.created_at)")
    dispensed_items = relationship("PharmacyDispenseItem", back_populates="inventory")


class StockMovement(Base, TimestampMixin):
    __tablename__ = "stock_movements"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    inventory_id = Column(String(36), ForeignKey("medicine_inventory.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Movement Types: PURCHASE_RECEIPT, DISPENSE, ADJUSTMENT_ADD, ADJUSTMENT_SUBTRACT, RETURN, EXPIRED_DISPOSAL
    movement_type = Column(String(30), nullable=False, index=True)
    quantity = Column(Integer, nullable=False) # Positive for additions, negative or absolute handled in logic
    balance_after = Column(Integer, nullable=False)
    reference_number = Column(String(60), nullable=True) # Purchase order, Dispense number, or Adjustment token
    reason = Column(Text, nullable=True)
    performed_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)

    inventory = relationship("MedicineInventory", back_populates="stock_movements")
    performed_by = relationship("User", foreign_keys=[performed_by_user_id])


class PharmacyDispense(Base, TimestampMixin):
    __tablename__ = "pharmacy_dispenses"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    dispense_number = Column(String(50), unique=True, nullable=False, index=True)
    prescription_id = Column(String(36), ForeignKey("prescriptions.id", ondelete="CASCADE"), nullable=False, index=True)
    visit_id = Column(String(36), ForeignKey("opd_visits.id", ondelete="CASCADE"), nullable=False, index=True)
    patient_id = Column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, index=True)
    dispensed_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=False)

    status = Column(String(20), default="COMPLETED", nullable=False, index=True) # COMPLETED, PARTIAL, CANCELLED
    total_items_dispensed = Column(Integer, default=0, nullable=False)
    total_amount = Column(Numeric(10, 2), default=0.0, nullable=False)
    dispensed_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    notes = Column(Text, nullable=True)

    prescription = relationship("Prescription")
    visit = relationship("OPDVisit")
    patient = relationship("Patient")
    dispensed_by = relationship("User", foreign_keys=[dispensed_by_user_id])
    items = relationship("PharmacyDispenseItem", back_populates="dispense", cascade="all, delete-orphan")


class PharmacyDispenseItem(Base, TimestampMixin):
    __tablename__ = "pharmacy_dispense_items"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    dispense_id = Column(String(36), ForeignKey("pharmacy_dispenses.id", ondelete="CASCADE"), nullable=False, index=True)
    prescription_item_id = Column(String(36), ForeignKey("prescription_items.id", ondelete="SET NULL"), nullable=True)
    inventory_id = Column(String(36), ForeignKey("medicine_inventory.id", ondelete="RESTRICT"), nullable=False, index=True)

    medicine_name = Column(String(150), nullable=False)
    batch_number = Column(String(50), nullable=False)
    quantity_prescribed = Column(Integer, nullable=False)
    quantity_dispensed = Column(Integer, nullable=False)
    unit_price = Column(Numeric(10, 2), default=0.0, nullable=False)
    total_price = Column(Numeric(10, 2), default=0.0, nullable=False)
    instructions = Column(Text, nullable=True)

    dispense = relationship("PharmacyDispense", back_populates="items")
    inventory = relationship("MedicineInventory", back_populates="dispensed_items")
    prescription_item = relationship("PrescriptionItem")


class PharmacyOrder(Base, TimestampMixin):
    __tablename__ = "pharmacy_orders"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    prescription_id = Column(String(36), ForeignKey("prescriptions.id", ondelete="CASCADE"), nullable=False, index=True)
    dispensed_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)

    status = Column(String(30), default="PENDING", nullable=False, index=True) # PENDING, DISPENSED, PARTIAL, CANCELLED
    total_amount = Column(Float, default=0.0, nullable=False)
    dispensed_at = Column(DateTime, nullable=True)
    notes = Column(Text, nullable=True)

    prescription = relationship("Prescription", back_populates="pharmacy_orders")
