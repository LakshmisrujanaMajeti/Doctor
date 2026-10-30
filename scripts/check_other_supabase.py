import urllib.request
import json

url1 = "https://xxwidqatsxzsrulaxxal.supabase.co/rest/v1/patients?select=*"
key1 = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4d2lkcWF0c3h6c3J1bGF4eGFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE3NzgwODgsImV4cCI6MjEwNzM1NDA4OH0.aPYCUJxHYwgYvTAjaiyYjD4G_s5dICLLjXLOYdkcXhE"

req1 = urllib.request.Request(url1, headers={"apikey": key1, "Authorization": f"Bearer {key1}"})
try:
    with urllib.request.urlopen(req1, timeout=5) as resp:
        data1 = json.loads(resp.read().decode())
        print(f"xxwidqatsxzsrulaxxal patients count: {len(data1)}")
        for p in data1[:5]:
            print(f"  UHID: {p.get('uhid')} | Name: {p.get('full_name')}")
except Exception as e:
    print(f"xxwidqatsxzsrulaxxal error: {e}")
