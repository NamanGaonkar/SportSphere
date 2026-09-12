#!/usr/bin/env python
"""SportSphere — apply branded auth email templates.

Uses the Supabase Management API to set the four transactional email
templates (confirmation, invite, magic link, password recovery) to the
branded HTML in supabase/email_templates/.

Reads SUPABASE_ACCESS_TOKEN + SUPABASE_URL from the root .env.
"""
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TEMPLATES = {
    "confirmation": ("Confirm your signup", "email_confirmation.html"),
    "invite": ("You have been invited", "invite.html"),
    "magic_link": ("Your login link", "magic_link.html"),
    "recovery": ("Reset your password", "password_recovery.html"),
}


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
    token = env.get("SUPABASE_ACCESS_TOKEN")
    url = env.get("SUPABASE_URL")
    if not token or not url:
        print("Missing SUPABASE_ACCESS_TOKEN or SUPABASE_URL in .env")
        sys.exit(1)
    ref = url.replace("https://", "").split(".")[0]
    api = f"https://api.supabase.com/v1/projects/{ref}/config/auth"

    for key, (subject, fname) in TEMPLATES.items():
        with open(os.path.join(ROOT, "supabase", "email_templates", fname), encoding="utf-8") as f:
            html = f.read()
        payload = {
            "subject": subject,
            "content": html,
        }
        status, body = http(api, "PATCH", token=token, payload={
            f"mailer_{key}_custom_subject": subject,
            f"mailer_{key}_custom_body": html,
        })
        print(f"{key}: status {status}")
        if status not in (200, 201, 204):
            print(body)
            sys.exit(1)
    print("EMAIL TEMPLATES APPLIED")


if __name__ == "__main__":
    main()
