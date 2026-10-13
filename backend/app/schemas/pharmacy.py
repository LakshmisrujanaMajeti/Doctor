from datetime import datetime, date
from typing import List, Optional
from decimal import Decimal
from pydantic import Field
from app.schemas.common import BaseSchema


class MedicineInventoryBase(BaseSchema):
    medicine_code: str
    name: str
    generic_name: Optional[str] = None
    strength: str
    dosage_form: str = "Tablet"
    batch_number: str
    expiry_date: date
    available_quantity: int = 0
    reorder_level: int = 20
    unit_price: Decimal = Decimal("0.00")
    is_synthetic_price: bool = True
    tax_classification: str = "GST_5"
    tax_rate_percent: Decimal = Decimal("5.00")
    supplier_name: str = "Standard Hospital Supply Co."
    supplier_contact: Optional[str] = None
    is_active: bool = True


class MedicineInventoryCreate(MedicineInventoryBase):
    pass


class MedicineInventoryRead(MedicineInventoryBase):
    id: str
    created_at: datetime
    updated_at: datetime
    is_low_stock: bool = False
    is_expiring_soon: bool = False
    is_expired: bool = False


class StockReceiptRequest(BaseSchema):
    medicine_code: Optional[str] = None # Existing code or new
    name: str
    generic_name: Optional[str] = None
    strength: str
    dosage_form: str = "Tablet"
    batch_number: str
    expiry_date: date
    quantity: int = Field(gt=0)
    unit_price: Decimal = Decimal("0.00")
    tax_classification: str = "GST_5"
    supplier_name: str = "Standard Hospital Supply Co."
    supplier_contact: Optional[str] = None
    purchase_order_ref: Optional[str] = None
    notes: Optional[str] = None


class StockAdjustmentRequest(BaseSchema):
    inventory_id: str
    adjustment_type: str = "ADD" # "ADD" or "SUBTRACT" or "SET"
    quantity: int = Field(gt=0)
    reason: str
    reference_number: Optional[str] = None


class StockMovementRead(BaseSchema):
    id: str
    inventory_id: str
    medicine_name: Optional[str] = None
    batch_number: Optional[str] = None
    movement_type: str
    quantity: int
    balance_after: int
    reference_number: Optional[str] = None
    reason: Optional[str] = None
    performed_by_name: Optional[str] = None
    created_at: datetime


class DispenseItemRequest(BaseSchema):
    prescription_item_id: Optional[str] = None
    inventory_id: str
    quantity_to_dispense: int = Field(gt=0)
    instructions: Optional[str] = None


class DispensePrescriptionRequest(BaseSchema):
    prescription_id: str
    items: List[DispenseItemRequest]
    notes: Optional[str] = None


class PharmacyDispenseItemRead(BaseSchema):
    id: str
    inventory_id: str
    prescription_item_id: Optional[str] = None
    medicine_name: str
    batch_number: str
    quantity_prescribed: int
    quantity_dispensed: int
    unit_price: Decimal
    total_price: Decimal
    instructions: Optional[str] = None


class PharmacyDispenseRead(BaseSchema):
    id: str
    dispense_number: str
    prescription_id: str
    visit_id: str
    patient_id: str
    patient_name: Optional[str] = None
    patient_uhid: Optional[str] = None
    dispensed_by_user_id: str
    dispensed_by_name: Optional[str] = None
    status: str
    total_items_dispensed: int
    total_amount: Decimal
    dispensed_at: datetime
    notes: Optional[str] = None
    items: List[PharmacyDispenseItemRead] = []


class InventoryStatsRead(BaseSchema):
    total_medicines: int = 0
    total_stock_units: int = 0
    low_stock_count: int = 0
    expiring_soon_count: int = 0
    expired_count: int = 0
    today_dispenses_count: int = 0


# Backwards compatibility schemas
class PharmacyOrderCreate(BaseSchema):
    prescription_id: str
    notes: Optional[str] = None


class PharmacyOrderRead(BaseSchema):
    id: str
    prescription_id: str
    dispensed_by_user_id: Optional[str] = None
    status: str
    total_amount: float
    dispensed_at: Optional[datetime] = None
    notes: Optional[str] = None
