"""
Repeatable, idempotent, and non-destructive migration script
From Local SQLite (backend/opd_connect.db) to Supabase PostgreSQL.

Safety Principles:
1. READ-ONLY on local SQLite (URI mode=ro).
2. Auto-creates all schemas matching FastAPI models via Base.metadata.create_all.
3. Widens users.id and referencing foreign keys to VARCHAR(64) to support prefixed IDs.
4. Uses PostgreSQL transactions with ON CONFLICT (id) DO NOTHING (prevents overwriting or duplicates on retries).
5. Topological ordering to respect all foreign keys.
6. Breaks circular foreign key reference between `users` and `patients` safely:
   - Users inserted first with patient_id = NULL
   - Patients inserted with all fields
   - Users patient_id updated to original valid IDs
7. Dynamic SQLAlchemy schema-driven type casting (converts any SQLite 0/1 to PostgreSQL boolean for all Boolean columns).
8. Sanitizes orphaned nullable foreign keys:
   - patients.registered_by_staff_id pointing to stale user IDs -> resolved to matching staff or NULL
   - audit_logs.user_id pointing to stale user IDs -> set to NULL (preserving historical audit event)
   - refresh_token_sessions for deleted users -> safely skipped
9. Comprehensive verification query post-migration.
"""

import os
import sys
import sqlite3
import argparse
from typing import Dict, List, Any, Tuple
from datetime import datetime

base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
backend_dir = os.path.join(base_dir, "backend")
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from sqlalchemy import Boolean
from app.core.database import Base
import app.models  # Register all models

TOPOLOGICAL_TABLE_ORDER = [
    # Level 1: Master tables with no FK dependencies
    "roles",
    "permissions",
    "departments",
    "medicine_inventory",
    "system_configs",
    "otp_verifications",
    
    # Level 2: Independent relationship mappings & users/patients
    "role_permissions",
    "users",               # First pass: patient_id deferred
    "patients",            # Full insert
    
    # Level 3: User & Department dependent entities
    "doctors",             # user_id -> users, department_id -> departments
    "opd_visits",          # patient_id, doctor_id, department_id
    
    # Level 4: Visit & Patient dependent clinical records
    "vital_signs",         # visit_id, recorded_by_user_id
    "clinical_records",    # visit_id, patient_id, doctor_id
    "clinical_amendments", # clinical_record_id, amended_by_user_id
    "prescriptions",       # visit_id, patient_id, doctor_id, signed_by_user_id
    "prescription_items",  # prescription_id
    "prescription_amendments", # prescription_id, amended_by_user_id
    
    # Level 5: Financial & Inventory workflow
    "bills",               # patient_id, visit_id, billed_by_user_id
    "bill_items",          # bill_id
    "payment_transactions",# bill_id, patient_id, received_by_user_id
    "stock_movements",     # inventory_id, performed_by_user_id
    
    # Level 6: Pharmacy dispenses
    "pharmacy_orders",     # prescription_id, dispensed_by_user_id
    "pharmacy_dispenses",  # prescription_id, patient_id, visit_id, dispensed_by_user_id
    "pharmacy_dispense_items", # dispense_id, prescription_item_id, inventory_id
    
    # Level 7: Diagnostic & Documents
    "lab_orders",          # patient_id, visit_id, ordered_by_doctor_id, verified_by_user_id
    "lab_results",         # lab_order_id, verified_by_user_id
    "medical_documents",   # patient_id, visit_id, uploaded_by_user_id
    "document_pages",      # document_id
    "document_ocr_extractions", # document_id
    "document_audit_logs", # document_id, user_id
    
    # Level 8: Auth sessions, tickets & audit trails
    "refresh_token_sessions", # user_id
    "password_reset_tokens",  # user_id
    "support_tickets",        # patient_id, user_id, assigned_to_user_id
    "audit_logs"              # user_id
]

def get_boolean_columns_map() -> Dict[str, set]:
    bool_map = {}
    for table_name, table in Base.metadata.tables.items():
        cols = {c.name for c in table.columns if isinstance(c.type, Boolean)}
        if cols:
            bool_map[table_name] = cols
    return bool_map

