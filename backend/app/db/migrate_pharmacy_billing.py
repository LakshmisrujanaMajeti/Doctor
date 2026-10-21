import sqlite3
import os
from app.core.database import engine, Base
import app.models # Ensures all models are registered

DB_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "opd_connect.db")

def migrate_pharmacy_billing():
    print("Running Base.metadata.create_all for new tables...")
    Base.metadata.create_all(bind=engine)

    if os.path.exists(DB_PATH):
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # Update existing 'bills' table if missing new decimal-safe & audit columns
        bill_columns = [
            ("subtotal", "NUMERIC(10,2) DEFAULT 0.0"),
            ("discount_type", "VARCHAR(20) DEFAULT 'NONE'"),
            ("discount_rate", "NUMERIC(5,2) DEFAULT 0.0"),
            ("discount_amount", "NUMERIC(10,2) DEFAULT 0.0"),
            ("discount_reason", "VARCHAR(150)"),
            ("taxable_amount", "NUMERIC(10,2) DEFAULT 0.0"),
            ("cgst_amount", "NUMERIC(10,2) DEFAULT 0.0"),
            ("sgst_amount", "NUMERIC(10,2) DEFAULT 0.0"),
            ("igst_amount", "NUMERIC(10,2) DEFAULT 0.0"),
            ("total_tax_amount", "NUMERIC(10,2) DEFAULT 0.0"),
            ("outstanding_balance", "NUMERIC(10,2) DEFAULT 0.0"),
            ("status", "VARCHAR(30) DEFAULT 'ISSUED'"),
            ("billed_by_user_id", "VARCHAR(36)"),
            ("cancellation_reason", "TEXT"),
            ("cancelled_at", "DATETIME"),
            ("notes", "TEXT"),
            ("is_synthetic_pricing", "BOOLEAN DEFAULT 1"),
        ]

        cursor.execute("PRAGMA table_info(bills)")
        existing_bill_cols = {row[1] for row in cursor.fetchall()}

        for col_name, col_type in bill_columns:
            if col_name not in existing_bill_cols:
                try:
                    cursor.execute(f"ALTER TABLE bills ADD COLUMN {col_name} {col_type}")
                    print(f"Added column {col_name} to bills")
                except Exception as e:
                    print(f"Notice on column {col_name} in bills: {e}")

        # Update existing 'bill_items' table if missing columns
        item_columns = [
            ("item_code", "VARCHAR(50)"),
            ("tax_rate_percent", "NUMERIC(5,2) DEFAULT 0.0"),
            ("tax_amount", "NUMERIC(10,2) DEFAULT 0.0"),
            ("reference_id", "VARCHAR(60)"),
        ]

        cursor.execute("PRAGMA table_info(bill_items)")
        existing_item_cols = {row[1] for row in cursor.fetchall()}

        for col_name, col_type in item_columns:
            if col_name not in existing_item_cols:
                try:
                    cursor.execute(f"ALTER TABLE bill_items ADD COLUMN {col_name} {col_type}")
                    print(f"Added column {col_name} to bill_items")
                except Exception as e:
                    print(f"Notice on column {col_name} in bill_items: {e}")

        conn.commit()
        conn.close()

    print("Pharmacy & Billing migration completed successfully.")

if __name__ == "__main__":
    migrate_pharmacy_billing()
