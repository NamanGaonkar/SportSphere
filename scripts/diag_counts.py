#!/usr/bin/env python
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

def http(url, method="GET", token=None, payload=None):
    req = urllib.request.Request(url, method=method)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    data = None
    if payload is not None:
        data = json.dumps(payload).encode()
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, data=data) as r:
            body = r.read().decode()
            return r.status, json.loads(body) if body else None
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()

def main():
    env = load_env()
    token = env["SUPABASE_ACCESS_TOKEN"]
    ref = env["SUPABASE_URL"].replace("https://", "").split(".")[0]
    tables = ["profiles","athletes","coaches","staff","teams","tournaments","matches","venues","venue_bookings",
              "attendance","payroll","inventory_items","vendors","purchase_orders","awards","notifications",
              "housekeeping_tasks","training_sessions","performance_records","medical_records","events","transport",
              "accommodation","expenses","school_activities","sports","athlete_sports"]
    q = "select " + ", ".join([f"(select count(*) from public.{t}) as {t}" for t in tables])
    s, body = http(f"https://api.supabase.com/v1/projects/{ref}/database/query", "POST", token=token, payload={"query": q})
    print(json.dumps(body, indent=1) if s == 200 else str(body)[:2000])

if __name__ == "__main__":
    main()
