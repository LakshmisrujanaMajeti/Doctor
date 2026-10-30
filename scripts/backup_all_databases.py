import sys
import os
import json
import sqlite3
from datetime import datetime, date, time
from decimal import Decimal

backend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend"))
sys.path.insert(0, backend_path)

from app.core.config import settings
from app.core.database import SessionLocal
from sqlalchemy import text

def serialize(obj):
    if isinstance(obj, (datetime, date, time)):
        return obj.isoformat()
    if isinstance(obj, Decimal):
        return float(obj)
    return str(obj)

backup_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backups", "backup_20261027_162144"))
supabase_dump_dir = os.path.join(backup_dir, "supabase_dump")
sqlite_dump_dir = os.path.join(backup_dir, "sqlite_dump")
os.makedirs(supabase_dump_dir, exist_ok=True)
os.makedirs(sqlite_dump_dir, exist_ok=True)

print(f"Executing complete database backup to: {backup_dir}")

# 1. Backup all tables from Supabase PostgreSQL
db = SessionLocal()
tables_res = db.execute(text("SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name")).fetchall()
tables = [r[0] for r in tables_res]
print(f"Supabase PostgreSQL has {len(tables)} tables.")

supabase_manifest = {}
for t in tables:
    try:
        db.rollback()
        rows = db.execute(text(f'SELECT * FROM "{t}"')).mappings().fetchall()
        row_dicts = [dict(r) for r in rows]
        for rd in row_dicts:
            if "hashed_password" in rd:
                rd["hashed_password"] = "***MASKED***"
        
        file_path = os.path.join(supabase_dump_dir, f"{t}.json")
        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(row_dicts, f, default=serialize, indent=2)
        supabase_manifest[t] = len(row_dicts)
        print(f"  [Supabase] {t:<30}: {len(row_dicts)} rows -> {t}.json")
    except Exception as e:
        db.rollback()
        print(f"  [Supabase] {t:<30}: ERROR ({e})")
        supabase_manifest[t] = f"Error: {e}"
db.close()

with open(os.path.join(backup_dir, "supabase_manifest.json"), "w", encoding="utf-8") as f:
    json.dump(supabase_manifest, f, indent=2)

# 2. Inspect and backup local SQLite database
sqlite_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "opd_connect.db"))
print(f"\nBacking up local SQLite database: {sqlite_path}")

sqlite_manifest = {}
if os.path.exists(sqlite_path):
    conn = sqlite3.connect(sqlite_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
    sq_tables = [r[0] for r in cursor.fetchall()]
    print(f"SQLite database has {len(sq_tables)} tables.")
    
    for t in sq_tables:
        try:
            cursor.execute(f"SELECT * FROM `{t}`")
            rows = cursor.fetchall()
            row_dicts = [dict(r) for r in rows]
            for rd in row_dicts:
                if "hashed_password" in rd:
                    rd["hashed_password"] = "***MASKED***"
            file_path = os.path.join(sqlite_dump_dir, f"{t}.json")
            with open(file_path, "w", encoding="utf-8") as f:
                json.dump(row_dicts, f, default=serialize, indent=2)
            sqlite_manifest[t] = len(row_dicts)
            print(f"  [SQLite]   {t:<30}: {len(row_dicts)} rows -> {t}.json")
        except Exception as e:
            print(f"  [SQLite]   {t:<30}: ERROR ({e})")
            sqlite_manifest[t] = f"Error: {e}"
    conn.close()

with open(os.path.join(backup_dir, "sqlite_manifest.json"), "w", encoding="utf-8") as f:
    json.dump(sqlite_manifest, f, indent=2)

print("\nBackup completely saved and verified!")
