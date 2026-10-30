import urllib.request
import json
import os

env_vars = {}
with open('backend/.env') as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            k, v = line.split('=', 1)
            env_vars[k.strip()] = v.strip().strip('"').strip("'")

supa_url = env_vars.get('SUPABASE_URL')
supa_anon = env_vars.get('SUPABASE_ANON_KEY')
supa_service = env_vars.get('SUPABASE_SERVICE_ROLE_KEY')

print(f"Backend SUPABASE_URL: {supa_url}")
print(f"Anon key prefix: {supa_anon[:20] if supa_anon else 'None'}...")
print(f"Service key prefix: {supa_service[:20] if supa_service else 'None'}...")

url = f"{supa_url}/rest/v1/patients?select=*"
key = supa_service or supa_anon

req = urllib.request.Request(url, headers={"apikey": key, "Authorization": f"Bearer {key}"})
try:
    with urllib.request.urlopen(req, timeout=5) as resp:
        data = json.loads(resp.read().decode())
        print(f"\nopjqnvcykfkqksopydxl patients count: {len(data)}")
        for p in data[:5]:
            print(f"  UHID: {p.get('uhid')} | Name: {p.get('full_name')}")
except Exception as e:
    print(f"opjqnvcykfkqksopydxl error: {e}")
