#!/usr/bin/env python
"""Create the SportSphere demo auth users via the Supabase admin API.

Reads SUPABASE_URL + SUPABASE_ACCESS_TOKEN from the root .env, fetches the
service_role key from the Management API, then POSTs each user to
/auth/v1/admin/users (official path — rows are exactly what GoTrue expects).
Idempotent: skips users that already exist.
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

def http(url, method="GET", headers=None, body=None):
    req = urllib.request.Request(url, method=method)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    data = json.dumps(body).encode() if body is not None else None
    with urllib.request.urlopen(req, data=data, timeout=60) as r:
        return json.loads(r.read().decode())

USERS = [
    ("admin@sportsphere.app",   "Jaya Sharma",    "Admin"),
    ("coach@sportsphere.app",   "Rahul Verma",    "Coach"),
    ("coach2@sportsphere.app",  "Priya Nair",     "Coach"),
    ("athlete@sportsphere.app", "Arjun Mehta",    "Athlete"),
    ("athlete2@sportsphere.app","Sneha Kulkarni", "Athlete"),
    ("athlete3@sportsphere.app","Vikram Singh",   "Athlete"),
    ("athlete4@sportsphere.app","Ananya Rao",     "Athlete"),
    ("hr@sportsphere.app",      "Deepa Iyer",     "HR"),
]

def main():
    env = load_env()
    base = env["SUPABASE_URL"].rstrip("/")
    token = env["SUPABASE_ACCESS_TOKEN"]
    project_ref = base.split("//")[1].split(".")[0]

    # fetch service_role key from the Management API
    keys = http(
        f"https://api.supabase.com/v1/projects/{project_ref}/api-keys",
        headers={"Authorization": f"Bearer {token}"},
    )
    service_role = next((k["api_key"] for k in keys if k.get("name") == "service_role" and k.get("api_key")), None)
    if not service_role:
        print("Could not fetch service_role key — check SUPABASE_ACCESS_TOKEN", file=sys.stderr)
        sys.exit(1)

    ok, fail = 0, 0
    for email, name, role in USERS:
        existing = http(
            f"{base}/auth/v1/admin/users?page=1&per_page=200",
            headers={"Authorization": f"Bearer {service_role}", "apikey": service_role},
        )
        if any(u.get("email") == email for u in existing.get("users", [])):
            print(f"  = {email} already exists, skipping")
            ok += 1
            continue

        try:
            http(
                f"{base}/auth/v1/admin/users",
                method="POST",
                headers={"Authorization": f"Bearer {service_role}", "apikey": service_role,
                         "Content-Type": "application/json"},
                body={
                    "email": email,
                    "password": "Passw0rd!",
                    "email_confirm": True,
                    "user_metadata": {"full_name": name, "role": role},
                },
            )
            print(f"  + created {email} ({role})")
            ok += 1
        except Exception as e:  # noqa: BLE001
            print(f"  ! {email}: {e}", file=sys.stderr)
            fail += 1

    print(f"Done: {ok} ok, {fail} failed")
    sys.exit(1 if fail else 0)

if __name__ == "__main__":
    main()
