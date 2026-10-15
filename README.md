# OPD Connect+

> **Comprehensive Outpatient Department (OPD), Hospital Workflow & Patient Medical Records Management System**

OPD Connect+ is a professional healthcare mobile application and enterprise backend built from the ground up according to hospital OPD booklets and outpatient consultation workflows. It integrates patient demographic registration with Unique Health Identification (UHID), daily token queues, nursing triage with vital signs and automatic BMI calculation, physical examination sheets, ICD-10 provisional and final diagnoses, prescription management, diagnostic lab ordering, and private document storage.

---

## Technology Stack

- **Mobile Application**: Flutter & Dart using Material 3
- **State Management**: Riverpod (`flutter_riverpod`)
- **Navigation**: GoRouter (`go_router`)
- **Networking**: Dio (`dio`) with auth interceptors and automatic token refresh
- **Backend API**: Python FastAPI (with versioning under `/api/v1`)
- **Database**: Supabase PostgreSQL / SQLAlchemy 2.0 ORM
- **Database Migrations**: Alembic
- **Authentication**: Secure token-based auth with short-lived JWT access tokens (30 min) and refresh-token rotation with reuse detection
- **Security & Cryptography**: Direct bcrypt password hashing, SHA-256 session token hashing
- **Testing**: Pytest (backend API, auth, health, patients, visits) & Flutter Test (widgets, models, BMI calculation)

---

## Project Structure

```text
OPD CONNECT/
├── backend/
│   ├── app/
│   │   ├── api/v1/
│   │   │   ├── endpoints/
│   │   │   │   ├── admin.py             # Hospital stats & audit compliance logs
│   │   │   │   ├── auth.py              # Login, token rotation, registration, /me
│   │   │   │   ├── billing.py           # Invoicing and payment status
│   │   │   │   ├── clinical_records.py  # OPD consultation sheet (ICD-10, exam, notes)
│   │   │   │   ├── departments.py       # Hospital clinical departments
│   │   │   │   ├── doctors.py           # Doctor profiles & consultation fees
│   │   │   │   ├── documents.py         # Private medical document & booklet scans
│   │   │   │   ├── health.py            # System & database health probe
│   │   │   │   ├── laboratory.py        # Lab orders & test result parameters
│   │   │   │   ├── patients.py          # UHID generation, search & demographics
│   │   │   │   ├── pharmacy.py          # Pharmacy dispensary orders
│   │   │   │   ├── prescriptions.py     # Medication orders & dosage instructions
│   │   │   │   ├── users.py             # User and role administration
│   │   │   │   └── visits.py            # Token queueing & vital signs triage
│   │   │   └── api.py                   # Master API v1 router
│   │   ├── core/
│   │   │   ├── config.py                # Environment configuration (Pydantic Settings)
│   │   │   ├── database.py              # SQLAlchemy engine, session maker & Base
│   │   │   ├── dependencies.py          # FastAPI dependencies & role enforcement
│   │   │   ├── exceptions.py            # Centralized exception types
│   │   │   ├── logging.py               # Structured logging setup
│   │   │   ├── responses.py             # Consistent API envelope formatting
│   │   │   └── security.py              # Bcrypt hashing & JWT token operations
│   │   ├── db/
│   │   │   └── seed.py                  # Realistic synthetic hospital data seeder
│   │   ├── models/                      # SQLAlchemy database models
│   │   ├── schemas/                     # Pydantic schemas (request/response validation)
│   │   ├── services/                    # Business logic (Auth, Patients, Visits, Documents)
│   │   └── main.py                      # FastAPI application with CORS and lifespan
│   ├── alembic/                         # Alembic migration scripts
│   ├── tests/                           # Pytest automated test suite
│   ├── .env.example                     # Sample configuration with placeholder values
│   ├── requirements.txt                 # Backend Python dependencies
│   └── pytest.ini                       # Pytest configuration
│
├── frontend/
│   ├── lib/
│   │   ├── core/
│   │   │   ├── config/app_config.dart   # Backend URLs & Supabase configuration
│   │   │   ├── constants/               # Colors, clinical constants, strings
│   │   │   ├── network/                 # DioClient & JWT interceptor
│   │   │   └── theme/app_theme.dart     # Material 3 light and dark themes
│   │   ├── features/
│   │   │   ├── auth/                    # Login screen & Riverpod auth notifier
│   │   │   ├── clinical_records/        # OPD Booklet consultation sheet
│   │   │   ├── dashboard/               # Hospital KPIs & quick actions
│   │   │   ├── patients/                # Directory search & UHID registration
│   │   │   ├── prescriptions/           # Drug dosing & dispensary tracking
│   │   │   ├── settings/                # Dark mode & connectivity indicators
│   │   │   └── visits/                  # Live queue tokens & nursing triage vitals
│   │   ├── routing/app_router.dart      # Declarative GoRouter routing
│   │   ├── shared/widgets/              # TriageChip, StatusBadge, StatMetricCard
│   │   └── main.dart                    # Application root & Riverpod ProviderScope
│   ├── test/                            # Flutter widget and unit tests
│   └── pubspec.yaml                     # Flutter package dependencies
│
└── docs/
    └── SETUP_GUIDE.md                   # Setup guide for Windows, Android, and USB
```

