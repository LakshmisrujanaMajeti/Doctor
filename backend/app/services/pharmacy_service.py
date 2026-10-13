import uuid
from datetime import datetime, date, timedelta
from decimal import Decimal
from typing import List, Optional, Tuple, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import func, or_, desc

from app.models.pharmacy import (
    MedicineInventory,
    StockMovement,
    PharmacyDispense,
    PharmacyDispenseItem,
    PharmacyOrder,
)
from app.models.prescription import Prescription, PrescriptionItem
from app.models.visit import OPDVisit
from app.models.patient import Patient
from app.models.user import User
from app.schemas.pharmacy import (
    StockReceiptRequest,
    StockAdjustmentRequest,
    DispensePrescriptionRequest,
    DispenseItemRequest,
    InventoryStatsRead,
    MedicineInventoryRead,
)
from app.core.exceptions import (
    NotFoundException,
    BadRequestException,
    ForbiddenException,
)
from app.core.logging import logger


class PharmacyService:
    @staticmethod
    def generate_dispense_number(db: Session) -> str:
        today_str = datetime.utcnow().strftime("%Y%m%d")
        prefix = f"DISP-{today_str}-"
        count = (
            db.query(func.count(PharmacyDispense.id))
            .filter(PharmacyDispense.dispense_number.like(f"{prefix}%"))
            .scalar()
            or 0
        )
        return f"{prefix}{str(count + 1).zfill(4)}"

    @staticmethod
    def generate_medicine_code(db: Session, name: str, strength: str) -> str:
        clean_name = "".join(c for c in name if c.isalnum())[:3].upper()
        clean_str = "".join(c for c in strength if c.isalnum())[:3].upper()
        rand_suffix = uuid.uuid4().hex[:4].upper()
        return f"MED-{clean_name}-{clean_str}-{rand_suffix}"

    @staticmethod
    def get_inventory_stats(db: Session) -> InventoryStatsRead:
        today = date.today()
        sixty_days = today + timedelta(days=60)
        start_of_day = datetime(today.year, today.month, today.day)

        total_medicines = db.query(func.count(func.distinct(MedicineInventory.name))).scalar() or 0
        total_stock_units = db.query(func.sum(MedicineInventory.available_quantity)).scalar() or 0
        low_stock_count = (
            db.query(func.count(MedicineInventory.id))
            .filter(MedicineInventory.available_quantity <= MedicineInventory.reorder_level)
            .scalar()
            or 0
        )
        expiring_soon_count = (
            db.query(func.count(MedicineInventory.id))
            .filter(MedicineInventory.expiry_date > today, MedicineInventory.expiry_date <= sixty_days)
            .scalar()
            or 0
        )
        expired_count = (
            db.query(func.count(MedicineInventory.id))
            .filter(MedicineInventory.expiry_date <= today)
            .scalar()
            or 0
        )
        today_dispenses_count = (
            db.query(func.count(PharmacyDispense.id))
            .filter(PharmacyDispense.dispensed_at >= start_of_day)
            .scalar()
            or 0
        )

        return InventoryStatsRead(
            total_medicines=total_medicines,
            total_stock_units=total_stock_units,
            low_stock_count=low_stock_count,
            expiring_soon_count=expiring_soon_count,
            expired_count=expired_count,
            today_dispenses_count=today_dispenses_count,
        )

    @staticmethod
    def search_inventory(
        db: Session,
        query: Optional[str] = None,
        dosage_form: Optional[str] = None,
        low_stock: Optional[bool] = None,
        expiring_soon: Optional[bool] = None,
        is_active: Optional[bool] = True,
        limit: int = 50,
        offset: int = 0,
    ) -> List[Dict[str, Any]]:
        today = date.today()
        sixty_days = today + timedelta(days=60)
        q = db.query(MedicineInventory)

        if is_active is not None:
            q = q.filter(MedicineInventory.is_active == is_active)

        if query and query.strip():
            term = f"%{query.strip()}%"
            q = q.filter(
                or_(
                    MedicineInventory.name.ilike(term),
                    MedicineInventory.generic_name.ilike(term),
                    MedicineInventory.medicine_code.ilike(term),
                    MedicineInventory.batch_number.ilike(term),
                )
            )

        if dosage_form and dosage_form != "All":
            q = q.filter(MedicineInventory.dosage_form == dosage_form)

        if low_stock:
            q = q.filter(MedicineInventory.available_quantity <= MedicineInventory.reorder_level)

        if expiring_soon:
            q = q.filter(MedicineInventory.expiry_date <= sixty_days)

        q = q.order_by(MedicineInventory.name.asc(), MedicineInventory.expiry_date.asc())
        items = q.offset(offset).limit(limit).all()

        results = []
        for item in items:
            is_low = item.available_quantity <= item.reorder_level
            is_exp_soon = today < item.expiry_date <= sixty_days
            is_exp = item.expiry_date <= today

            data = {
                "id": item.id,
                "medicine_code": item.medicine_code,
                "name": item.name,
                "generic_name": item.generic_name,
                "strength": item.strength,
                "dosage_form": item.dosage_form,
                "batch_number": item.batch_number,
                "expiry_date": item.expiry_date,
                "available_quantity": item.available_quantity,
                "reorder_level": item.reorder_level,
                "unit_price": item.unit_price,
                "is_synthetic_price": item.is_synthetic_price,
                "tax_classification": item.tax_classification,
                "tax_rate_percent": item.tax_rate_percent,
                "supplier_name": item.supplier_name,
                "supplier_contact": item.supplier_contact,
                "is_active": item.is_active,
                "created_at": item.created_at,
                "updated_at": item.updated_at,
                "is_low_stock": is_low,
                "is_expiring_soon": is_exp_soon,
                "is_expired": is_exp,
            }
            results.append(data)
        return results

    @staticmethod
    def receive_stock(
        db: Session,
        payload: StockReceiptRequest,
        performed_by_user_id: Optional[str] = None,
    ) -> MedicineInventory:
        # Check if identical batch already exists
        existing = (
            db.query(MedicineInventory)
            .filter(
                MedicineInventory.name == payload.name,
                MedicineInventory.batch_number == payload.batch_number,
            )
            .first()
        )

        if existing:
            existing.available_quantity += payload.quantity
            existing.expiry_date = payload.expiry_date
            existing.unit_price = payload.unit_price
            existing.supplier_name = payload.supplier_name
            if payload.supplier_contact:
                existing.supplier_contact = payload.supplier_contact
            inventory = existing
        else:
            code = payload.medicine_code or PharmacyService.generate_medicine_code(
                db, payload.name, payload.strength
            )
            inventory = MedicineInventory(
                medicine_code=code,
                name=payload.name,
                generic_name=payload.generic_name,
                strength=payload.strength,
                dosage_form=payload.dosage_form,
                batch_number=payload.batch_number,
                expiry_date=payload.expiry_date,
                available_quantity=payload.quantity,
                unit_price=payload.unit_price,
                is_synthetic_price=True,
                tax_classification=payload.tax_classification,
                supplier_name=payload.supplier_name,
                supplier_contact=payload.supplier_contact,
            )
            db.add(inventory)
            db.flush()

        movement = StockMovement(
            inventory_id=inventory.id,
            movement_type="PURCHASE_RECEIPT",
            quantity=payload.quantity,
            balance_after=inventory.available_quantity,
            reference_number=payload.purchase_order_ref or f"PO-{datetime.utcnow().strftime('%Y%m%d%H%M')}",
            reason=payload.notes or "Purchase stock receipt into pharmacy inventory",
            performed_by_user_id=performed_by_user_id,
        )
        db.add(movement)
        db.commit()
        db.refresh(inventory)
        return inventory

    @staticmethod
    def adjust_stock(
        db: Session,
        payload: StockAdjustmentRequest,
        performed_by_user_id: Optional[str] = None,
    ) -> MedicineInventory:
        inventory = db.query(MedicineInventory).filter(MedicineInventory.id == payload.inventory_id).first()
        if not inventory:
            raise NotFoundException(f"Inventory item '{payload.inventory_id}' not found")

        adj_type = payload.adjustment_type.upper()
        if adj_type == "SUBTRACT":
            if inventory.available_quantity < payload.quantity:
                raise BadRequestException(
                    f"Cannot reduce stock below zero. Current stock is {inventory.available_quantity}, requested reduction: {payload.quantity}"
                )
            inventory.available_quantity -= payload.quantity
            qty_delta = -payload.quantity
            movement_type = "ADJUSTMENT_SUBTRACT"
        elif adj_type == "SET":
            qty_delta = payload.quantity - inventory.available_quantity
            inventory.available_quantity = payload.quantity
            movement_type = "ADJUSTMENT_ADD" if qty_delta >= 0 else "ADJUSTMENT_SUBTRACT"
        else: # ADD
            inventory.available_quantity += payload.quantity
            qty_delta = payload.quantity
            movement_type = "ADJUSTMENT_ADD"

        movement = StockMovement(
            inventory_id=inventory.id,
            movement_type=movement_type,
            quantity=qty_delta,
            balance_after=inventory.available_quantity,
            reference_number=payload.reference_number or f"ADJ-{datetime.utcnow().strftime('%Y%m%d%H%M')}",
            reason=payload.reason,
            performed_by_user_id=performed_by_user_id,
        )
        db.add(movement)
        db.commit()
        db.refresh(inventory)
        return inventory

    @staticmethod
    def get_stock_movements(
        db: Session,
        inventory_id: Optional[str] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> List[Dict[str, Any]]:
        q = db.query(StockMovement)
        if inventory_id:
            q = q.filter(StockMovement.inventory_id == inventory_id)
        q = q.order_by(desc(StockMovement.created_at)).offset(offset).limit(limit)
        movements = q.all()

        results = []
        for m in movements:
            med_name = m.inventory.name if m.inventory else None
            batch = m.inventory.batch_number if m.inventory else None
            staff = m.performed_by.full_name if m.performed_by else None
            results.append({
                "id": m.id,
                "inventory_id": m.inventory_id,
                "medicine_name": med_name,
                "batch_number": batch,
                "movement_type": m.movement_type,
                "quantity": m.quantity,
                "balance_after": m.balance_after,
                "reference_number": m.reference_number,
                "reason": m.reason,
                "performed_by_name": staff,
                "created_at": m.created_at,
            })
        return results

    @staticmethod
    def get_prescriptions_for_dispensing(
        db: Session,
        patient_id: Optional[str] = None,
        visit_id: Optional[str] = None,
        status: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        # Retrieve authorized prescriptions (SIGNED or AMENDED or ACTIVE)
        q = db.query(Prescription).filter(
            Prescription.status.in_(["SIGNED", "AMENDED", "ACTIVE", "PARTIAL"])
        )
        if patient_id:
            q = q.filter(Prescription.patient_id == patient_id)
        if visit_id:
            q = q.filter(Prescription.visit_id == visit_id)

        prescriptions = q.order_by(desc(Prescription.created_at)).all()
        results = []
        for rx in prescriptions:
            items_data = []
            for item in rx.items:
                # Find matching inventory batches
                batches = (
                    db.query(MedicineInventory)
                    .filter(
                        MedicineInventory.name.ilike(f"%{item.medicine_name}%"),
                        MedicineInventory.is_active == True,
                    )
                    .order_by(MedicineInventory.expiry_date.asc())
                    .all()
                )
                available_batches = [
                    {
                        "inventory_id": b.id,
                        "batch_number": b.batch_number,
                        "expiry_date": str(b.expiry_date),
                        "available_quantity": b.available_quantity,
                        "unit_price": float(b.unit_price),
                        "is_expired": b.expiry_date <= date.today(),
                    }
                    for b in batches
                ]

                items_data.append({
                    "id": item.id,
                    "medicine_name": item.medicine_name,
                    "form": item.form,
                    "dosage": item.dosage,
                    "route": item.route,
                    "frequency": item.frequency,
                    "duration_days": item.duration_days,
                    "quantity": item.quantity,
                    "timing": item.timing,
                    "instructions": item.instructions,
                    "is_dispensed": item.is_dispensed,
                    "available_batches": available_batches,
                })

            pat = getattr(rx, "patient", None) or (rx.visit.patient if rx.visit and hasattr(rx.visit, "patient") else None) or db.query(Patient).filter(Patient.id == rx.patient_id).first()
            doc = getattr(rx, "doctor", None) or (rx.visit.doctor if rx.visit and hasattr(rx.visit, "doctor") else None)
            results.append({
                "id": rx.id,
                "visit_id": rx.visit_id,
                "patient_id": rx.patient_id,
                "patient_name": pat.full_name if pat else "Unknown",
                "patient_uhid": pat.uhid if pat else "",
                "doctor_name": doc.user.full_name if (doc and hasattr(doc, "user") and doc.user) else "Clinician",
                "status": rx.status,
                "signed_at": rx.signed_at,
                "notes": rx.notes,
                "items": items_data,
            })
        return results

    @staticmethod
    def dispense_prescription(
        db: Session,
        payload: DispensePrescriptionRequest,
        current_user: User,
    ) -> PharmacyDispense:
        # 1. Verify Prescription
        rx = db.query(Prescription).filter(Prescription.id == payload.prescription_id).first()
        if not rx:
            raise NotFoundException(f"Prescription '{payload.prescription_id}' not found")

        # Security check: Prevent unauthorized dispensing from cancelled or draft prescriptions
        if rx.status == "CANCELLED":
            raise BadRequestException("Cannot dispense from a CANCELLED prescription.")
        if rx.status == "DRAFT":
            raise BadRequestException("Cannot dispense from an unsigned DRAFT prescription. Clinician signature required.")

        if not payload.items:
            raise BadRequestException("No medicine items specified for dispensing")

        today = date.today()
        dispense_number = PharmacyService.generate_dispense_number(db)
        total_dispense_amount = Decimal("0.00")
        total_items_count = 0

        dispense = PharmacyDispense(
            dispense_number=dispense_number,
            prescription_id=rx.id,
            visit_id=rx.visit_id,
            patient_id=rx.patient_id,
            dispensed_by_user_id=current_user.id,
            status="COMPLETED",
            notes=payload.notes,
            dispensed_at=datetime.utcnow(),
        )
        db.add(dispense)
        db.flush()

        # 2. Process each item with stock validation and deductions
        for req_item in payload.items:
            inv = db.query(MedicineInventory).filter(MedicineInventory.id == req_item.inventory_id).with_for_update().first()
            if not inv:
                raise NotFoundException(f"Inventory medicine '{req_item.inventory_id}' not found")

            # Check expired batch: "Test expired batches"
            if inv.expiry_date <= today:
                raise BadRequestException(
                    f"Cannot dispense expired medicine '{inv.name}' (Batch: {inv.batch_number}, Expired: {inv.expiry_date})"
                )

            # Check stock deduction bounds: "Prevent dispensing beyond available stock"
            if inv.available_quantity < req_item.quantity_to_dispense:
                raise BadRequestException(
                    f"Insufficient stock for '{inv.name}' (Batch {inv.batch_number}). "
                    f"Requested: {req_item.quantity_to_dispense}, Available: {inv.available_quantity}"
                )

            # Verify against prescribed quantity if prescription item linked
            qty_prescribed = req_item.quantity_to_dispense
            if req_item.prescription_item_id:
                rx_item = db.query(PrescriptionItem).filter(
                    PrescriptionItem.id == req_item.prescription_item_id,
                    PrescriptionItem.prescription_id == rx.id,
                ).first()
                if rx_item:
                    qty_prescribed = rx_item.quantity or req_item.quantity_to_dispense
                    rx_item.is_dispensed = True

            item_unit_price = Decimal(str(inv.unit_price))
            item_total = item_unit_price * Decimal(str(req_item.quantity_to_dispense))
            total_dispense_amount += item_total
            total_items_count += req_item.quantity_to_dispense

            # Real-time stock deduction
            inv.available_quantity -= req_item.quantity_to_dispense

            # Stock movement audit log
            movement = StockMovement(
                inventory_id=inv.id,
                movement_type="DISPENSE",
                quantity=-req_item.quantity_to_dispense,
                balance_after=inv.available_quantity,
                reference_number=dispense_number,
                reason=f"Dispensed for Prescription {rx.id[:8]} (Patient: {rx.patient_id[:8]})",
                performed_by_user_id=current_user.id,
            )
            db.add(movement)

            # Dispense item record
            disp_item = PharmacyDispenseItem(
                dispense_id=dispense.id,
                prescription_item_id=req_item.prescription_item_id,
                inventory_id=inv.id,
                medicine_name=inv.name,
                batch_number=inv.batch_number,
                quantity_prescribed=qty_prescribed,
                quantity_dispensed=req_item.quantity_to_dispense,
                unit_price=item_unit_price,
                total_price=item_total,
                instructions=req_item.instructions,
            )
            db.add(disp_item)

        dispense.total_amount = total_dispense_amount
        dispense.total_items_dispensed = total_items_count

        # Check if all prescription items are dispensed
        all_dispensed = all(item.is_dispensed for item in rx.items)
        rx.status = "DISPENSED" if all_dispensed else "PARTIAL"

        db.commit()
        db.refresh(dispense)
        return dispense

    @staticmethod
    def get_dispenses(
        db: Session,
        patient_id: Optional[str] = None,
        visit_id: Optional[str] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> List[Dict[str, Any]]:
        q = db.query(PharmacyDispense)
        if patient_id:
            q = q.filter(PharmacyDispense.patient_id == patient_id)
        if visit_id:
            q = q.filter(PharmacyDispense.visit_id == visit_id)

        dispenses = q.order_by(desc(PharmacyDispense.dispensed_at)).offset(offset).limit(limit).all()
        results = []
        for d in dispenses:
            items_list = []
            for it in d.items:
                items_list.append({
                    "id": it.id,
                    "inventory_id": it.inventory_id,
                    "prescription_item_id": it.prescription_item_id,
                    "medicine_name": it.medicine_name,
                    "batch_number": it.batch_number,
                    "quantity_prescribed": it.quantity_prescribed,
                    "quantity_dispensed": it.quantity_dispensed,
                    "unit_price": it.unit_price,
                    "total_price": it.total_price,
                    "instructions": it.instructions,
                })

            results.append({
                "id": d.id,
                "dispense_number": d.dispense_number,
                "prescription_id": d.prescription_id,
                "visit_id": d.visit_id,
                "patient_id": d.patient_id,
                "patient_name": d.patient.full_name if d.patient else None,
                "patient_uhid": d.patient.uhid if d.patient else None,
                "dispensed_by_user_id": d.dispensed_by_user_id,
                "dispensed_by_name": d.dispensed_by.full_name if d.dispensed_by else None,
                "status": d.status,
                "total_items_dispensed": d.total_items_dispensed,
                "total_amount": d.total_amount,
                "dispensed_at": d.dispensed_at,
                "notes": d.notes,
                "items": items_list,
            })
        return results

    @staticmethod
    def get_dispense_by_id(db: Session, dispense_id: str) -> Optional[Dict[str, Any]]:
        d = db.query(PharmacyDispense).filter(PharmacyDispense.id == dispense_id).first()
        if not d:
            return None
        items_list = [
            {
                "id": it.id,
                "inventory_id": it.inventory_id,
                "prescription_item_id": it.prescription_item_id,
                "medicine_name": it.medicine_name,
                "batch_number": it.batch_number,
                "quantity_prescribed": it.quantity_prescribed,
                "quantity_dispensed": it.quantity_dispensed,
                "unit_price": it.unit_price,
                "total_price": it.total_price,
                "instructions": it.instructions,
            }
            for it in d.items
        ]
        return {
            "id": d.id,
            "dispense_number": d.dispense_number,
            "prescription_id": d.prescription_id,
            "visit_id": d.visit_id,
            "patient_id": d.patient_id,
            "patient_name": d.patient.full_name if d.patient else None,
            "patient_uhid": d.patient.uhid if d.patient else None,
            "dispensed_by_user_id": d.dispensed_by_user_id,
            "dispensed_by_name": d.dispensed_by.full_name if d.dispensed_by else None,
            "status": d.status,
            "total_items_dispensed": d.total_items_dispensed,
            "total_amount": d.total_amount,
            "dispensed_at": d.dispensed_at,
            "notes": d.notes,
            "items": items_list,
        }
