#!/usr/bin/env python
"""Normalize .env / .env.example to LF endings and strip any stray
CR/quotes around values, so shell pipelines feeding --dart-define
always get clean values. Run from the repo root:  python scripts/fix_env.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

for name in (".env", ".env.example"):
    path = os.path.join(ROOT, name)
    if not os.path.exists(path):
        continue
    raw = open(path, encoding="utf-8").read()
    lines = []
    for line in raw.replace("\r\n", "\n").split("\n"):
        stripped = line.rstrip("\r")
        if "=" in stripped and not stripped.lstrip().startswith("#"):
            key, val = stripped.split("=", 1)
            val = val.strip().strip('"').strip("'")
            stripped = f"{key}={val}"
        lines.append(stripped)
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print(f"normalized {name}")
print("done")
