import json
import os

backup_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backups", "backup_20261027_162144"))
supabase_patients_path = os.path.join(backup_dir, "supabase_dump", "patients.json")
sqlite_patients_path = os.path.join(backup_dir, "sqlite_dump", "patients.json")

with open(supabase_patients_path, encoding="utf-8") as f:
    sp_patients = json.load(f)

with open(sqlite_patients_path, encoding="utf-8") as f:
    sq_patients = json.load(f)

print(f"==================================================")
print(f"PATIENT RECONCILIATION AUDIT")
print(f"Supabase Patients: {len(sp_patients)}")
print(f"SQLite Patients  : {len(sq_patients)}")
print(f"==================================================\n")

print("--- SQLITE PATIENTS ---")
sq_by_uhid = {}
sq_by_id = {}
for p in sq_patients:
    uhid = p.get("uhid")
    sq_by_uhid[uhid] = p
    sq_by_id[p.get("id")] = p
    print(f"SQLite ID: {p.get('id')} | UHID: {uhid} | Name: {p.get('full_name')} | Age: {p.get('age_years')} | Gender: {p.get('gender')} | Phone: {p.get('phone')} | Reg: {p.get('registration_date')}")

print("\n--- SUPABASE PATIENTS ---")
sp_by_uhid = {}
sp_by_id = {}
for p in sp_patients:
    uhid = p.get("uhid")
    sp_by_uhid[uhid] = p
    sp_by_id[p.get("id")] = p
    print(f"Supabase ID: {p.get('id')} | UHID: {uhid} | Name: {p.get('full_name')} | Age: {p.get('age_years')} | Gender: {p.get('gender')} | Phone: {p.get('phone')} | Reg: {p.get('registration_date')}")

print("\n==================================================")
print("COMPARISON & DISCREPANCIES:")
print("==================================================")

# Check SQLite patients in Supabase
for uhid, sq_p in sq_by_uhid.items():
    if uhid in sp_by_uhid:
        sp_p = sp_by_uhid[uhid]
        diffs = []
        for k in ["full_name", "phone", "gender", "age_years", "parent_spouse_name", "address"]:
            v1 = str(sq_p.get(k, ""))
            v2 = str(sp_p.get(k, ""))
            if v1 != v2:
                diffs.append(f"{k}: SQLite='{v1}' vs Supabase='{v2}'")
        if diffs:
            print(f"[MODIFIED] UHID {uhid} ({sq_p.get('full_name')}): {', '.join(diffs)}")
        else:
            print(f"[IDENTICAL] UHID {uhid} ({sq_p.get('full_name')}) matches in both.")
    else:
        print(f"[MISSING IN SUPABASE] UHID {uhid} ({sq_p.get('full_name')}) exists ONLY in SQLite!")

# Check Supabase patients not in SQLite
for uhid, sp_p in sp_by_uhid.items():
    if uhid not in sq_by_uhid:
        print(f"[NEW IN SUPABASE] UHID {uhid} ({sp_p.get('full_name')}) - registered in Supabase but not in local SQLite")
