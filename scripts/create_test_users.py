#!/usr/bin/env python
"""SportSphere — create role test accounts.

Reads SUPABASE_URL + SUPABASE_ACCESS_TOKEN from the root .env.
Creates (or resets) one account per role, all with the same password.
Prints the credentials table at the end.
"""
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TEST_USERS = [
    ("Admin", "Admin SportSphere", "admin@sportsphere.app"),
    ("Athlete", "Athlete One", "athlete@sportsphere.app"),
    ("Coach", "Coach One", "coach@sportsphere.app"),
    ("HR", "HR Manager", "hr@sportsphere.app"),
    ("Finance", "Finance Lead", "finance@sportsphere.app"),
    ("VenueManager", "Venue Manager", "venuemanager@sportsphere.app"),
]
PASSWORD = "Test@1234"


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

    created = []
    for role, full_name, email in TEST_USERS:
        status, body = http(
            f"{url}/auth/v1/admin/users",
            "POST", apikey=service,
            payload={
                "email": email,
                "password": PASSWORD,
                "email_confirm": True,
                "user_metadata": {"full_name": full_name, "role": role},
            },
        )
        if status in (200, 201):
            print(f"created  {role:13s} {email}")
            created.append(email)
        elif "already been registered" in str(body):
            # reset password + metadata on the existing account
            s, users = http(f"{url}/auth/v1/admin/users?email={email}", "GET", apikey=service)
            if s == 200 and users.get("users"):
                uid = users["users"][0]["id"]
                s2, _ = http(
                    f"{url}/auth/v1/admin/users/{uid}",
                    "PUT", apikey=service,
                    payload={
                        "password": PASSWORD,
                        "email_confirm": True,
                        "user_metadata": {"full_name": full_name, "role": role},
                    },
                )
                # also update the profile row (role may have changed)
                http(
                    f"https://api.supabase.com/v1/projects/{ref}/database/query",
                    "POST", token=token,
                    payload={"query": f"update public.profiles set role='{role}', full_name='{full_name}' where id='{uid}';"},
                )
                print(f"reset    {role:13s} {email}")
                created.append(email)
            else:
                print(f"FAILED   {role} {email}: lookup {s}")
        else:
            print(f"FAILED   {role} {email}: {status} {str(body)[:120]}")

    # the Admin role must be set in SQL (signup path can never grant it)
    for role, full_name, email in TEST_USERS:
        if role != "Admin":
            continue
        status, users = http(f"{url}/auth/v1/admin/users?email={email}", "GET", apikey=service)
        if status == 200 and users.get("users"):
            uid = users["users"][0]["id"]
            http(
                f"https://api.supabase.com/v1/projects/{ref}/database/query",
                "POST", token=token,
                payload={"query": f"update public.profiles set role='Admin' where id='{uid}';"},
            )
            print("admin role granted via SQL")

    print("\n================ TEST ACCOUNTS ================")
    print(f"Password for all: {PASSWORD}\n")
    for role, full_name, email in TEST_USERS:
        print(f"{role:13s} | {full_name:20s} | {email}")
    print("===============================================")


if __name__ == "__main__":
    main()
