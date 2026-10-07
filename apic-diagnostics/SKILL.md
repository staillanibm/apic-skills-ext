---
name: apic-diagnostics
description: Diagnose a REST API or product published on the IBM API Connect DataPower Nano Gateway after publish. Use it when a just-published or republished REST API must be confirmed live before testing, when calls return 401, 429 or 500 unexpectedly, when a subscription or client credentials are rejected, when a rate limit or quota does not behave as configured, or when the nano runtime, its cache (Valkey) or a backend secret or TLS profile may be at fault. Triggers on phrases like "check the deployment", "is my API live", "why 401 / 500 / 429", "invalid client credentials", "check the rate limit", "test the quota", "ClusterDown". For MCP servers and LLM proxies use idig-diagnostics instead. Requires read access to the cluster with oc.
---

# APIC nano REST diagnostics

Post-publish verification and troubleshooting of a REST product on the DataPower Nano Gateway. Same spirit as
`idig-diagnostics` (read-only, evidence before conclusions) for the classic API mode (`spec.mode.apiRouter`).

> **Read-only.** Use `oc get`, `describe` and `logs`. Never edit, delete, restart or scale anything in the gateway
> namespace, including Valkey, the operators and the runtime, without the user's explicit approval for that exact change.
> A fix is normally an edit of the project's kind files and a republish.

> **Secrets.** Follow section 1 of `apic-field-notes/NOTES.md`: never print secret values, client secrets or passwords.

## Step 0: confirm access and find the resources

```bash
oc whoami
oc get rt,api -n <ns>                      # Runtime <product>-pro-<hash>, API <api>-<hash>
oc get rt <rt> -n <ns> -o jsonpath='{.spec.mode.apiRouter.routing}{"\n"}{.spec.mode.apiRouter.plans}{"\n"}'
```

`scripts/nano-health.sh <ns> [name-filter]` runs the read-only checks below in one go.

## Step 1: is it live? (never test before this)

- `Runtime` `.status.conditions` empty and `.status.deployment.conditions` `Available`. Right after a publish you may see
  "API ... not deployable: status not reconciled": it clears in about 20 seconds; check again.
- Replicas 0 is normal: the runtime scales from zero. Send one request without credentials (expect 401, it consumes no
  quota) and wait about 15 seconds for the pod.
- After a **republish** the gateway stages a temporary runtime with a base path `/<version>-<uuid>`, swaps, then deletes
  it. Wait until a single runtime remains and the base path is back to `/<version>`.

## Step 2: read what the gateway compiled, not only your YAML

```bash
oc get api <api> -n <ns> -o jsonpath='{.status.conditions}{"\n"}{.status.dependencies}{"\n"}'
```

`dependencies` lists the secrets (with required keys), TLS client profiles, rate limit aliases and cache services the
assembly resolved. `conditions` carries deployment-blocking errors that the publish response never shows.

## Step 3: logs

```bash
oc logs <runtime-pod> -n <ns> --since=3m
```

The default level is error-only. Use the signatures in `references/nano-api-mode.md` before treating an error as new.

## Step 4: smoke tests

Order: no credentials (401), wrong secret (401), valid GET (200), the write operations the user approved, then the rate
limits. Read credentials from the creds file inside a script and redact them in all output. Use `curl -k` only if the
machine does not trust the gateway certificate, in a development environment, and say so.
Rate limit tests: `references/ratelimit-testing.md`.

## Step 5: report

State: runtime state, what the compiled API resolved, each test with its HTTP status, and anything inconclusive.
Say "not verified" for anything you did not observe. List consumer applications created during testing, because the
tools cannot delete them.

## References

- `references/nano-api-mode.md`: where to look, behaviours, log signatures.
- `references/ratelimit-testing.md`: how to test plan and per-consumer limits.
