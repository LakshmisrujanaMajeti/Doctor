import sqlite3
import os
from app.core.database import engine, Base
import app.models  # Ensures all models are registered

DB_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "opd_connect.db")


def migrate_documents():
    print("Running Base.metadata.create_all for document tables...")
    Base.metadata.create_all(bind=engine)

    if os.path.exists(DB_PATH):
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # Update existing 'medical_documents' table if missing new columns
        doc_columns = [
            ("page_count", "INTEGER DEFAULT 1"),
            ("checksum_sha256", "VARCHAR(64)"),
            ("is_verified", "BOOLEAN DEFAULT 0"),
            ("verification_status", "VARCHAR(30) DEFAULT 'UNVERIFIED'"),
            ("verified_by_user_id", "VARCHAR(36)"),
            ("verified_at", "DATETIME"),
            ("is_deleted", "BOOLEAN DEFAULT 0"),
            ("deleted_at", "DATETIME"),
            ("deleted_by_user_id", "VARCHAR(36)"),
        ]

        cursor.execute("PRAGMA table_info(medical_documents)")
        existing_cols = {row[1] for row in cursor.fetchall()}

        for col_name, col_type in doc_columns:
            if col_name not in existing_cols:
                try:
                    cursor.execute(f"ALTER TABLE medical_documents ADD COLUMN {col_name} {col_type}")
                    print(f"Added column {col_name} to medical_documents")
                except Exception as e:
                    print(f"Notice on column {col_name} in medical_documents: {e}")

        conn.commit()
        conn.close()
        print("Document migrations completed successfully.")


if __name__ == "__main__":
    migrate_documents()
