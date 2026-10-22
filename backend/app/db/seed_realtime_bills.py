import sqlite3
import json
import urllib.request
from datetime import datetime

SUPABASE_URL = "https://xxwidqatsxzsrulaxxal.supabase.co/rest/v1"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4d2lkcWF0c3h6c3J1bGF4eGFsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTc3ODA4OCwiZXhwIjoyMTA3MzU0MDg4fQ.eayg90ZSOAT91ZA8c-mt28kRf3NkZOCvJDtTpRLHy8c"

headers = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation,resolution=merge-duplicates"
}

now_str = datetime.utcnow().isoformat() + "Z"
cashier_user_id = "a71ba01d-e928-4985-948f-dedbf4ae407d"

bills_data = [
    {
        "id": "bill-uday-00001",
        "visit_id": "eb3db1bc-6e0e-403e-b883-279b285c7345",
        "patient_id": "746b2fb8-cc53-4e2f-aa85-0388067b1022",
        "invoice_number": "INV-2026-00001",
        "subtotal": "650.00",
        "discount_type": "NONE",
        "discount_rate": "0.00",
        "discount_amount": "0.00",
        "discount_reason": None,
        "taxable_amount": "650.00",
        "cgst_amount": "0.00",
        "sgst_amount": "0.00",
        "igst_amount": "0.00",
        "total_tax_amount": "0.00",
        "total_amount": "650.00",
        "net_amount": "650.00",
        "paid_amount": "650.00",
        "outstanding_balance": "0.00",
        "status": "PAID",
        "payment_status": "PAID",
        "payment_method": "UPI",
        "billed_by_user_id": cashier_user_id,
        "billed_at": "2026-10-21T09:30:00Z",
        "cancellation_reason": None,
        "cancelled_at": None,
        "notes": "Pulmonology Consultation for Uday Kumar",
        "is_synthetic_pricing": 0,
        "created_at": "2026-10-21T09:30:00Z",
        "updated_at": "2026-10-21T09:35:00Z"
    },
    {
        "id": "bill-ravi-00002",
        "visit_id": "363b499a-46e3-4a5b-ad56-a125d14ac7f5",
        "patient_id": "f5c22d18-d291-4992-adbc-01351ac5c40f",
        "invoice_number": "INV-2026-00002",
        "subtotal": "800.00",
        "discount_type": "NONE",
        "discount_rate": "0.00",
        "discount_amount": "0.00",
        "discount_reason": None,
        "taxable_amount": "800.00",
        "cgst_amount": "0.00",
        "sgst_amount": "0.00",
        "igst_amount": "0.00",
        "total_tax_amount": "0.00",
        "total_amount": "800.00",
        "net_amount": "800.00",
        "paid_amount": "500.00",
        "outstanding_balance": "300.00",
        "status": "PARTIALLY_PAID",
        "payment_status": "PARTIAL",
        "payment_method": "CASH",
        "billed_by_user_id": cashier_user_id,
        "billed_at": "2026-10-21T10:15:00Z",
        "cancellation_reason": None,
        "cancelled_at": None,
        "notes": "Neurology Consultation for Ravi",
        "is_synthetic_pricing": 0,
        "created_at": "2026-10-21T10:15:00Z",
        "updated_at": "2026-10-21T10:18:00Z"
    },
    {
        "id": "bill-pavan-00003",
        "visit_id": "c6a9251a-f098-4242-888a-b556c120c1af",
        "patient_id": "b45c7957-b64f-4fd8-b9ef-705bf68da328",
        "invoice_number": "INV-2026-00003",
        "subtotal": "750.00",
        "discount_type": "NONE",
        "discount_rate": "0.00",
        "discount_amount": "0.00",
        "discount_reason": None,
        "taxable_amount": "750.00",
        "cgst_amount": "0.00",
        "sgst_amount": "0.00",
        "igst_amount": "0.00",
        "total_tax_amount": "0.00",
        "total_amount": "750.00",
        "net_amount": "750.00",
        "paid_amount": "750.00",
        "outstanding_balance": "0.00",
        "status": "PAID",
        "payment_status": "PAID",
        "payment_method": "CARD",
        "billed_by_user_id": cashier_user_id,
        "billed_at": "2026-10-22T08:45:00Z",
        "cancellation_reason": None,
        "cancelled_at": None,
        "notes": "Cardiology Consultation for Pavan",
        "is_synthetic_pricing": 0,
        "created_at": "2026-10-22T08:45:00Z",
        "updated_at": "2026-10-22T08:48:00Z"
    },
    {
        "id": "bill-srujana-00004",
        "visit_id": "1e7ab4f3-e305-450d-888b-01a77b6023f5",
        "patient_id": "9791dc19-e67c-4921-8f9b-d1c6c8d12408",
        "invoice_number": "INV-2026-00004",
        "subtotal": "500.00",
        "discount_type": "NONE",
        "discount_rate": "0.00",
        "discount_amount": "0.00",
        "discount_reason": None,
        "taxable_amount": "500.00",
        "cgst_amount": "0.00",
        "sgst_amount": "0.00",
        "igst_amount": "0.00",
        "total_tax_amount": "0.00",
        "total_amount": "500.00",
        "net_amount": "500.00",
        "paid_amount": "500.00",
        "outstanding_balance": "0.00",
        "status": "PAID",
        "payment_status": "PAID",
        "payment_method": "UPI",
        "billed_by_user_id": cashier_user_id,
        "billed_at": "2026-10-22T09:10:00Z",
        "cancellation_reason": None,
        "cancelled_at": None,
        "notes": "General Medicine Consultation for Srujana",
        "is_synthetic_pricing": 0,
        "created_at": "2026-10-22T09:10:00Z",
        "updated_at": "2026-10-22T09:12:00Z"
    }
]

