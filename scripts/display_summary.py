import json
import os

json_path = os.path.join(os.path.dirname(__file__), "current_database_export.json")
with open(json_path, encoding='utf-8') as f:
    d = json.load(f)

print("="*70)
print(f"DATABASE SNAPSHOT SUMMARY (Connected to Supabase PostgreSQL)")
print(f"Export Time: {d.get('exported_at')}")
print("="*70)

# 1. Patients
pts = d['tables']['patients']['data']
print(f"\n1. REGISTERED PATIENTS ({len(pts)} Total):")
print(f"{'UHID':<18} {'Full Name':<28} {'Gender':<8} {'Age':<5} {'Phone':<12} {'City'}")
print("-" * 85)
for p in pts:
    print(f"{p['uhid']:<18} {p['full_name']:<28} {p.get('gender','N/A'):<8} {str(p.get('age_years','-')):<5} {str(p.get('phone','-')):<12} {p.get('city','Puducherry')}")

# 2. OPD Visits breakdown
vsts = d['tables']['opd_visits']['data']
status_counts = {}
for v in vsts:
    st = v.get('status', 'UNKNOWN')
    status_counts[st] = status_counts.get(st, 0) + 1

print(f"\n2. OPD VISITS & QUEUE TOKENS ({len(vsts)} Total):")
print(f"Status Breakdown: {status_counts}")
print(f"\nLatest 10 OPD Visits:")
print(f"{'Visit Number':<22} {'Token':<10} {'Priority':<12} {'Status':<16} {'Visit Date'}")
print("-" * 80)
for v in vsts[:10]:
    print(f"{str(v.get('visit_number','-')):<22} {str(v.get('queue_token','-')):<10} {str(v.get('triage_priority','-')):<12} {str(v.get('status','-')):<16} {str(v.get('visit_date','-'))}")

# 3. Doctors & Departments
depts = d['tables']['departments']['data']
print(f"\n3. CLINICAL DEPARTMENTS ({len(depts)} Total):")
dept_names = [f"{dp.get('code','')} ({dp.get('name','')})" for dp in depts]
print(", ".join(dept_names[:10]))
if len(dept_names) > 10:
    print(", ".join(dept_names[10:]))

docs = d['tables']['doctors']['data']
print(f"\n4. ACTIVE DOCTORS ({len(docs)} Total Registered):")
for doc in docs[:10]:
    print(f"Doctor ID: {doc.get('id')} | Spec: {doc.get('specialization')} | Room: {doc.get('room_number')} | Fee: INR {doc.get('consultation_fee')}")

# 4. Billing & Financials
bills = d['tables']['bills']['data']
total_net = sum(float(b.get('net_amount') or 0) for b in bills)
total_paid = sum(float(b.get('paid_amount') or 0) for b in bills)
total_out = sum(float(b.get('outstanding_balance') or 0) for b in bills)
print(f"\n5. BILLING & REVENUE OVERVIEW:")
print(f"Total Invoices Generated : {len(bills)}")
print(f"Total Net Billed Amount  : INR {total_net:,.2f}")
print(f"Total Collected Revenue  : INR {total_paid:,.2f}")
print(f"Total Outstanding Balance: INR {total_out:,.2f}")

# 5. Pharmacy Inventory
meds = d['tables']['medicine_inventory']['data']
print(f"\n6. PHARMACY INVENTORY ({len(meds)} Medicines tracked):")
print(f"{'Medicine Name':<28} {'Brand':<18} {'Stock':<8} {'Min Level':<10} {'Price (INR)'}")
print("-" * 80)
for m in meds:
    print(f"{m.get('medicine_name',''):<28} {str(m.get('brand','')):<18} {str(m.get('stock_quantity',0)):<8} {str(m.get('reorder_level',0)):<10} {str(m.get('unit_price',0))}")

# 6. Prescriptions & Clinical Records
rxs = d['tables']['prescriptions']['data']
clin = d['tables']['clinical_records']['data']
vitals = d['tables']['vital_signs']['data']
labs = d['tables']['lab_orders']['data']
print(f"\n7. CLINICAL & DIAGNOSTIC DATA:")
print(f"Prescriptions Issued   : {len(rxs)}")
print(f"Clinical Consultations : {len(clin)}")
print(f"Triage Vital Signs     : {len(vitals)}")
print(f"Laboratory Orders      : {len(labs)}")

# 7. Audit & Users
usrs = d['tables']['users']['data']
audits = d['tables']['audit_logs']['total_rows']
print(f"\n8. PLATFORM USERS & GOVERNANCE:")
print(f"Total Platform Users   : {len(usrs)} accounts across 7 roles")
print(f"Total System Audit Logs: {audits} immutable events recorded")
