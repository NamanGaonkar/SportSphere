#!/usr/bin/env python
"""SportSphere — create the single fixed admin account.

Reads from root .env:
  SUPABASE_URL, SUPABASE_ACCESS_TOKEN, ADMIN_EMAIL, ADMIN_PASSWORD

Creates the admin via the official auth admin API (or resets the password if
the account already exists) and upserts profiles.role = 'Admin'.
This is the ONLY account with the Admin role; public signup can never create one.
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
    email = env.get("ADMIN_EMAIL")
    password = env.get("ADMIN_PASSWORD")
    if not all([token, url, email, password]):
        print("Set SUPABASE_URL, SUPABASE_ACCESS_TOKEN, ADMIN_EMAIL, ADMIN_PASSWORD in .env")
        sys.exit(1)
    ref = url.replace("https://", "").split(".")[0]

    status, keys = http(f"https://api.supabase.com/v1/projects/{ref}/api-keys", "GET", token=token)
    if status != 200 or not isinstance(keys, list):
        print("api-keys failed:", status, keys)
        sys.exit(1)
    service = next((k["api_key"] for k in keys if k.get("name") == "service_role"), None)
    if not service:
        print("no service_role key found")
        sys.exit(1)

    # create or update the admin user
    status, body = http(
        f"{url}/auth/v1/admin/users",
        "POST", apikey=service,
        payload={
            "email": email,
            "password": password,
            "email_confirm": True,
            "user_metadata": {"full_name": "Administrator", "role": "Admin"},
        },
    )
    if status not in (200, 201) and "already been registered" not in str(body):
        print("create admin failed:", status, body)
        sys.exit(1)
    if status not in (200, 201):
        # existing account: find id and reset password
        s, users = http(f"{url}/auth/v1/admin/users?email={email}", "GET", apikey=service)
        if s != 200 or not users.get("users"):
            print("could not find existing admin:", s, users)
            sys.exit(1)
        uid = users["users"][0]["id"]
        s, body = http(
            f"{url}/auth/v1/admin/users/{uid}",
            "PUT", apikey=service,
            payload={"password": password, "email_confirm": True},
        )
        print("reset existing admin:", s)
        if s != 200:
            sys.exit(1)

    print("ADMIN READY:", email)


if __name__ == "__main__":
    main()
