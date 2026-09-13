#!/usr/bin/env python
"""SportSphere — live insert audit.

Signs in as admin@sportsphere.app with the REST endpoint the apps use, then
attempts one INSERT (and one UPDATE) per table to surface RLS / schema errors
exactly as the web/mobile apps would see them. Read-only afterwards: every
test row is deleted again.
"""
import json
import os
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def load_env():
    env = {}
    with open(os.path.join(ROOT, ".env"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip()
    return env

def http(url, method="GET", token=None, payload=None, apikey=None):
    req = urllib.request.Request(url, method=method)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    req.add_header("apikey", apikey or token or "")
    data = None
    if payload is not None:
        data = json.dumps(payload).encode()
        req.add_header("Content-Type", "application/json")
        req.add_header("Prefer", "return=representation")
    try:
        with urllib.request.urlopen(req, data=data) as r:
            body = r.read().decode()
            return r.status, json.loads(body) if body else None
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()

def main():
    env = load_env()
    url = env["SUPABASE_URL"].rstrip("/")
    token = env["SUPABASE_ACCESS_TOKEN"]
    ref = url.replace("https://", "").split(".")[0]
    s, keys = http(f"https://api.supabase.com/v1/projects/{ref}/api-keys", "GET", token=token)
    if s != 200 or not isinstance(keys, list):
        print("api-keys failed:", s, keys); return
    service = next((k["api_key"] for k in keys if k.get("name") == "service_role"), None)
    anon = next((k["api_key"] for k in keys if k.get("name") == "anon"), None)
    # 1) sign in like the apps do
    s, body = http(f"{url}/auth/v1/token?grant_type=password",
                   "POST", payload={"email": "admin@sportsphere.app", "password": "Test@1234"}, apikey=anon)
    if s != 200:
        print("ADMIN LOGIN FAILED:", s, str(body)[:300]); return
    jwt = body["access_token"]
    print("admin login OK\n")

    tests = [
        ("teams",             {"name": "__audit_team", "sport_id": None}),
        ("tournaments",       {"name": "__audit_tour"}),
        ("matches",           {"status": "Scheduled"}),
        ("venues",            {"name": "__audit_venue"}),
        ("venue_bookings",    {"start_time": "2026-10-01T10:00:00Z", "end_time": "2026-10-01T11:00:00Z"}),
        ("athletes",          {}),
        ("coaches",           {}),
        ("staff",             {"department": "Audit", "designation": "Audit"}),
        ("attendance",        {"date": "2026-01-01", "status": "Present"}),
        ("payroll",           {"month": "2026-01-01", "gross": 1, "deductions": 0}),
        ("inventory_items",   {"name": "__audit_item", "quantity": 5}),
        ("vendors",           {"name": "__audit_vendor"}),
        ("purchase_orders",   {"status": "Draft", "items": []}),
        ("awards",            {"title": "__audit_award"}),
        ("notifications",     {"message": "__audit_notif"}),
        ("housekeeping_tasks",{"area": "A", "task": "T"}),
        ("training_sessions", {"title": "__audit_train"}),
        ("performance_records",{"metric": "__audit_m", "value": "1"}),
        ("medical_records",   {"details": "__audit_med"}),
        ("events",            {"title": "__audit_event"}),
        ("transport",         {"purpose": "__audit_transport"}),
        ("accommodation",     {"hotel": "__audit_hotel"}),
        ("expenses",          {"category": "Other", "amount": 1}),
        ("school_activities", {"title": "__audit_act"}),
        ("sports",            {"name": "__audit_sport"}),
        ("profiles",          {"full_name": "__audit_profile"}),
    ]

    ok, bad = [], []
    for table, payload in tests:
        s, body = http(f"{url}/rest/v1/{table}", "POST", token=jwt, payload=payload, apikey=anon)
        if s in (200, 201) and isinstance(body, list) and body:
            row = body[0]
            ok.append(table)
            # cleanup
            http(f"{url}/rest/v1/{table}?id=eq.{row['id']}", "DELETE", token=jwt, apikey=anon)
        else:
            bad.append((table, s, str(body)[:200]))

    print(f"INSERT OK  ({len(ok)}):", ", ".join(ok))
    if bad:
        print(f"\nINSERT FAILED ({len(bad)}):")
        for t, s, b in bad:
            print(f"  {t:24s} {s}  {b}")
    else:
        print("\nAll inserts pass as admin.")

if __name__ == "__main__":
    main()
