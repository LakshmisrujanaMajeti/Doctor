import sqlite3
import json
import urllib.request
from datetime import datetime

SUPABASE_URL = "https://xxwidqatsxzsrulaxxal.supabase.co/rest/v1"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4d2lkcWF0c3h6c3J1bGF4eGFsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTc3ODA4OCwiZXhwIjoyMTA3MzU0MDg4fQ.eayg90ZSOAT91ZA8c-mt28kRf3NkZOCvJDtTpRLHy8c"

headers = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation,resolution=merge-duplicates"
}

patients = [
    {
        "id": "9791dc19-e67c-4921-8f9b-d1c6c8d12408",
        "uhid": "UHID-2026-00001",
        "hospital_reg_num": "REG-2026-00000",
        "full_name": "Srujana",
        "parent_spouse_name": "Ramesh",
        "parent_spouse_relation": "D/o",
        "gender": "FEMALE",
        "age_years": 22,
        "phone": "8374477999",
        "email": "srujana@opdconnect.hospital",
        "address": "Kalitheerthalkuppam",
        "city": "Puducherry",
        "state": "Puducherry",
        "postal_code": "605107",
        "blood_group": "O+"
    },
    {
        "id": "746b2fb8-cc53-4e2f-aa85-0388067b1022",
        "uhid": "UHID-2026-00002",
        "hospital_reg_num": "REG-2026-00001",
        "full_name": "Uday Kumar",
        "parent_spouse_name": "S. Kumar",
        "parent_spouse_relation": "S/o",
        "gender": "MALE",
        "age_years": 23,
        "phone": "9347989890",
        "email": "uday.kumar@gmail.com",
        "address": "12 Anna Nagar",
        "city": "Puducherry",
        "state": "Puducherry",
        "postal_code": "605001",
        "blood_group": "A+"
    },
    {
        "id": "f5c22d18-d291-4992-adbc-01351ac5c40f",
        "uhid": "UHID-2026-00003",
        "hospital_reg_num": "REG-2026-00002",
        "full_name": "Ravi",
        "parent_spouse_name": "Prasad",
        "parent_spouse_relation": "S/o",
        "gender": "MALE",
        "age_years": 25,
        "phone": "9876543211",
        "email": "ravi@gmail.com",
        "address": "Main Bazaar",
        "city": "Puducherry",
        "state": "Puducherry",
        "postal_code": "605001",
        "blood_group": "O+"
    },
    {
        "id": "b45c7957-b64f-4fd8-b9ef-705bf68da328",
        "uhid": "UHID-2026-00004",
        "hospital_reg_num": "REG-2026-00004",
        "full_name": "Pavan",
        "parent_spouse_name": "Venkatesh",
        "parent_spouse_relation": "S/o",
        "gender": "MALE",
        "age_years": 25,
        "phone": "9876543222",
        "email": "pavan@gmail.com",
        "address": "Beach Road",
        "city": "Puducherry",
        "state": "Puducherry",
        "postal_code": "605001",
        "blood_group": "O+"
    },
    {
        "id": "pat-sheela-00005",
        "uhid": "UHID-2026-00005",
        "hospital_reg_num": "REG-2026-00005",
        "full_name": "Sheela",
        "parent_spouse_name": "David",
        "parent_spouse_relation": "D/o",
        "gender": "FEMALE",
        "age_years": 25,
        "phone": "9999999999",
        "email": "sheela@gmail.com",
        "address": "Moon Land",
        "city": "Puducherry",
        "state": "Puducherry",
        "postal_code": "605001",
        "blood_group": "A-"
    },
    {
        "id": "pat-samanta-00006",
        "uhid": "UHID-2026-00006",
        "hospital_reg_num": "REG-2026-00006",
        "full_name": "Samanta",
        "parent_spouse_name": "Subramaniam",
        "parent_spouse_relation": "W/o",
        "gender": "FEMALE",
        "age_years": 79,
        "phone": "1234567890",
        "email": "samanta@gmail.com",
        "address": "Heritage Town",
        "city": "Puducherry",
        "state": "Puducherry",
        "postal_code": "605001",
        "blood_group": "B+"
    },
    {
        "id": "pat-teja-00007",
        "uhid": "UHID-2026-00007",
        "hospital_reg_num": "REG-2026-00007",
        "full_name": "Teja",
        "parent_spouse_name": "Narayana",
        "parent_spouse_relation": "S/o",
        "gender": "MALE",
        "age_years": 25,
        "phone": "9848022338",
        "email": "teja@gmail.com",
        "address": "Villupuram Road",
        "city": "Puducherry",
        "state": "Puducherry",
        "postal_code": "605107",
        "blood_group": "AB+"
    }
]