bill_items_data = [
    {
        "id": "item-uday-00001",
        "bill_id": "bill-uday-00001",
        "item_type": "CONSULTATION",
        "item_code": "SRV-CONS-SPEC",
        "description": "Pulmonology Consultation - Dr. Harish Patel, MD",
        "quantity": 1,
        "unit_price": "650.00",
        "tax_rate_percent": "0.00",
        "tax_amount": "0.00",
        "total_price": "650.00",
        "reference_id": "7e3587d5-40d3-49c0-9658-23d9e2d97420",
        "created_at": "2026-10-21T09:30:00Z",
        "updated_at": "2026-10-21T09:30:00Z"
    },
    {
        "id": "item-ravi-00002",
        "bill_id": "bill-ravi-00002",
        "item_type": "CONSULTATION",
        "item_code": "SRV-CONS-SPEC",
        "description": "Neurology Consultation - Dr. Vikram Seth, DM",
        "quantity": 1,
        "unit_price": "800.00",
        "tax_rate_percent": "0.00",
        "tax_amount": "0.00",
        "total_price": "800.00",
        "reference_id": "f5632023-25ec-41bd-a585-4b6e34e398ad",
        "created_at": "2026-10-21T10:15:00Z",
        "updated_at": "2026-10-21T10:15:00Z"
    },
    {
        "id": "item-pavan-00003",
        "bill_id": "bill-pavan-00003",
        "item_type": "CONSULTATION",
        "item_code": "SRV-CONS-SPEC",
        "description": "Cardiology Consultation - Dr. R. Venkatesh, DM",
        "quantity": 1,
        "unit_price": "750.00",
        "tax_rate_percent": "0.00",
        "tax_amount": "0.00",
        "total_price": "750.00",
        "reference_id": "9f06ce12-c0d7-49a2-bcc5-cb0065e16c95",
        "created_at": "2026-10-22T08:45:00Z",
        "updated_at": "2026-10-22T08:45:00Z"
    },
    {
        "id": "item-srujana-00004",
        "bill_id": "bill-srujana-00004",
        "item_type": "CONSULTATION",
        "item_code": "SRV-CONS-SPEC",
        "description": "General Medicine Consultation - Dr. Sarah Chen, MD",
        "quantity": 1,
        "unit_price": "500.00",
        "tax_rate_percent": "0.00",
        "tax_amount": "0.00",
        "total_price": "500.00",
        "reference_id": "46cb6139-e887-48b3-9031-53f462d73966",
        "created_at": "2026-10-22T09:10:00Z",
        "updated_at": "2026-10-22T09:10:00Z"
    }
]

