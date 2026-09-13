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

    queries = {
        "admin role owner": "select p.id, p.full_name, p.role, p.contact_info, (select count(*) from auth.users u where u.id = p.id) as has_auth_user from public.profiles p where p.role = 'Admin';",
        "auth users": "select id, email from auth.users order by email;",
        "publication": "select tablename from pg_publication_tables where pubname = 'supabase_realtime';",
        "six users roles": "select p.full_name, p.role, p.contact_info from public.profiles p where p.contact_info in ('admin@sportsphere.app','athlete@sportsphere.app','coach@sportsphere.app','hr@sportsphere.app','finance@sportsphere.app','venuemanager@sportsphere.app');",
    }
    for name, q in queries.items():
        s, body = http(f"https://api.supabase.com/v1/projects/{ref}/database/query", "POST", token=token, payload={"query": q})
        print(f"===== {name} ({s}) =====")
        print(json.dumps(body, indent=1, default=str)[:3000] if s == 200 else str(body)[:1500])
        print()

if __name__ == "__main__":
    main()