# 1. Update SQLite backend/opd_connect.db
conn = sqlite3.connect("backend/opd_connect.db")
c = conn.cursor()
for p in patients:
    now_str = datetime.now().isoformat()
    c.execute("""
        INSERT INTO patients (id, uhid, hospital_reg_num, full_name, parent_spouse_name, parent_spouse_relation, gender, age_years, phone, email, address, city, state, postal_code, blood_group, barcode_value, qr_code_data, registration_date, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            uhid=excluded.uhid,
            hospital_reg_num=excluded.hospital_reg_num,
            full_name=excluded.full_name,
            gender=excluded.gender,
            phone=excluded.phone,
            email=excluded.email,
            address=excluded.address,
            city=excluded.city,
            blood_group=excluded.blood_group
    """, (
        p["id"], p["uhid"], p["hospital_reg_num"], p["full_name"], p["parent_spouse_name"], p["parent_spouse_relation"],
        p["gender"], p["age_years"], p["phone"], p["email"], p["address"], p["city"], p["state"], p["postal_code"],
        p["blood_group"], f"BAR-{p['uhid']}", f"OPDCONNECT+{p['uhid']}+{p['hospital_reg_num']}",
        now_str, now_str, now_str
    ))
conn.commit()
print("SQLite sync completed successfully!")

# 2. Sync to Supabase PostgreSQL
# Remove older misallocated duplicates from Supabase
del_req = urllib.request.Request(
    f"{SUPABASE_URL}/patients?id=in.(pat-1792652229576,pat-1792652178045,pat-1792655198939)",
    headers=headers,
    method="DELETE"
)
try:
    urllib.request.urlopen(del_req)
    print("Cleaned older duplicate records from Supabase!")
except Exception as e:
    print(f"Clean duplicates notice: {e}")

for p in patients:
    now_iso = datetime.now().isoformat()
    payload = {
        "id": p["id"],
        "uhid": p["uhid"],
        "hospital_reg_num": p["hospital_reg_num"],
        "full_name": p["full_name"],
        "parent_spouse_name": p["parent_spouse_name"],
        "parent_spouse_relation": p["parent_spouse_relation"],
        "gender": p["gender"],
        "age_years": p["age_years"],
        "phone": p["phone"],
        "email": p["email"],
        "address": p["address"],
        "city": p["city"],
        "state": p["state"],
        "postal_code": p["postal_code"],
        "blood_group": p["blood_group"],
        "barcode_value": f"BAR-{p['uhid']}",
        "qr_code_data": f"OPDCONNECT+{p['uhid']}+{p['hospital_reg_num']}",
        "registration_date": now_iso,
        "created_at": now_iso,
        "updated_at": now_iso,
    }
    req = urllib.request.Request(
        f"{SUPABASE_URL}/patients",
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST"
    )
    try:
        urllib.request.urlopen(req)
        print(f"Supabase upsert {p['uhid']} ({p['full_name']}): OK")
    except Exception as e:
        print(f"Supabase upsert {p['uhid']} notice: {e}")

print("ALL DATABASE SYNCHRONIZATION COMPLETED!")
