#!/usr/bin/env python
"""SportSphere — production cleanup.

1. Truncates every application table and deletes all profiles.
2. Deletes every auth user via the official admin API.

Reads SUPABASE_URL + SUPABASE_ACCESS_TOKEN from the root .env.
Run:  python scripts/cleanup_demo_data.py
"""
import json
import os
import sys
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


def http(url, method="GET", token=None, apikey=None, payload=None):
    req = urllib.request.Request(url, method=method)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    if apikey:
        req.add_header("apikey", apikey)
        # auth admin API also requires a Bearer token (the service_role key)
        if not token:
            req.add_header("Authorization", f"Bearer {apikey}")
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
    token = env.get("SUPABASE_ACCESS_TOKEN")
    url = env.get("SUPABASE_URL")
    if not token or not url:
        print("Missing SUPABASE_ACCESS_TOKEN or SUPABASE_URL in .env")
        sys.exit(1)
    ref = url.replace("https://", "").split(".")[0]

    # 1) wipe application data
    sql = """
    truncate table public.notifications, public.attendance, public.awards,
      public.medical_records, public.performance_records, public.training_sessions,
      public.school_activities, public.events, public.transport, public.accommodation,
      public.expenses, public.housekeeping_tasks, public.purchase_orders,
      public.vendors, public.inventory_items, public.venue_bookings,
      public.matches, public.tournaments, public.payroll, public.staff,
      public.athletes, public.teams, public.coaches, public.venues cascade;
    delete from public.profiles;
    """
    status, body = http(
        f"https://api.supabase.com/v1/projects/{ref}/database/query",
        "POST", token=token, payload={"query": sql},
    )
    print("wipe tables:", status)
    if status not in (200, 201, 204):
        print(body)
        sys.exit(1)

    # 2) fetch service_role key from management API
    status, keys = http(f"https://api.supabase.com/v1/projects/{ref}/api-keys", "GET", token=token)
    if status != 200 or not isinstance(keys, list):
        print("api-keys failed:", status, keys)
        sys.exit(1)
    service = next((k["api_key"] for k in keys if k.get("name") == "service_role"), None)
    if not service:
        print("no service_role key found")
        sys.exit(1)

    # 3) delete every auth user
    status, users = http(f"{url}/auth/v1/admin/users?per_page=500", "GET", apikey=service)
    if status != 200:
        print("list users failed:", status, users)
        sys.exit(1)
    ids = [u["id"] for u in users.get("users", [])]
    for uid in ids:
        s, _ = http(f"{url}/auth/v1/admin/users/{uid}", "DELETE", apikey=service)
        print("deleted user", uid, s)
    print(f"auth users removed: {len(ids)}")
    print("CLEANUP DONE")


if __name__ == "__main__":
    main()
