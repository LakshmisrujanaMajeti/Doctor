import uuid
from decimal import Decimal
import pytest
from datetime import date, timedelta
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def get_token(email: str, password: str) -> str:
    res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert res.status_code == 200, f"Login failed for {email}: {res.text}"
    return res.json()["data"]["access_token"]


@pytest.fixture(scope="module")
def admin_token():
    return get_token("admin@opdconnect.com", "Admin@123456")


@pytest.fixture(scope="module")
def doctor_token():
    return get_token("dr.chen@opdconnect.com", "Doctor@123456")


@pytest.fixture(scope="module")
def pharmacist_token():
    return get_token("pharmacist@opdconnect.com", "Pharmacy@123456")


@pytest.fixture(scope="module")
def receptionist_token():
    return get_token("receptionist@opdconnect.com", "Reception@123456")


@pytest.fixture(scope="module")
def patient_token():
    return get_token("patient@opdconnect.com", "Patient@123456")


def test_pharmacy_inventory_search_and_stats(pharmacist_token):
    headers = {"Authorization": f"Bearer {pharmacist_token}"}
    
    # 1. Stats endpoint
    res = client.get("/api/v1/pharmacy/inventory/stats", headers=headers)
    assert res.status_code == 200
    stats = res.json()["data"]
    assert "total_medicines" in stats
    assert "low_stock_count" in stats
    assert "expiring_soon_count" in stats
    assert "expired_count" in stats
    assert stats["total_medicines"] > 0
    assert stats["expired_count"] >= 1 # We seeded an expired batch

    # 2. Search endpoint
    res_search = client.get("/api/v1/pharmacy/inventory?query=Paracetamol", headers=headers)
    assert res_search.status_code == 200
    items = res_search.json()["data"]
    assert len(items) >= 1
    pcm = items[0]
    assert "Paracetamol" in pcm["name"]
    assert pcm["is_synthetic_price"] is True
    assert float(pcm["unit_price"]) > 0

    # 3. Filter for low stock
    res_low = client.get("/api/v1/pharmacy/inventory?low_stock=true", headers=headers)
    assert res_low.status_code == 200
    low_items = res_low.json()["data"]
    assert any(item["is_low_stock"] for item in low_items)


def test_stock_receipt_and_adjustment_audit_trail(pharmacist_token):
    headers = {"Authorization": f"Bearer {pharmacist_token}"}

    # 1. Receive new stock batch
    exp_date = (date.today() + timedelta(days=365)).isoformat()
    unique_batch = f"BAT-IBU-{uuid.uuid4().hex[:6].upper()}"
    receipt_payload = {
        "name": "Ibuprofen Test Batch",
        "generic_name": "Ibuprofen",
        "strength": "400 mg",
        "dosage_form": "Tablet",
        "batch_number": unique_batch,
        "expiry_date": exp_date,
        "quantity": 100,
        "unit_price": 4.50,
        "tax_classification": "GST_5",
        "supplier_name": "Apex Pharma Supplies",
        "purchase_order_ref": "PO-TEST-901",
        "notes": "Emergency restock receipt",
    }
    res_rec = client.post("/api/v1/pharmacy/inventory/receive", json=receipt_payload, headers=headers)
    assert res_rec.status_code in [200, 201]
    inv_data = res_rec.json()["data"]
    inv_id = inv_data["id"]
    assert inv_data["available_quantity"] == 100

    # 2. Stock adjustment: Deduct 10 units with clinical reason
    adj_payload = {
        "inventory_id": inv_id,
        "adjustment_type": "SUBTRACT",
        "quantity": 10,
        "reason": "Damaged blister packaging during shelf stacking",
    }
    res_adj = client.post("/api/v1/pharmacy/inventory/adjust", json=adj_payload, headers=headers)
    assert res_adj.status_code == 200
    assert res_adj.json()["data"]["available_quantity"] == 90

    # 3. Prevent adjusting below zero
    adj_invalid = {
        "inventory_id": inv_id,
        "adjustment_type": "SUBTRACT",
        "quantity": 200,
        "reason": "Excessive subtraction attempt",
    }
    res_err = client.post("/api/v1/pharmacy/inventory/adjust", json=adj_invalid, headers=headers)
    assert res_err.status_code == 400

    # 4. Check stock movements audit trail
    res_mov = client.get(f"/api/v1/pharmacy/inventory/movements?inventory_id={inv_id}", headers=headers)
    assert res_mov.status_code == 200
    movs = res_mov.json()["data"]
    assert len(movs) >= 2 # 1 PURCHASE_RECEIPT and 1 ADJUSTMENT_SUBTRACT


