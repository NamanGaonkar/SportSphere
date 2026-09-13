#!/usr/bin/env python
import json, os, urllib.request
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
    if token: req.add_header("Authorization", f"Bearer {token}")
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
env = load_env()
token = env["SUPABASE_ACCESS_TOKEN"]
ref = env["SUPABASE_URL"].replace("https://", "").split(".")[0]
s, body = http(f"https://api.supabase.com/v1/projects/{ref}/database/query", "POST", token=token,
               payload={"query": "select policyname, cmd, qual, with_check from pg_policies where tablename='notifications';"})
print(json.dumps(body, indent=1)[:2000] if s == 200 else str(body)[:1000])
