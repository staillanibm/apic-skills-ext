#!/usr/bin/env python3
"""Burst test for plan and per-consumer rate limits. Never prints client ids or secrets.

Usage:
  ratelimit_burst.py --endpoint https://host/base --path '/items?pageSize=1' --calls 5 \
      --creds sub3/subscriptions/x-creds.json --creds sub5/subscriptions/x-creds.json [--insecure]

Each --creds file holds client_id and client_secret (as written by the subscription tool). Consumers are tested one
after the other, in the order given, starting at the beginning of a clock minute so the 1-minute counters are fresh.
A first request without credentials wakes a scaled-to-zero runtime (a 401 consumes no quota).
"""
import argparse
import json
import subprocess
import sys
import time


def curl(url, headers, insecure):
    cmd = ["curl", "-s", "-m", "40", "-o", "/dev/null", "-w", "%{http_code}", url]
    if insecure:
        cmd.insert(1, "-k")
    for k, v in headers.items():
        cmd += ["-H", f"{k}: {v}"]
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--endpoint", required=True)
    ap.add_argument("--path", default="/")
    ap.add_argument("--calls", type=int, default=5, help="calls per consumer")
    ap.add_argument("--creds", action="append", required=True)
    ap.add_argument("--insecure", action="store_true", help="curl -k, development environments only")
    a = ap.parse_args()

    consumers = []
    for p in a.creds:
        c = json.load(open(p))
        consumers.append((p.split("/")[0], c["client_id"], c["client_secret"]))
    if len({c[1] for c in consumers}) != len(consumers):
        sys.exit("credentials are not distinct: refusing to run (it would hit one consumer's own limit)")

    url = a.endpoint.rstrip("/") + a.path
    for _ in range(6):
        if curl(url, {}, a.insecure) == "401":
            break
        time.sleep(8)
    time.sleep(10)

    now = time.time()
    time.sleep(61 - (now % 60) + 1)
    for label, cid, sec in consumers:
        codes = [curl(url, {"X-IBM-Client-Id": cid, "X-IBM-Client-Secret": sec}, a.insecure) for _ in range(a.calls)]
        print(f"{label} x{a.calls}", codes)


if __name__ == "__main__":
    main()
