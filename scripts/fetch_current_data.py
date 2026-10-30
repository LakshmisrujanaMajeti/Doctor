import sys
import os
import json
from datetime import datetime, date, time
from decimal import Decimal

backend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend"))
sys.path.insert(0, backend_path)

from app.core.config import settings
from app.core.database import SessionLocal
from sqlalchemy import text

db = SessionLocal()

def serialize(obj):
    if isinstance(obj, (datetime, date, time)):
        return obj.isoformat()
    if isinstance(obj, Decimal):
        return float(obj)
    return str(obj)

data_export = {
    "exported_at": datetime.now().isoformat(),
    "database_type": "Supabase PostgreSQL",
    "supabase_url": settings.SUPABASE_URL,
    "tables": {}
}

tables_to_dump = [
    "patients",
    "opd_visits",
    "doctors",
    "departments",
    "users",
    "bills",
    "bill_items",
    "prescriptions",
    "prescription_items",
    "clinical_records",
    "vital_signs",
    "lab_orders",
    "medicine_inventory",
    "medical_documents",
    "audit_logs"
]

try:
    for t in tables_to_dump:
        try:
            db.rollback()
            count = db.execute(text(f'SELECT COUNT(*) FROM "{t}"')).scalar()
            rows = db.execute(text(f'SELECT * FROM "{t}" ORDER BY id DESC LIMIT 50')).mappings().fetchall()
            row_list = []
            for r in rows:
                d = dict(r)
                # mask sensitive password hashes
                if "hashed_password" in d:
                    d["hashed_password"] = "***MASKED***"
                row_list.append(d)
            data_export["tables"][t] = {
                "total_rows": count,
                "sample_count": len(row_list),
                "data": row_list
            }
            print(f"Table {t:<22}: {count:>5} total rows (fetched {len(row_list)})")
        except Exception as e:
            db.rollback()
            print(f"Table {t:<22}: ERROR ({e})")
            data_export["tables"][t] = {"error": str(e)}

    out_path = os.path.join(os.path.dirname(__file__), "current_database_export.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data_export, f, default=serialize, indent=2)

    print(f"\nSuccessfully wrote export to: {out_path}")

except Exception as ex:
    print(f"Fatal error: {ex}")
finally:
    db.close()
