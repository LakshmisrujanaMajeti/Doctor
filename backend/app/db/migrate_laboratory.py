import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "opd_connect.db")

def migrate_laboratory_tables():
    if not os.path.exists(DB_PATH):
        print(f"Database not found at {DB_PATH}")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Columns for lab_orders
    order_columns = [
        ("order_number", "VARCHAR(50)"),
        ("specimen_id", "VARCHAR(50)"),
        ("specimen_type", "VARCHAR(80)"),
        ("specimen_status", "VARCHAR(30) DEFAULT 'PENDING_COLLECTION'"),
        ("collected_at", "DATETIME"),
        ("collected_by_name", "VARCHAR(100)"),
        ("received_at", "DATETIME"),
        ("received_by_name", "VARCHAR(100)"),
        ("rejection_reason", "TEXT"),
        ("is_sensitive", "BOOLEAN DEFAULT 0"),
        ("requires_review", "BOOLEAN DEFAULT 0"),
        ("verified_by_user_id", "VARCHAR(36)"),
        ("verified_by_name", "VARCHAR(100)"),
        ("verified_at", "DATETIME"),
        ("verification_notes", "TEXT"),
        ("published_to_visit", "BOOLEAN DEFAULT 0"),
    ]

    cursor.execute("PRAGMA table_info(lab_orders)")
    existing_order_cols = {row[1] for row in cursor.fetchall()}

    for col_name, col_type in order_columns:
        if col_name not in existing_order_cols:
            try:
                cursor.execute(f"ALTER TABLE lab_orders ADD COLUMN {col_name} {col_type}")
                print(f"Added column {col_name} to lab_orders")
            except Exception as e:
                print(f"Error adding {col_name} to lab_orders: {e}")

    # Columns for lab_results
    result_columns = [
        ("is_critical", "BOOLEAN DEFAULT 0"),
        ("flag", "VARCHAR(20) DEFAULT 'NORMAL'"),
        ("verified_at", "DATETIME"),
    ]

    cursor.execute("PRAGMA table_info(lab_results)")
    existing_result_cols = {row[1] for row in cursor.fetchall()}

    for col_name, col_type in result_columns:
        if col_name not in existing_result_cols:
            try:
                cursor.execute(f"ALTER TABLE lab_results ADD COLUMN {col_name} {col_type}")
                print(f"Added column {col_name} to lab_results")
            except Exception as e:
                print(f"Error adding {col_name} to lab_results: {e}")

    conn.commit()
    conn.close()
    print("Laboratory migration completed successfully.")

if __name__ == "__main__":
    migrate_laboratory_tables()