---

## Quick Start & Installation

### 1. Backend Setup

#### Prerequisites
- Python 3.11+ / 3.12+ / 3.14+

#### Steps
```bash
# 1. Navigate to backend
cd backend

# 2. Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate       # On Windows: .\venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Copy configuration
cp .env.example .env

# 5. Run Alembic database migrations
alembic upgrade head

# 6. Seed initial synthetic data (Roles, Departments, Demo Users & Patients)
python3 -m app.db.seed

# 7. Start the FastAPI backend server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Interactive OpenAPI documentation is available at: **`http://localhost:8000/docs`**

---

### 2. Frontend Setup

#### Prerequisites
- Flutter SDK (3.24+ / 3.44+)

#### Steps
```bash
# 1. Navigate to frontend
cd frontend

# 2. Fetch packages
flutter pub get

# 3. Run the application
flutter run
```

---

## Quick Multi-Platform Launchers & Credentials

### 1. Workstation Launchers (Zero-Setup)

| Target Platform | Launcher Command / File | Description |
| :--- | :--- | :--- |
| **Windows Desktop** | `run_desktop.bat` | Double-click to launch standalone clinical desktop workstation (1280x820) |
| **Windows Web Portal** | `run_web.bat` | Fast local production web portal server on `http://127.0.0.1:54321` |
| **macOS Desktop** | `./run_desktop.sh` | Launch standalone native macOS app (`OPD Connect.app`) |
| **macOS Direct App** | `desktop_builds/OPD Connect.app` | Standalone native macOS App bundle (`darwin-arm64`) |
| **Android Mobile** | `apk_builds/opd-connect-release.apk`| Production Android APK (61 MB, install directly on Android 8.0+) |

### 2. Official Login Credentials Directory (PDF)

Complete hospital login credentials across all institutional roles, department specialists, and test patient UHIDs are provided in the official printable PDF:

📄 **[`SMVMCH_OPD_Connect_Login_Credentials.pdf`](file:///Users/satyaalugolu/Desktop/OPD%20CONNECT/SMVMCH_OPD_Connect_Login_Credentials.pdf)** *(also in `docs/`)*

---

## Default Demo Accounts

The database seed provides pre-configured synthetic staff accounts with zero plain-text password persistence:

| Role | Email | Password | Full Name |
| :--- | :--- | :--- | :--- |
| **Doctor** | `dr.chen@opdconnect.com` | `Doctor@123456` | Dr. Sarah Chen, MD |
| **Receptionist** | `receptionist@opdconnect.com` | `Reception@123456` | Alice Adams |
| **Administrator**| `admin@opdconnect.com` | `Admin@123456` | Admin Administrator |

*(The login screen also provides quick-fill action chips for 1-tap testing.)*

---

## Automated Testing

### Run Backend Tests
Run the pytest test suite covering root health, API v1 health, user registration, JWT authentication, refresh token rotation, patient UHID creation/search, and OPD visit triage & BMI calculation:
```bash
cd backend
./venv/bin/pytest -v
```

### Run Frontend Tests
Run Flutter unit and widget tests covering models, serialization, BMI calculation, and UI widget rendering:
```bash
cd frontend
flutter test
```

---

## Health Check Verification

The service provides consistent JSON health-check responses:

```bash
# Root Health
curl http://localhost:8000/health

# API v1 Health & Database Check
curl http://localhost:8000/api/v1/health
```

Expected Response:
```json
{
  "status": "success",
  "message": "Service is healthy and operational",
  "data": {
    "app_name": "OPD Connect+",
    "environment": "development",
    "database_status": "healthy",
    "version": "1.0.0"
  },
  "meta": {
    "timestamp": "2026-10-12T06:37:36.939118Z",
    "version": "v1"
  }
}
```

---

## API Response Format

All `/api/v1` endpoints return a consistent standardized envelope:

### Success Response
```json
{
  "status": "success",
  "message": "Operation completed successfully",
  "data": { ... },
  "meta": {
    "timestamp": "2026-10-12T06:00:00Z",
    "version": "v1"
  }
}
```

### Error Response
```json
{
  "status": "error",
  "message": "Resource not found",
  "error": {
    "code": "NOT_FOUND",
    "details": null
  },
  "meta": {
    "path": "/api/v1/patients/999",
    "version": "v1"
  }
}
```

---

## Supabase PostgreSQL Configuration

The application is prepared to connect to your Supabase project:
- **Project Ref**: `xxwidqatsxzsrulaxxal`
- **Host**: `db.xxwidqatsxzsrulaxxal.supabase.co`

To switch from the default local development database to Supabase PostgreSQL, update `DATABASE_URL` in `backend/.env`:
```env
DATABASE_URL=postgresql://postgres:[YOUR-SUPABASE-PASSWORD]@db.xxwidqatsxzsrulaxxal.supabase.co:5432/postgres
```
Then run `alembic upgrade head`.

Refer to [`docs/SETUP_GUIDE.md`](docs/SETUP_GUIDE.md) for Windows, Android emulator, and physical USB debugging setup instructions.
