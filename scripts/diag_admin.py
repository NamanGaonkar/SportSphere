#!/usr/bin/env python
"""Diagnose why is_admin() fails for the admin user."""
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
    url = env["SUPABASE_URL"].rstrip("/")
    token = env["SUPABASE_ACCESS_TOKEN"]
    ref = url.replace("https://", "").split(".")[0]

    queries = {
        "admin profile": "select id, full_name, role, contact_info from public.profiles where full_name ilike '%admin%' or contact_info like 'admin@%';",
        "policies on profiles": "select policyname, cmd, qual, with_check from pg_policies where schemaname='public' and tablename='profiles';",
        "is_admin def": "select prosrc from pg_proc where proname='is_admin';",
        "current_role def": "select prosrc from pg_proc where proname='current_role';",
        "all roles": "select role, count(*) from public.profiles group by role;",
        "admin count": "select count(*) from public.profiles where role='Admin';",
        "revoke check": "select grantee, privilege_type from information_schema.role_table_grants where table_schema='public' and table_name='profiles' limit 10;",
    }
    for name, q in queries.items():
        s, body = http(f"https://api.supabase.com/v1/projects/{ref}/database/query", "POST", token=token, payload={"query": q})
        print(f"===== {name} ({s}) =====")
        print(json.dumps(body, indent=1, default=str)[:2500] if s == 200 else str(body)[:1500])
        print()

if __name__ == "__main__":
    main()