def test_prescription_dispensing_workflow_and_stock_deduction(
    doctor_token, pharmacist_token, receptionist_token
):
    doc_headers = {"Authorization": f"Bearer {doctor_token}"}
    pharm_headers = {"Authorization": f"Bearer {pharmacist_token}"}

    # 1. Create visit and signed prescription
    vis_res = client.post(
        "/api/v1/visits",
        json={
            "patient_id": "test-pat-1", # from seeded or existing patient
            "department_id": "dept-1",
            "doctor_id": "doc-1",
            "visit_type": "NEW",
            "priority": "ROUTINE",
        },
        headers={"Authorization": f"Bearer {receptionist_token}"},
    )
    # If test-pat-1 not found, pick an existing visit
    visits_res = client.get("/api/v1/visits", headers=doc_headers)
    assert visits_res.status_code == 200
    visit = visits_res.json()["data"][0]
    visit_id = visit["id"]
    patient_id = visit["patient_id"]

    # Create signed prescription
    rx_payload = {
        "visit_id": visit_id,
        "notes": "Post consultation regimen",
        "allergy_warning_acknowledged": True,
        "items": [
            {
                "medicine_name": "Paracetamol",
                "form": "Tablet",
                "dosage": "650 mg",
                "route": "Oral",
                "frequency": "TID",
                "duration_days": 3,
                "quantity": 6,
                "timing": "After Food",
                "instructions": "For fever",
            }
        ],
    }
    rx_res = client.post("/api/v1/prescriptions", json=rx_payload, headers=doc_headers)
    assert rx_res.status_code in [200, 201]
    rx_data = rx_res.json()["data"]
    rx_id = rx_data["id"]
    rx_item_id = rx_data["items"][0]["id"]

    # 2. Get prescriptions ready for dispensing
    ready_res = client.get(f"/api/v1/pharmacy/prescriptions?visit_id={visit_id}", headers=pharm_headers)
    assert ready_res.status_code == 200
    ready_list = ready_res.json()["data"]
    assert any(r["id"] == rx_id for r in ready_list)

    # Find the Paracetamol batch
    inv_search = client.get("/api/v1/pharmacy/inventory?query=Paracetamol", headers=pharm_headers)
    pcm_batch = [item for item in inv_search.json()["data"] if not item["is_expired"]][0]
    initial_stock = pcm_batch["available_quantity"]

    # 3. Dispense prescription items
    disp_payload = {
        "prescription_id": rx_id,
        "items": [
            {
                "prescription_item_id": rx_item_id,
                "inventory_id": pcm_batch["id"],
                "quantity_to_dispense": 6,
                "instructions": "Take after meals",
            }
        ],
        "notes": "Verified patient identity and dispensed",
    }
    disp_res = client.post("/api/v1/pharmacy/dispense", json=disp_payload, headers=pharm_headers)
    assert disp_res.status_code == 201
    disp_record = disp_res.json()["data"]
    assert disp_record["status"] == "COMPLETED"
    assert disp_record["total_items_dispensed"] == 6
    assert float(disp_record["total_amount"]) == round(6 * float(pcm_batch["unit_price"]), 2)

    # 4. Verify stock was deducted in real time
    inv_after = client.get(f"/api/v1/pharmacy/inventory?query=Paracetamol", headers=pharm_headers)
    pcm_after = [item for item in inv_after.json()["data"] if item["id"] == pcm_batch["id"]][0]
    assert pcm_after["available_quantity"] == initial_stock - 6

    # 5. Verify traceable dispensing history
    history_res = client.get(f"/api/v1/pharmacy/dispenses?visit_id={visit_id}", headers=pharm_headers)
    assert history_res.status_code == 200
    assert len(history_res.json()["data"]) >= 1


