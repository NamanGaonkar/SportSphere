#!/usr/bin/env python
"""Run a SQL file against Supabase and print the FULL result set (no truncation).
Usage: python scripts/query_sql.py <file.sql>
"""
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
from apply_sql import load_env, http  # noqa: E402


def main():
    if len(sys.argv) < 2:
        print("usage: python scripts/query_sql.py <file.sql>")
        sys.exit(1)
    sql_path = os.path.join(ROOT, sys.argv[1])
    with open(sql_path, encoding="utf-8") as f:
        sql = f.read()

    env = load_env()
    token = env.get("SUPABASE_ACCESS_TOKEN")
    url = env.get("SUPABASE_URL")
    ref = url.replace("https://", "").split(".")[0]

    status, body = http(
        f"https://api.supabase.com/v1/projects/{ref}/database/query",
        "POST", token=token,
        payload={"query": sql},
    )
    out = json.dumps(body, indent=1, default=str) if not isinstance(body, str) else str(body)
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    print(out)


if __name__ == "__main__":
    main()
