import json
import sqlite3
import uuid
from datetime import datetime

DB_PATH = "opd_connect.db"

def run_migration():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    print("Running migration for Patient and Admin portals...")

    # 1. Create support_tickets table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS support_tickets (
        id VARCHAR(36) PRIMARY KEY,
        patient_id VARCHAR(36) NOT NULL,
        user_id VARCHAR(36),
        subject VARCHAR(200) NOT NULL,
        category VARCHAR(50) NOT NULL DEFAULT 'GENERAL',
        priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL',
        message TEXT NOT NULL,
        status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
        assigned_to_user_id VARCHAR(36),
        admin_response TEXT,
        resolved_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
        FOREIGN KEY (assigned_to_user_id) REFERENCES users(id) ON DELETE SET NULL
    );
    """)

    # 2. Create system_configs table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS system_configs (
        id VARCHAR(36) PRIMARY KEY,
        config_key VARCHAR(100) UNIQUE NOT NULL,
        config_value TEXT NOT NULL,
        category VARCHAR(50) NOT NULL DEFAULT 'GENERAL',
        description VARCHAR(255),
        updated_by_user_id VARCHAR(36),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (updated_by_user_id) REFERENCES users(id) ON DELETE SET NULL
    );
    """)

    # 3. Seed Default System Configurations
    default_configs = [
        ("hospital_name", "City Care Memorial Hospital", "HOSPITAL", "Official hospital name printed on OPD booklets and receipts"),
        ("hospital_code", "CCMH-OPD", "HOSPITAL", "Hospital code prefix for registrations"),
        ("opd_operating_hours", "08:00 AM - 08:00 PM (Mon-Sat), 09:00 AM - 01:00 PM (Sun)", "HOSPITAL", "Daily OPD operating hours"),
        ("hospital_gstin", "29AAAAA0000A1Z5", "BILLING", "Hospital GST identification number"),
        ("consultation_default_fee", "500.00", "BILLING", "Default general OPD consultation fee"),
        ("tax_rate_medicines", "5.0", "BILLING", "Standard tax percentage for essential medicines"),
        ("tax_rate_services", "0.0", "BILLING", "Standard tax percentage for clinical healthcare services (exempt)"),
        ("backup_schedule", "Daily at 02:00 AM UTC", "BACKUP", "Automated backup schedule"),
        ("backup_retention_days", "30", "BACKUP", "Snapshot retention period in days"),
        ("emergency_helpline", "+91 8000 112 911", "HOSPITAL", "24/7 Hospital emergency helpline"),
    ]

    for key, val, cat, desc in default_configs:
        cursor.execute("SELECT id FROM system_configs WHERE config_key = ?", (key,))
        if not cursor.fetchone():
            cursor.execute("""
                INSERT INTO system_configs (id, config_key, config_value, category, description, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """, (str(uuid.uuid4()), key, val, cat, desc))
            print(f"Seeded config: {key}")

    # 4. Seed Permissions
    permissions_list = [
        # Patient & Identity
        ("patient:read", "View patient demographics", "Read patient profile and permitted records"),
        ("patient:write", "Register/update patients", "Create or edit patient records"),
        ("patient:dependents", "Manage dependent profiles", "Link or manage family dependents"),
        # Clinical (Restricted)
        ("clinical:read", "View clinical consultation records", "Doctor or clinician consultation review"),
        ("clinical:write", "Record clinical diagnoses and vitals", "Sign clinical sheets and prescriptions"),
        ("clinical:audit", "Clinical record audit override", "Authorized medical auditor access"),
        # Admin Operations
        ("admin:users", "Manage hospital staff accounts", "Provision, activate, deactivate, or unlock users"),
        ("admin:roles", "Manage roles and privileges", "Modify staff roles and permissions"),
        ("admin:config", "Configure hospital settings", "Edit system configs and catalogues"),
        ("admin:reports", "Generate operational reports", "Access and export hospital footfall and billing reports"),
        ("admin:audit", "Search and inspect audit logs", "Compliance and security audit log inspection"),
        # Billing & Inventory
        ("billing:read", "View invoices and payments", "Read-only access to billing data"),
        ("billing:write", "Process bills and refunds", "Generate invoices, payments, and refunds"),
        ("pharmacy:read", "View inventory and stock", "Read stock levels and drug catalogues"),
        ("pharmacy:write", "Dispense medicines and adjust stock", "Prescription dispensing and stock adjustments"),
        ("lab:read", "View laboratory orders", "Read lab orders and results"),
        ("lab:write", "Enter lab results and verify", "Enter specimen results and sign off"),
    ]

    for code, name, desc in permissions_list:
        cursor.execute("SELECT id FROM permissions WHERE code = ?", (code,))
        row = cursor.fetchone()
        if not row:
            p_id = str(uuid.uuid4())
            cursor.execute("""
                INSERT INTO permissions (id, code, name, description, created_at, updated_at)
                VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """, (p_id, code, name, desc))

    # 5. Link Roles to Permissions
    # Fetch roles
    roles = {r[1]: r[0] for r in cursor.execute("SELECT id, name FROM roles").fetchall()}
    perms = {p[1]: p[0] for p in cursor.execute("SELECT id, code FROM permissions").fetchall()}

    role_mapping = {
        "admin": [
            "admin:users", "admin:roles", "admin:config", "admin:reports", "admin:audit",
            "billing:read", "billing:write", "pharmacy:read", "pharmacy:write",
            "lab:read", "patient:read",
            # NOTE: DO NOT grant "clinical:read" or "clinical:write" to admin by default
        ],
        "doctor": [
            "patient:read", "clinical:read", "clinical:write", "lab:read", "lab:write", "pharmacy:read"
        ],
        "nurse": [
            "patient:read", "clinical:write", "lab:read"
        ],
        "receptionist": [
            "patient:read", "patient:write", "billing:read", "billing:write"
        ],
        "pharmacist": [
            "pharmacy:read", "pharmacy:write", "billing:read", "billing:write"
        ],
        "laboratory": [
            "lab:read", "lab:write"
        ],
        "lab_tech": [
            "lab:read", "lab:write"
        ],
        "patient": [
            "patient:read", "patient:dependents", "billing:read"
        ],
    }

    for role_name, perm_codes in role_mapping.items():
        role_id = roles.get(role_name)
        if not role_id:
            continue
        for p_code in perm_codes:
            perm_id = perms.get(p_code)
            if not perm_id:
                continue
            cursor.execute(
                "SELECT 1 FROM role_permissions WHERE role_id = ? AND permission_id = ?",
                (role_id, perm_id)
            )
            if not cursor.fetchone():
                cursor.execute(
                    "INSERT INTO role_permissions (role_id, permission_id) VALUES (?, ?)",
                    (role_id, perm_id)
                )

    conn.commit()
    conn.close()
    print("Migration finished successfully.")

if __name__ == "__main__":
    run_migration()