def test_safety_reject_dispensing_expired_and_cancelled_prescriptions(
    doctor_token, pharmacist_token
):
    doc_headers = {"Authorization": f"Bearer {doctor_token}"}
    pharm_headers = {"Authorization": f"Bearer {pharmacist_token}"}

    # Pick visit
    visits_res = client.get("/api/v1/visits", headers=doc_headers)
    visit = visits_res.json()["data"][0]

    # Create prescription and then cancel it
    rx_payload = {
        "visit_id": visit["id"],
        "notes": "Prescription to be cancelled",
        "allergy_warning_acknowledged": True,
        "items": [
            {
                "medicine_name": "Cetirizine",
                "dosage": "10 mg",
                "frequency": "OD",
                "duration_days": 5,
                "quantity": 5,
            }
        ],
    }
    rx_res = client.post("/api/v1/prescriptions", json=rx_payload, headers=doc_headers)
    rx_id = rx_res.json()["data"]["id"]

    # Cancel prescription
    cancel_res = client.post(f"/api/v1/prescriptions/{rx_id}/cancel?reason=Discontinued", headers=doc_headers)
    assert cancel_res.status_code == 200

    # Locate Cetirizine inventory
    inv_search = client.get("/api/v1/pharmacy/inventory?query=Cetirizine", headers=pharm_headers)
    ctz_batch = inv_search.json()["data"][0]

    # 1. Attempt to dispense cancelled prescription -> Must be rejected (400)
    disp_cancelled = {
        "prescription_id": rx_id,
        "items": [
            {
                "inventory_id": ctz_batch["id"],
                "quantity_to_dispense": 5,
            }
        ],
    }
    res_err1 = client.post("/api/v1/pharmacy/dispense", json=disp_cancelled, headers=pharm_headers)
    assert res_err1.status_code == 400
    assert "CANCELLED" in res_err1.text

    # 2. Attempt to dispense expired batch -> Must be rejected (400)
    inv_expired = client.get("/api/v1/pharmacy/inventory?query=Tetracycline", headers=pharm_headers)
    exp_batch = inv_expired.json()["data"][0]
    assert exp_batch["is_expired"] is True

    # Valid prescription for testing expired batch
    rx2_payload = {
        "visit_id": visit["id"],
        "allergy_warning_acknowledged": True,
        "items": [{"medicine_name": "Tetracycline", "dosage": "250 mg", "frequency": "BD", "duration_days": 2, "quantity": 4}],
    }
    rx2_res = client.post("/api/v1/prescriptions", json=rx2_payload, headers=doc_headers)
    rx2_id = rx2_res.json()["data"]["id"]

    disp_expired = {
        "prescription_id": rx2_id,
        "items": [
            {
                "inventory_id": exp_batch["id"],
                "quantity_to_dispense": 4,
            }
        ],
    }
    res_err2 = client.post("/api/v1/pharmacy/dispense", json=disp_expired, headers=pharm_headers)
    assert res_err2.status_code == 400
    assert "expired" in res_err2.text.lower()


def test_billing_decimal_arithmetic_tax_breakdown_and_invoice_creation(receptionist_token):
    headers = {"Authorization": f"Bearer {receptionist_token}"}

    # 1. Service Catalogue
    cat_res = client.get("/api/v1/billing/services-catalogue", headers=headers)
    assert cat_res.status_code == 200
    services = cat_res.json()["data"]
    assert len(services) >= 4
    assert any(s["is_synthetic"] for s in services)

    # Pick a visit
    visits_res = client.get("/api/v1/visits", headers=headers)
    visit = visits_res.json()["data"][0]

    # 2. Create itemized bill with consultation + procedure + 10% discount
    # Consultation: 300.00 @ 0% tax = 300.00
    # Dressing Procedure: 150.00 @ 5% tax = 150.00 + 7.50 = 157.50
    # Subtotal base = 450.00
    # Discount: 10% on 450.00 = 45.00
    # Taxable amount = 450.00 - 45.00 = 405.00
    # Total tax = 7.50 (CGST 3.75, SGST 3.75)
    # Total amount = 405.00 + 7.50 = 412.50
    bill_payload = {
        "visit_id": visit["id"],
        "discount_type": "PERCENTAGE",
        "discount_rate": 10.0,
        "discount_reason": "Senior Citizen Concession",
        "payment_method": "CASH",
        "paid_amount": 0.0,
        "items": [
            {
                "item_type": "CONSULTATION",
                "item_code": "SRV-CONS-GEN",
                "description": "General OPD Consultation",
                "unit_price": 300.00,
                "quantity": 1,
                "tax_rate_percent": 0.0,
            },
            {
                "item_type": "PROCEDURE",
                "item_code": "SRV-PROC-DRESS",
                "description": "Minor Wound Dressing & Aseptic Bandage",
                "unit_price": 150.00,
                "quantity": 1,
                "tax_rate_percent": 5.0,
            },
        ],
    }

    res_bill = client.post("/api/v1/billing", json=bill_payload, headers=headers)
    assert res_bill.status_code in [200, 201]
    bill = res_bill.json()["data"]

    # Verify decimal-safe monetary arithmetic
    assert float(bill["subtotal"]) == 450.00
    assert float(bill["discount_amount"]) == 45.00
    assert float(bill["taxable_amount"]) == 405.00
    assert float(bill["total_tax_amount"]) == 7.50
    assert float(bill["cgst_amount"]) == 3.75
    assert float(bill["sgst_amount"]) == 3.75
    assert float(bill["total_amount"]) == 412.50
    assert float(bill["outstanding_balance"]) == 412.50
    assert bill["payment_status"] == "UNPAID"
    assert bill["status"] == "ISSUED"


