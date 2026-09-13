#!/usr/bin/env python
"""SportSphere — apply a SQL file to the Supabase project.

Reads SUPABASE_URL + SUPABASE_ACCESS_TOKEN from the root .env, fetches the
service_role key, then executes the given SQL file via the Supabase management
query API. Usage:

    python scripts/apply_sql.py supabase/migrate_sports.sql
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
    if len(sys.argv) != 2:
        print("usage: python scripts/apply_sql.py <file.sql>")
        sys.exit(1)
    sql_path = os.path.join(ROOT, sys.argv[1])
    with open(sql_path, encoding="utf-8") as f:
        sql = f.read()

    env = load_env()
    token = env.get("SUPABASE_ACCESS_TOKEN")
    url = env.get("SUPABASE_URL")
    if not token or not url:
        print("Missing SUPABASE_ACCESS_TOKEN or SUPABASE_URL in .env")
        sys.exit(1)
    ref = url.replace("https://", "").split(".")[0]

    status, keys = http(f"https://api.supabase.com/v1/projects/{ref}/api-keys", "GET", token=token)
    if status not in (200, 201) or not isinstance(keys, list):
        print("api-keys failed:", status, keys)
        sys.exit(1)
    service = next((k["api_key"] for k in keys if k.get("name") == "service_role"), None)
    if not service:
        print("no service_role key found")
        sys.exit(1)

    status, body = http(
        f"https://api.supabase.com/v1/projects/{ref}/database/query",
        "POST", token=token,
        payload={"query": sql},
    )
    if status in (200, 201):
        print("OK — SQL applied.")
        if body:
            print(json.dumps(body, indent=2, default=str)[:2000])
    else:
        print(f"FAILED ({status}):")
        print(str(body)[:3000])
        sys.exit(1)


if __name__ == "__main__":
    main()
