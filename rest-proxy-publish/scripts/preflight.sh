#!/bin/sh
# Read-only pre-flight before publishing a project to a nano gateway catalog.
# Usage: preflight.sh <workspace-dir> <project> [gateway-namespace]
# Runs lint and build, then checks what can be checked offline or with oc. Catalog checks that need the MCP tools
# (gateway ready, consumer org, TLS client profile in the catalog) are printed as a reminder list.
set -eu
[ $# -ge 2 ] || { echo "usage: $0 <workspace-dir> <project> [gateway-namespace]" >&2; exit 1; }
ws=$1
project=$2
ns=${3:-}
dir="$ws/$project"
status=0

echo "== lint"
if apic lint "$project" --localDir "$ws" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E "Error|completed|failed"; then :; fi
apic lint "$project" --localDir "$ws" >/dev/null 2>&1 || { echo "lint reported errors: ask the user before going on"; status=1; }

echo "== build"
mkdir -p "$ws/builds"
apic build "$project" --localDir "$ws" --output "$ws/builds/$project.zip" 2>&1 | grep -E "completed|failed|rror" || true
[ -f "$ws/builds/$project.zip" ] || { echo "no build zip: stop"; exit 1; }
echo "zip to publish: $ws/builds/$project.zip"

echo "== files that should not be there"
for f in "$dir"/*.yml "$dir"/*.yaml; do [ -f "$f" ] && echo "unexpected file in the project root: $f"; done
grep -rlE "^ *(static:|password:)" "$dir" --include=*.yaml --include=*.yml 2>/dev/null | sed 's/^/credentials in clear text? /' || true

echo "== secrets referenced by SetAuthorization (keys only)"
for f in $(grep -l "kind: SetAuthorization" "$dir"/policies/*.yaml 2>/dev/null || true); do
  secret=$(sed -n 's/^ *secret: *//p' "$f" | head -1)
  [ -n "$secret" ] || continue
  if [ -n "$ns" ]; then
    echo "secret $secret in $ns:"
    "$(dirname "$0")/check-secret-keys.sh" "$ns" "$secret" || status=1
  else
    echo "secret $secret: pass a gateway namespace to check it"
  fi
done

echo "== rate limit aliases"
for plan in "$dir"/plans/*.yaml; do
  [ -f "$plan" ] || continue
  sed -n '/withQuota:/,$p' "$plan" | sed -n 's/^ *\([A-Za-z0-9_-]*\):$/\1/p' | grep -v withQuota | while read -r alias; do
    if grep -rqs "name: $alias\$" "$dir/policies" "$dir/security"; then echo "alias $alias: consumed by a policy"
    else echo "alias $alias: NOT consumed by any RateLimit policy (publish will fail)"; fi
  done
done

echo "== TLS"
if grep -qs "https://" "$dir"/policies/*invoke*.yaml && ! grep -qs "tlsClientProfile" "$dir"/policies/*invoke*.yaml; then
  echo "Invoke targets https without tlsClientProfile: calls will fail with 500 at run time"; status=1
fi

cat <<'E'
== to check with the MCP tools / API Manager (not done by this script)
- ListGatewaysInCatalog: a gateway of the right type in state ready
- ListConsumerOrgs for the target catalog (organizations are per catalog)
- The catalog has the TLS client profile named in the Invoke policy (catalog settings); cannot be listed via MCP
E
exit $status