def test_payment_idempotent_callback_and_refunds(receptionist_token):
    headers = {"Authorization": f"Bearer {receptionist_token}"}

    # 1. Create a bill of 500.00
    visits_res = client.get("/api/v1/visits", headers=headers)
    visit = visits_res.json()["data"][0]

    bill_payload = {
        "visit_id": visit["id"],
        "items": [
            {
                "item_type": "CONSULTATION",
                "description": "Specialist Clinician Consultation",
                "unit_price": 500.00,
                "quantity": 1,
                "tax_rate_percent": 0.0,
            }
        ],
    }
    res_b = client.post("/api/v1/billing", json=bill_payload, headers=headers)
    bill_id = res_b.json()["data"]["id"]

    # 2. Test Online Payment Flow: "Do not automatically mark a payment successful because a user clicks Pay."
    online_req = {
        "amount": 500.00,
        "payment_method": "ONLINE",
        "is_online": True,
    }
    pay_init = client.post(f"/api/v1/billing/{bill_id}/payments", json=online_req, headers=headers)
    assert pay_init.status_code in [200, 201]
    init_data = pay_init.json()["data"]
    assert init_data["payment_status"] == "PENDING"
    order_id = init_data["gateway_order_id"]

    # Bill is still UNPAID before webhook callback
    bill_check = client.get(f"/api/v1/billing/{bill_id}", headers=headers).json()["data"]
    assert bill_check["payment_status"] == "UNPAID"
    assert float(bill_check["outstanding_balance"]) == 500.00

    # 3. Simulate Gateway Callback
    mock_pay_id = f"pay_mock_{uuid.uuid4().hex[:8]}"
    mock_idemp_key = f"idemp-key-{uuid.uuid4().hex[:8]}"
    callback_payload = {
        "gateway_order_id": order_id,
        "gateway_payment_id": mock_pay_id,
        "amount": 500.00,
        "idempotency_key": mock_idemp_key,
        "status": "SUCCESS",
    }
    cb_res = client.post("/api/v1/billing/payments/callback", json=callback_payload)
    assert cb_res.status_code == 200
    assert cb_res.json()["data"]["payment_status"] == "COMPLETED"

    # Bill is now PAID
    bill_paid = client.get(f"/api/v1/billing/{bill_id}", headers=headers).json()["data"]
    assert bill_paid["payment_status"] == "PAID"
    assert float(bill_paid["outstanding_balance"]) == 0.00
    assert float(bill_paid["paid_amount"]) == 500.00

    # 4. Test Duplicate Payment Callback: "Test duplicate payment callbacks" (Idempotency)
    cb_dup = client.post("/api/v1/billing/payments/callback", json=callback_payload)
    assert cb_dup.status_code == 200
    # Must NOT double-credit
    bill_after_dup = client.get(f"/api/v1/billing/{bill_id}", headers=headers).json()["data"]
    assert float(bill_after_dup["paid_amount"]) == 500.00

    # 5. Test Refunds: "Test refunds"
    # Over-refund must be rejected
    refund_excess = {"refund_amount": 700.00, "reason": "Excessive refund test"}
    res_ref_err = client.post(f"/api/v1/billing/{bill_id}/refund", json=refund_excess, headers=headers)
    assert res_ref_err.status_code == 400

    # Valid Partial Refund of 200.00
    refund_valid = {"refund_amount": 200.00, "reason": "Patient discharged early"}
    res_ref = client.post(f"/api/v1/billing/{bill_id}/refund", json=refund_valid, headers=headers)
    assert res_ref.status_code == 200
    ref_data = res_ref.json()["data"]
    assert ref_data["refund_amount"] == 200.00

    # Verify adjusted bill balance: paid_amount = 300.00, outstanding = 200.00, status = PARTIALLY_PAID
    bill_after_ref = client.get(f"/api/v1/billing/{bill_id}", headers=headers).json()["data"]
    assert float(bill_after_ref["paid_amount"]) == 300.00
    assert float(bill_after_ref["outstanding_balance"]) == 200.00
    assert bill_after_ref["payment_status"] == "PARTIAL"

    # 6. Printable Receipt
    receipt_res = client.get(f"/api/v1/billing/{bill_id}/receipt", headers=headers)
    assert receipt_res.status_code == 200
    receipt_data = receipt_res.json()["data"]
    assert "OPD CONNECT+ HOSPITAL" in receipt_data["hospital_name"]
    assert receipt_data["is_synthetic_pricing"] is True
