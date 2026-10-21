# OPD Connect+ Multi-Platform Setup & Development Guide

This guide details exact instructions for configuring, running, and testing **OPD Connect+** across development environments, including Windows, macOS/Linux, Android Emulator, and Physical Android Devices.

---

## 1. Network Architecture Overview

When developing mobile apps that communicate with a local backend server (`localhost:8000`), network addressing differs by target platform:

| Target Platform | Backend Host URL | Description |
| :--- | :--- | :--- |
| **macOS / iOS Simulator** | `http://localhost:8000/api/v1` | Direct localhost loopback |
| **Web Browser** | `http://localhost:8000/api/v1` | Direct localhost loopback |
| **Android Emulator** | `http://10.0.2.2:8000/api/v1` | Special alias to host machine's loopback interface |
| **Physical Android Device (USB)** | `http://localhost:8000/api/v1` | Via `adb reverse tcp:8000 tcp:8000` |
| **Physical Android Device (Wi-Fi)**| `http://<YOUR_LOCAL_IP>:8000/api/v1` | e.g. `http://192.168.1.100:8000/api/v1` |

`OPD Connect+` automatically detects the platform and points to `10.0.2.2:8000` on Android devices, and supports custom overrides via `--dart-define=API_BASE_URL=...`.

---

## 2. Windows Development Setup

### Prerequisites
1. **Python 3.11+ / 3.12+**: Install from [python.org](https://www.python.org/) (ensure "Add Python to PATH" is checked).
2. **Flutter SDK**: Install Flutter for Windows and add `flutter/bin` to System PATH.
3. **Android Studio**: Install Android Studio with Android SDK Command-line Tools and Android Emulator.

### Backend Setup (PowerShell / Command Prompt)
```powershell
# Navigate to backend directory
cd "OPD CONNECT\backend"

# Create virtual environment
python -m venv venv

# Activate virtual environment
# On PowerShell:
.\venv\Scripts\Activate.ps1
# On CMD:
.\venv\Scripts\activate.bat

# Install dependencies
pip install -r requirements.txt

# Copy sample configuration
copy .env.example .env

# Run database migrations
alembic upgrade head

# Seed synthetic initial data
python -m app.db.seed

# Start FastAPI server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

---

## 3. Android Emulator Setup

1. Open **Android Studio** -> **Virtual Device Manager** (Device Manager).
2. Create or launch an Android Virtual Device (AVD) (e.g. Pixel 8 with API 34/35).
3. Ensure the FastAPI backend is running on `0.0.0.0:8000`:
   ```bash
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```
4. Verify emulator connectivity to host machine:
   In the emulator's Chrome browser, navigate to:
   ```text
   http://10.0.2.2:8000/api/v1/health
   ```
   You should receive `{ "status": "success", "data": { ... } }`.
5. Run the Flutter app targeting the emulator:
   ```bash
   cd frontend
   flutter run -d emulator
   ```

---

## 4. Physical Android Device Setup

There are two primary approaches for physical Android devices:

### Method A: ADB Reverse Port Forwarding (Recommended via USB)
1. Enable **Developer Options** and **USB Debugging** on your Android phone.
2. Connect your phone via USB cable and verify detection:
   ```bash
   adb devices
   ```
3. Forward port 8000 from the phone to your computer:
   ```bash
   adb reverse tcp:8000 tcp:8000
   ```
4. Run the app with localhost override:
   ```bash
   cd frontend
   flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
   ```

### Method B: Over Local Wi-Fi Network
1. Ensure both your computer and phone are connected to the same Wi-Fi router.
2. Find your computer's local IP address:
   - **macOS**: `ipconfig getifaddr en0`
   - **Windows**: `ipconfig` (IPv4 Address under Wireless LAN adapter)
   - **Linux**: `hostname -I`
   *(Example: `192.168.1.150`)*
3. Verify your computer's firewall allows incoming connections on port 8000.
4. Run the Flutter app with your local IP defined:
   ```bash
   cd frontend
   flutter run --dart-define=API_BASE_URL=http://192.168.1.150:8000/api/v1
   ```

---

## 5. Supabase PostgreSQL Database Setup

The backend is pre-configured to connect to Supabase PostgreSQL or local PostgreSQL.

### Connecting to Supabase Directly
1. Obtain your Supabase database master password.
2. Open `backend/.env` and update `DATABASE_URL`:
   ```env
   DATABASE_URL=postgresql://postgres:[YOUR-PASSWORD]@db.xxwidqatsxzsrulaxxal.supabase.co:5432/postgres
   ```
   *(Or using the connection pooler on port 6543)*
3. Execute migrations against Supabase:
   ```bash
   alembic upgrade head
   ```
4. Seed demo roles and departments into Supabase:
   ```bash
   python -m app.db.seed
   ```
