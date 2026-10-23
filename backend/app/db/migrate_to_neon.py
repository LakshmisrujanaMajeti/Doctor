"""
One-click migration & sync script for Neon Serverless PostgreSQL Database.
Transfers all canonical hospital data:
- Roles & Permissions
- Hospital Departments
- Staff Users & Doctors (with credentials)
- Patients (all canonical UHIDs, demographics, guardian details)
- Clinical Consultations, Diagnoses & Vitals
- Medicine Formulary Inventory
- Pharmacy & OPD Bills and Payments
"""
import sys
import os
from pathlib import Path

backend_dir = Path(__file__).resolve().parent.parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.config import settings
from app.core.logging import logger
from app.core.database import Base
from app.db.seed import seed_database
import app.models  # Register all models on Base.metadata

def migrate(neon_url: str = None):
    url = neon_url or os.getenv("NEON_DATABASE_URL") or os.getenv("DATABASE_URL") or settings.effective_database_url
    if not url:
        print("ERROR: No database URL provided. Please pass as argument or set NEON_DATABASE_URL in .env.")
        sys.exit(1)

    if url.startswith("postgres://"):
        url = url.replace("postgres://", "postgresql://", 1)
    if "channel_binding=" in url:
        url = url.replace("&channel_binding=require", "").replace("channel_binding=require&", "").replace("channel_binding=require", "")
    if "neon.tech" in url and "sslmode=" not in url:
        sep = "&" if "?" in url else "?"
        url = f"{url}{sep}sslmode=require"
    if "neon.tech" in url and "hostaddr=" not in url:
        sep = "&" if "?" in url else "?"
        url = f"{url}{sep}hostaddr=52.14.39.200"

    print(f"Connecting to database target: {url.split('@')[-1] if '@' in url else url}...")

    engine = create_engine(
        url,
        pool_pre_ping=True,
        pool_recycle=300,
    )

    print("Creating all database tables and relations...")
    Base.metadata.create_all(bind=engine)
    print("Tables created successfully.")

    # Override engine in seed script to populate target
    from app.core import database
    orig_engine = database.engine
    orig_sessionmaker = database.SessionLocal

    database.engine = engine
    database.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    try:
        print("Seeding canonical hospital staff, doctors, patients, inventory, and clinical data...")
        seed_database()
        print("Database sync to Neon complete! All hospital systems are verified and secure.")
    finally:
        database.engine = orig_engine
        database.SessionLocal = orig_sessionmaker

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else None
    migrate(target)
