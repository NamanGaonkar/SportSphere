#!/usr/bin/env python
"""Fix SportSphere Vercel env vars (one-time repair tool).

Background: the VITE_ Supabase vars were created as Sensitive/Secret at
project import with broken values, and Secrets cannot be edited in place
(which is why the dashboard refused to save). This script deletes the VITE_
vars and recreates them as Config-type vars with the values from the local
root .env. A redeploy is required afterwards: push an empty commit
(git commit --allow-empty -m "redeploy") — git-connected projects cannot be
deployed via the plain deployments API.

The Vercel token is read from VERCEL_TOKEN in the root .env — never hardcode
or commit it. Never prints secret values.
"""
import json
import os
import time
import urllib.error
import urllib.request

TEAM = "team_boXRyLJzxW3tTko7IjORUMwU"
PROJECT = "prj_dMOisOKAjjGXLYBScbe7RACSu8Fs"
BASE = f"https://api.vercel.com/v10/projects/{PROJECT}/env?teamId={TEAM}"
ENV_BASE = f"https://api.vercel.com/v10/projects/{PROJECT}/env"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_env():
    env = {}
    with open(os.path.join(ROOT, ".env"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().rstrip("\r")
    return env


_env = load_env()
VT = _env.get("VERCEL_TOKEN", "")
assert VT, "Add VERCEL_TOKEN=<token> to the root .env first"


def req(method, url, payload=None, send_json=True):
    data = json.dumps(payload).encode() if payload is not None else None
    headers = {"Authorization": f"Bearer {VT}"}
    if send_json:
        headers["Content-Type"] = "application/json"
    r = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(r) as resp:
            body = resp.read().decode()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{method} {url} -> HTTP {e.code}: {e.read().decode()[:300]}") from None
    return json.loads(body) if body else {}


url_val = _env.get("VITE_SUPABASE_URL") or _env.get("SUPABASE_URL", "")
key_val = _env.get("VITE_SUPABASE_ANON_KEY") or _env.get("SUPABASE_ANON_KEY", "")
assert url_val.startswith("https://") and ".supabase.co" in url_val, "bad URL in .env"
assert len(key_val) > 20, "anon key too short in .env"

# 1) Delete existing VITE_ vars by ID (path BEFORE query string, no JSON body).
existing = req("GET", BASE).get("envs", [])
for e in existing:
    if e["key"].startswith("VITE_"):
        try:
            req("DELETE", f"{ENV_BASE}/{e['id']}?teamId={TEAM}", send_json=False)
            print("deleted old var:", e["key"])
        except RuntimeError as ex:
            print("skip delete:", e["key"], str(ex)[:120])

# 2) Recreate as Config (readable) vars on all environments.
for k, v in (("VITE_SUPABASE_URL", url_val), ("VITE_SUPABASE_ANON_KEY", key_val)):
    req("POST", BASE, {
        "key": k,
        "value": v,
        "type": "encrypted",      # "Config" in the dashboard
        "target": ["production", "preview", "development"],
    })
    print("created var:", k)

print("done. Now redeploy: git commit --allow-empty -m 'redeploy' && git push origin main")
