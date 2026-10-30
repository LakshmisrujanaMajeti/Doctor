import json

with open('scripts/current_database_export.json', encoding='utf-8') as f:
    d = json.load(f)

for p in sorted(d['tables']['patients']['data'], key=lambda x: x['uhid']):
    print(f"{p['uhid']} | {p['full_name']} | created_at: {p.get('created_at')} | reg_by: {p.get('registered_by_staff_role', 'N/A')}")