payments_data = [
    {
        "id": "pay-uday-00001",
        "receipt_number": "REC-20261021-00001",
        "bill_id": "bill-uday-00001",
        "patient_id": "746b2fb8-cc53-4e2f-aa85-0388067b1022",
        "amount": "650.00",
        "payment_method": "UPI",
        "payment_status": "COMPLETED",
        "is_online": 1,
        "online_provider": "UPI_QR",
        "gateway_order_id": "order_uday_650",
        "gateway_payment_id": "pay_upi_uday650",
        "idempotency_key": "idem-uday-650",
        "verified_at": "2026-10-21T09:35:00Z",
        "refund_amount": "0.00",
        "refund_reason": None,
        "refunded_at": None,
        "notes": "Paid via SMVMCH Cashier UPI Counter",
        "received_by_user_id": cashier_user_id,
        "created_at": "2026-10-21T09:35:00Z",
        "updated_at": "2026-10-21T09:35:00Z"
    },
    {
        "id": "pay-ravi-00002",
        "receipt_number": "REC-20261021-00002",
        "bill_id": "bill-ravi-00002",
        "patient_id": "f5c22d18-d291-4992-adbc-01351ac5c40f",
        "amount": "500.00",
        "payment_method": "CASH",
        "payment_status": "COMPLETED",
        "is_online": 0,
        "online_provider": "OFFLINE_CASH",
        "gateway_order_id": None,
        "gateway_payment_id": None,
        "idempotency_key": "idem-ravi-500",
        "verified_at": "2026-10-21T10:18:00Z",
        "refund_amount": "0.00",
        "refund_reason": None,
        "refunded_at": None,
        "notes": "Partial cash deposit at billing desk",
        "received_by_user_id": cashier_user_id,
        "created_at": "2026-10-21T10:18:00Z",
        "updated_at": "2026-10-21T10:18:00Z"
    },
    {
        "id": "pay-pavan-00003",
        "receipt_number": "REC-20261022-00001",
        "bill_id": "bill-pavan-00003",
        "patient_id": "b45c7957-b64f-4fd8-b9ef-705bf68da328",
        "amount": "750.00",
        "payment_method": "CARD",
        "payment_status": "COMPLETED",
        "is_online": 0,
        "online_provider": "OFFLINE_POS",
        "gateway_order_id": None,
        "gateway_payment_id": None,
        "idempotency_key": "idem-pavan-750",
        "verified_at": "2026-10-22T08:48:00Z",
        "refund_amount": "0.00",
        "refund_reason": None,
        "refunded_at": None,
        "notes": "POS Card Swipe at counter 2",
        "received_by_user_id": cashier_user_id,
        "created_at": "2026-10-22T08:48:00Z",
        "updated_at": "2026-10-22T08:48:00Z"
    },
    {
        "id": "pay-srujana-00004",
        "receipt_number": "REC-20261022-00002",
        "bill_id": "bill-srujana-00004",
        "patient_id": "9791dc19-e67c-4921-8f9b-d1c6c8d12408",
        "amount": "500.00",
        "payment_method": "UPI",
        "payment_status": "COMPLETED",
        "is_online": 1,
        "online_provider": "UPI_QR",
        "gateway_order_id": "order_srujana_500",
        "gateway_payment_id": "pay_upi_srujana500",
        "idempotency_key": "idem-srujana-500",
        "verified_at": "2026-10-22T09:12:00Z",
        "refund_amount": "0.00",
        "refund_reason": None,
        "refunded_at": None,
        "notes": "Paid via UPI QR Code",
        "received_by_user_id": cashier_user_id,
        "created_at": "2026-10-22T09:12:00Z",
        "updated_at": "2026-10-22T09:12:00Z"
    }
]

def seed_sqlite():
    conn = sqlite3.connect("backend/opd_connect.db")
    c = conn.cursor()
    
    for b in bills_data:
        cols = list(b.keys())
        placeholders = ", ".join(["?"] * len(cols))
        col_names = ", ".join(cols)
        c.execute(f"INSERT OR REPLACE INTO bills ({col_names}) VALUES ({placeholders})", list(b.values()))
        
    for it in bill_items_data:
        cols = list(it.keys())
        placeholders = ", ".join(["?"] * len(cols))
        col_names = ", ".join(cols)
        c.execute(f"INSERT OR REPLACE INTO bill_items ({col_names}) VALUES ({placeholders})", list(it.values()))
        
    for p in payments_data:
        cols = list(p.keys())
        placeholders = ", ".join(["?"] * len(cols))
        col_names = ", ".join(cols)
        c.execute(f"INSERT OR REPLACE INTO payment_transactions ({col_names}) VALUES ({placeholders})", list(p.values()))
        
    conn.commit()
    conn.close()
    print("Seeded SQLite bills successfully!")

def seed_supabase():
    # Insert or update bills
    req_b = urllib.request.Request(
        f"{SUPABASE_URL}/bills",
        data=json.dumps(bills_data).encode("utf-8"),
        headers=headers,
        method="POST"
    )
    try:
        with urllib.request.urlopen(req_b) as resp:
            print("Supabase bills synced:", resp.status)
    except Exception as e:
        print("Supabase bills sync error:", e)
        if hasattr(e, 'read'):
            print(e.read().decode())

    # Insert or update bill_items
    req_it = urllib.request.Request(
        f"{SUPABASE_URL}/bill_items",
        data=json.dumps(bill_items_data).encode("utf-8"),
        headers=headers,
        method="POST"
    )
    try:
        with urllib.request.urlopen(req_it) as resp:
            print("Supabase bill_items synced:", resp.status)
    except Exception as e:
        print("Supabase bill_items sync error:", e)
        if hasattr(e, 'read'):
            print(e.read().decode())

    # Insert or update payments
    supa_payments = []
    for p in payments_data:
        p_copy = dict(p)
        p_copy["is_online"] = bool(p["is_online"])
        supa_payments.append(p_copy)
        
    req_p = urllib.request.Request(
        f"{SUPABASE_URL}/payment_transactions",
        data=json.dumps(supa_payments).encode("utf-8"),
        headers=headers,
        method="POST"
    )
    try:
        with urllib.request.urlopen(req_p) as resp:
            print("Supabase payment_transactions synced:", resp.status)
    except Exception as e:
        print("Supabase payment_transactions sync error:", e)
        if hasattr(e, 'read'):
            print(e.read().decode())

if __name__ == "__main__":
    seed_sqlite()
    seed_supabase()
