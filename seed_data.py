import urllib.request, json, io, http.client

BASE = "http://localhost:8001"

# 1. Register or login user
print("=== Creating/logging in user ===")
creds = json.dumps({"email":"lawyer@lawfirm.com","password":"lawyer123","full_name":"Sarah Johnson","bar_number":"BAR-2024-001","phone":"+1234567890"}).encode()
req = urllib.request.Request(f"{BASE}/api/auth/register", data=creds, headers={"Content-Type":"application/json"}, method="POST")
try:
    resp = json.loads(urllib.request.urlopen(req).read())
except urllib.error.HTTPError:
    body = json.dumps({"email":"lawyer@lawfirm.com","password":"lawyer123"}).encode()
    req = urllib.request.Request(f"{BASE}/api/auth/login", data=body, headers={"Content-Type":"application/json"}, method="POST")
    resp = json.loads(urllib.request.urlopen(req).read())
    print("  Logged in as existing user")
token = resp["access_token"]
print(f"  User ID: {resp['user']['id']}")
headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

# 2. Create clients
print("\n=== Creating clients ===")
user_id = resp["user"]["id"]
clients = [
    {"name":"Alice Smith","email":"alice@smith.com","phone":"+12025551234","address":"123 Main St, New York, NY","notes":"Corporate retainer client"},
    {"name":"Bob Williams","email":"bob@williams.com","phone":"+12025555678","address":"456 Oak Ave, Brooklyn, NY","notes":"Criminal defense"},
    {"name":"Carol Davis","email":"carol@davislaw.com","phone":"+12025559012","address":"789 Pine Rd, Manhattan, NY","notes":"Family law client"},
]
client_ids = []
for c in clients:
    body = json.dumps(c).encode()
    req = urllib.request.Request(f"{BASE}/api/clients/", data=body, headers=headers, method="POST")
    resp = json.loads(urllib.request.urlopen(req).read())
    client_ids.append(resp["id"])
    print(f"  Client: {c['name']} (ID: {resp['id']})")

# 3. Create cases
print("\n=== Creating cases ===")
cases = [
    {"case_number":"CIV-2026-001","title":"Smith v. Johnson Corp","description":"Breach of contract - unpaid invoices totaling $150,000","case_type":"CIVIL","status":"ACTIVE","court_name":"NY Supreme Court","judge_name":"Hon. Maria Roberts","client_id":client_ids[0],"opposing_party":"Johnson Corp","filing_date":"2026-01-15T00:00:00Z"},
    {"case_number":"CR-2026-042","title":"State v. Williams","description":"Drug possession charges - defendant claims unlawful search","case_type":"CRIMINAL","status":"ACTIVE","court_name":"Brooklyn Criminal Court","judge_name":"Hon. James Chen","client_id":client_ids[1],"opposing_party":"People of NY","filing_date":"2026-02-20T00:00:00Z"},
    {"case_number":"FAM-2026-018","title":"Davis v. Davis","description":"Child custody and divorce proceedings","case_type":"FAMILY","status":"PENDING","court_name":"Manhattan Family Court","judge_name":"Hon. Patricia Lee","client_id":client_ids[2],"opposing_party":"Mark Davis","filing_date":"2026-03-10T00:00:00Z"},
    {"case_number":"CORP-2026-007","title":"Apex Corp Merger Review","description":"Legal review of merger documents for compliance","case_type":"CORPORATE","status":"ACTIVE","court_name":"","judge_name":"","client_id":client_ids[0],"opposing_party":"","filing_date":"2026-04-01T00:00:00Z"},
]
case_ids = []
for c in cases:
    body = json.dumps(c).encode()
    req = urllib.request.Request(f"{BASE}/api/cases/", data=body, headers=headers, method="POST")
    resp = json.loads(urllib.request.urlopen(req).read())
    case_ids.append(resp["id"])
    print(f"  Case: {c['case_number']} - {c['title'][:40]} (ID: {resp['id']})")

# 4. Create hearings
print("\n=== Creating hearings ===")
hearings = [
    {"case_id":case_ids[0],"hearing_date":"2026-06-15","hearing_time":"10:00:00","court_room":"Room 3B","purpose":"Motion hearing - summary judgment","status":"SCHEDULED","notes":"Prepare evidence package"},
    {"case_id":case_ids[1],"hearing_date":"2026-05-28","hearing_time":"14:00:00","court_room":"Court 7","purpose":"Preliminary hearing","status":"SCHEDULED","notes":"Suppression motion to be filed"},
    {"case_id":case_ids[2],"hearing_date":"2026-07-10","hearing_time":"09:30:00","court_room":"Chambers 2","purpose":"Mediation session","status":"SCHEDULED","notes":"Both parties to attend"},
    {"case_id":case_ids[0],"hearing_date":"2026-05-12","hearing_time":"11:00:00","court_room":"Room 3B","purpose":"Case management conference","status":"COMPLETED","notes":"Discovery schedule finalized"},
]
for h in hearings:
    body = json.dumps(h).encode()
    req = urllib.request.Request(f"{BASE}/api/hearings/", data=body, headers=headers, method="POST")
    resp = json.loads(urllib.request.urlopen(req).read())
    print(f"  Hearing: {h['purpose'][:35]} on {h['hearing_date']} (ID: {resp['id']})")

# 5. Upload sample documents
print("\n=== Uploading documents ===")
docs = [
    ("complaint.txt", "COMPLAINT\n\nPlaintiff alleges breach of contract...", case_ids[0], "Initial complaint filing"),
    ("evidence_list.txt", "EVIDENCE LIST\n1. Contract signed Jan 2026\n2. Invoice records\n3. Email correspondence", case_ids[0], "List of evidence items"),
    ("motion_suppress.txt", "MOTION TO SUPPRESS\n\nDefendant moves to suppress evidence obtained during unlawful search.", case_ids[1], "Pre-trial motion"),
]
boundary = "----FormBoundary7MA4YWxk"
for fname, content, cid, desc in docs:
    conn = http.client.HTTPConnection("localhost", 8001)
    body_bytes = []
    for k, v in [("case_id", str(cid)), ("description", desc), ("file", (fname, content.encode(), "text/plain"))]:
        if isinstance(v, tuple):
            body_bytes.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"; filename=\"{v[0]}\"\r\nContent-Type: {v[2]}\r\n\r\n".encode() + v[1] + b"\r\n")
        else:
            body_bytes.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n".encode() + v.encode() + b"\r\n")
    body_bytes.append(f"--{boundary}--\r\n".encode())
    conn.request("POST", "/api/documents/upload", body=b"".join(body_bytes), headers={"Authorization": f"Bearer {token}", "Content-Type": f"multipart/form-data; boundary={boundary}"})
    resp = conn.getresponse()
    d = json.loads(resp.read().decode())
    print(f"  Doc: {fname} (case {cid}) (ID: {d['id']})")

print("\n=== SEEDING COMPLETE ===")
print(f"  User:    lawyer@lawfirm.com / lawyer123")
print(f"  Clients: {len(clients)} created")
print(f"  Cases:   {len(cases)} created")
print(f"  Hearings: {len(hearings)} created")
print(f"  Docs:    {len(docs)} uploaded")
print(f"\n  Open: http://localhost:8001/docs")
print(f"  Login with: lawyer@lawfirm.com / lawyer123")
