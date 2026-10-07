#!/bin/sh
# Read-only health summary of nano gateway REST runtimes.
# Usage: nano-health.sh <namespace> [name-filter]
# Prints runtime/api state, conditions, resolved dependencies (secret key names only), pods and recent error lines.
set -eu
[ $# -ge 1 ] || { echo "usage: $0 <namespace> [name-filter]" >&2; exit 1; }
ns=$1
filter=${2:-}

oc whoami >/dev/null || { echo "oc is not logged in" >&2; exit 1; }

echo "== runtimes and apis"
oc get rt,api -n "$ns" 2>&1 | grep -i -E "NAME|${filter:-.}" || true

for rt in $(oc get rt -n "$ns" -o name 2>/dev/null | grep -i -E "${filter:-.}" || true); do
  echo
  echo "== $rt"
  oc get "$rt" -n "$ns" -o json | python3 -I -c '
import sys, json
d = json.load(sys.stdin)
r = d["spec"].get("mode", {}).get("apiRouter", {})
print("routing   :", json.dumps(r.get("routing")))
print("plans     :", json.dumps([{"name": p.get("name"), "rateLimitMap": p.get("rateLimitMap")} for p in r.get("plans", [])]))
print("conditions:", json.dumps(d.get("status", {}).get("conditions")))
dep = d.get("status", {}).get("deployment", {}).get("conditions", [])
print("deployment:", json.dumps([(c["type"], c["status"], c.get("reason")) for c in dep]))
'
done

for api in $(oc get api -n "$ns" -o name 2>/dev/null | grep -i -E "${filter:-.}" || true); do
  echo
  echo "== $api"
  oc get "$api" -n "$ns" -o json | python3 -I -c '
import sys, json
d = json.load(sys.stdin)
s = d.get("status", {})
dep = s.get("dependencies", {})
print("conditions:", json.dumps(s.get("conditions")))
print("secrets   :", json.dumps(dep.get("secrets")))
print("tls       :", json.dumps(dep.get("tlsClientProfiles")))
print("aliases   :", json.dumps(dep.get("rateLimitAliases")), "rateLimitService:", dep.get("rateLimitService"))
'
done

echo
echo "== pods"
oc get pods -n "$ns" 2>&1 | grep -i -E "NAME|${filter:-dpn-rt}|valkey" || true

echo
echo "== recent runtime errors (3m)"
for pod in $(oc get pods -n "$ns" -o name 2>/dev/null | grep -i "dpn-rt-${filter}" || true); do
  echo "-- $pod"
  oc logs "$pod" -n "$ns" --since=3m 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E "ERROR" | cut -c1-240 | tail -10 || true
done