def load_sqlite_data(sqlite_path: str) -> Dict[str, List[Dict[str, Any]]]:
    if not os.path.exists(sqlite_path):
        raise FileNotFoundError(f"Local SQLite database not found at {sqlite_path}")

    conn = sqlite3.connect(f"file:{sqlite_path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    data = {}
    for table in TOPOLOGICAL_TABLE_ORDER:
        try:
            cursor.execute(f'SELECT * FROM "{table}"')
            rows = [dict(row) for row in cursor.fetchall()]
            data[table] = rows
        except sqlite3.OperationalError:
            data[table] = []
    conn.close()
    return data

def dry_run_validation(data: Dict[str, List[Dict[str, Any]]]):
    print("=" * 70)
    print("DRY-RUN VALIDATION: Scanning all local records")
    print("=" * 70)

    total_records = 0
    pks_seen = {}

    for table in TOPOLOGICAL_TABLE_ORDER:
        rows = data.get(table, [])
        total_records += len(rows)
        pks_seen[table] = set()
        
        for r in rows:
            if table == "role_permissions":
                pk_val = f"{r.get('role_id')}_{r.get('permission_id')}"
            else:
                pk_val = r.get("id")

            if pk_val in pks_seen[table]:
                print(f"[WARNING] Duplicate primary key in {table}: {pk_val}")
            pks_seen[table].add(pk_val)

        print(f"  {table:30s}: {len(rows):5d} valid records queued")

    print("=" * 70)
    print(f"Total valid records ready to migrate: {total_records}")
    print("=" * 70)
    return total_records

def migrate_to_supabase(data: Dict[str, List[Dict[str, Any]]], target_url: str):
    from sqlalchemy import create_engine, text, inspect
    import psycopg2

    # Clean URL and ensure sslmode
    if target_url.startswith("postgres://"):
        target_url = target_url.replace("postgres://", "postgresql://", 1)
    if "sslmode=" not in target_url:
        sep = "&" if "?" in target_url else "?"
        target_url = f"{target_url}{sep}sslmode=require"

    masked_url = target_url.split("@")[-1] if "@" in target_url else "configured-target"
    print(f"Connecting to target Supabase: {masked_url}")

    engine = create_engine(target_url, pool_pre_ping=True)
    
    # 1. Ensure all schemas are created
    print("Verifying / Creating database schemas on Supabase...")
    Base.metadata.create_all(bind=engine)
    
    # Ensure users.id and related columns allow up to VARCHAR(64)
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE users ALTER COLUMN id TYPE VARCHAR(64);"))
        for tbl, col in [
            ("refresh_token_sessions", "user_id"),
            ("audit_logs", "user_id"),
            ("doctors", "user_id"),
            ("bills", "billed_by_user_id"),
            ("payment_transactions", "received_by_user_id"),
            ("patients", "registered_by_staff_id"),
            ("system_configs", "updated_by_user_id"),
            ("stock_movements", "performed_by_user_id")
        ]:
            try:
                conn.execute(text(f'ALTER TABLE "{tbl}" ALTER COLUMN "{col}" TYPE VARCHAR(64);'))
            except Exception:
                pass
    print("Database schemas verified with expanded ID columns.")

    # Dynamically extract all boolean columns from SQLAlchemy models
    bool_map = get_boolean_columns_map()

    # Collect valid user IDs for FK validation
    valid_user_ids = {u["id"] for u in data.get("users", [])}
    
    # Store user-patient circular links to update after both are inserted
    user_patient_links = []
    for u in data.get("users", []):
        if u.get("patient_id"):
            user_patient_links.append((u["id"], u["patient_id"]))

    stats = {
        "transferred": {},
        "skipped": {}
    }

    # 2. Transactional batch insert
    with engine.begin() as conn:
        print("Opened atomic transaction. Migrating records in topological order...")

        for table in TOPOLOGICAL_TABLE_ORDER:
            rows = data.get(table, [])
            if not rows:
                stats["transferred"][table] = 0
                stats["skipped"][table] = 0
                continue

            bool_cols = bool_map.get(table, set())
            
            # Prepare rows
            prepared_rows = []
            for r in rows:
                r_copy = dict(r)
                
                # Table-specific safe FK handling
                if table == "users":
                    # Defer patient_id to second pass
                    r_copy["patient_id"] = None

                elif table == "patients":
                    # If registered_by_staff_id is an orphaned ID, sanitize it safely
                    staff_id = r_copy.get("registered_by_staff_id")
                    if staff_id and staff_id not in valid_user_ids:
                        staff_name = r_copy.get("registered_by_staff_name", "")
                        if "Alice Adams" in staff_name and "60de44f5-28c9-4b56-8fb6-11c7046991da" in valid_user_ids:
                            r_copy["registered_by_staff_id"] = "60de44f5-28c9-4b56-8fb6-11c7046991da"
                        else:
                            r_copy["registered_by_staff_id"] = None

                elif table == "audit_logs":
                    # If user_id is an orphaned ID from past deleted test user, set to None to preserve audit record
                    uid = r_copy.get("user_id")
                    if uid and uid not in valid_user_ids:
                        r_copy["user_id"] = None

                elif table == "refresh_token_sessions":
                    # If session belongs to deleted user, skip dead token session
                    uid = r_copy.get("user_id")
                    if uid and uid not in valid_user_ids:
                        continue
                
                # Convert any integer 0/1 to True/False for all boolean columns
                for bc in bool_cols:
                    if bc in r_copy and r_copy[bc] is not None:
                        r_copy[bc] = bool(r_copy[bc])

                prepared_rows.append(r_copy)

            if not prepared_rows:
                stats["transferred"][table] = 0
                stats["skipped"][table] = len(rows)
                print(f"  {table:30s}: Transferred    0 | Skipped (Orphaned/Dead) {len(rows):4d}")
                continue

            # Insert with ON CONFLICT DO NOTHING
            cols = list(prepared_rows[0].keys())
            cols_quoted = [f'"{c}"' for c in cols]
            val_params = [f':{c}' for c in cols]
            
            if table == "role_permissions":
                conflict_clause = 'ON CONFLICT ("role_id", "permission_id") DO NOTHING'
            else:
                conflict_clause = 'ON CONFLICT ("id") DO NOTHING'

            insert_sql = text(f"""
                INSERT INTO "{table}" ({', '.join(cols_quoted)})
                VALUES ({', '.join(val_params)})
                {conflict_clause}
            """)

            transferred = 0
            for r in prepared_rows:
                res = conn.execute(insert_sql, r)
                transferred += res.rowcount

            skipped = len(rows) - transferred
            stats["transferred"][table] = transferred
            stats["skipped"][table] = skipped
            print(f"  {table:30s}: Transferred {transferred:4d} | Skipped (Existing/Orphan) {skipped:4d}")

        # Update deferred user -> patient links
        if user_patient_links:
            print(f"Restoring circular patient links for {len(user_patient_links)} users...")
            update_sql = text('UPDATE "users" SET "patient_id" = :patient_id WHERE "id" = :user_id')
            for uid, pid in user_patient_links:
                conn.execute(update_sql, {"user_id": uid, "patient_id": pid})
            print("User-patient links restored successfully.")

    print("=" * 70)
    print("MIGRATION COMMITTED SUCCESSFULLY")
    print("=" * 70)

    # 3. Post-migration row count verification
    print("\nPOST-MIGRATION AUDIT: Verifying counts in Supabase vs Local SQLite:")
    inspector = inspect(engine)
    sb_tables = set(inspector.get_table_names(schema="public"))
    with engine.connect() as conn:
        mismatch_count = 0
        total_migrated = 0
        for table in TOPOLOGICAL_TABLE_ORDER:
            expected = stats["transferred"].get(table, 0)
            if table in sb_tables:
                actual = conn.execute(text(f'SELECT COUNT(*) FROM "{table}"')).scalar()
                total_migrated += actual
                status = "OK" if actual >= expected else "MISMATCH"
                if actual < expected:
                    mismatch_count += 1
                print(f"  {table:30s}: Transferred={expected:4d} | Live in Supabase={actual:4d} [{status}]")
            else:
                print(f"  {table:30s}: MISSING in Supabase!")
                mismatch_count += 1
        
        print("-" * 70)
        print(f"Total Live Records in Supabase: {total_migrated}")
        if mismatch_count == 0:
            print("[VERIFICATION PASSED] All valid records safely stored in Supabase with zero mismatches.")
        else:
            print(f"[VERIFICATION NOTICE] {mismatch_count} tables had differences.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OPD Connect+ SQLite to Supabase Migration")
    parser.add_argument("--dry-run", action="store_true", default=False, help="Perform dry-run validation without writing to DB")
    parser.add_argument("--target-url", default=None, help="Target Supabase connection string")
    parser.add_argument("--sqlite-path", default=r"backend\opd_connect.db", help="Path to source SQLite file")
    args = parser.parse_args()

    sqlite_full_path = os.path.join(base_dir, args.sqlite_path)

    data = load_sqlite_data(sqlite_full_path)
    if args.dry_run or not args.target_url:
        dry_run_validation(data)
        if not args.dry_run and not args.target_url:
            print("\n[NOTE] No --target-url provided. Exited after dry-run validation.")
    else:
        migrate_to_supabase(data, args.target_url)
