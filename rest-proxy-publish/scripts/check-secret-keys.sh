#!/bin/sh
# List the key names (never the values) of a Kubernetes secret, and the closest names if it does not exist.
# Usage: check-secret-keys.sh <namespace> <secret-name>
set -eu
[ $# -eq 2 ] || { echo "usage: $0 <namespace> <secret-name>" >&2; exit 1; }
ns=$1
name=$2

if oc get secret "$name" -n "$ns" >/dev/null 2>&1; then
  oc get secret "$name" -n "$ns" -o json | python3 -I -c '
import sys, json
d = json.load(sys.stdin)
print("type:", d.get("type"))
print("keys:", sorted(d.get("data", {}).keys()))
'
else
  echo "secret '$name' not found in namespace '$ns'. Similar names:"
  stem=$(echo "$name" | tr -d '_-' | cut -c1-6)
  oc get secrets -n "$ns" -o name 2>/dev/null | sed 's#^secret/##' | while read -r s; do
    flat=$(echo "$s" | tr -d '_-')
    case "$flat" in *"$stem"*) echo "  $s" ;; esac
  done
  exit 1
fi
