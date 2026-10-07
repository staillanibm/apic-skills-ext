---
name: rest-proxy-publish
description: End-to-end playbook to put an existing REST backend behind IBM API Connect on the DataPower Nano Gateway - spec, backend authentication, subscription security (client id + secret), plan quotas and per-consumer rate limits, publish to a catalog and developer portal, subscription, and live tests. Use when the user asks to "create an API proxy", "expose this backend through API Connect", "publish with subscription security and rate limits", or to build, publish and test a REST proxy in one flow. It orchestrates asset-manager, lint-project, build-project, publish-project, apic-field-notes and apic-diagnostics; it does not replace them.
---

# REST proxy: from backend to tested, subscribed API

Orchestration only. Each phase uses the skill named in it. Before each phase read the matching section of
[`apic-field-notes/NOTES.md`](../apic-field-notes/NOTES.md). The schema from `apic schema get` always wins over any
example here.

## Working agreement

1. Show the plan first and get it validated. Ask for approval at the end of every phase.
2. Cluster access is read-only unless the user formally approves a specific change (NOTES section 1).
3. Never guess the backend URL or a secret name. Ask, and check what exists.
4. If a reply could answer only one of two questions, ask again before acting on the other.
5. Report outcomes as observed. Say "not verified" for anything not observed.

## Inputs to collect once (one consolidated question)

Backend base URL and where its spec is (`/openapi.json`?), project name, target catalog, the Kubernetes secret holding the
backend credentials and its namespace, subscription security (client id, or client id + secret), plan limit and
per-consumer limit, whether write calls (POST, PUT, DELETE) may be tested, whether the API has free-text fields, and read-only `oc` access.

## Phase 1: discovery (read-only)

- `oc whoami`; `scripts/check-secret-keys.sh <ns> <secret>` (keys only; it suggests near names).
- Fetch the spec; list operations, security schemes, servers.
- MCP: `ListCatalogs`, `ListGatewaysInCatalog`, `ListConsumerOrgs`, `ListManagedProjects`.
- Gate: report findings, wrong secret names, a missing consumer organization.

## Phase 2: project and API design (nothing published)

- `project-manager` creates the project under the requested path; `asset-manager` builds assets (NOTES sections 2, 3, 4):
  spec copy with consumer security schemes, `ExtractIdentity`, `Authenticate`, `Authorize`, `RateLimit` (+ `RateLimitDef`
  for per-consumer), `SetAuthorization` (backend), `Invoke` (with `tlsClientProfile`), `Telemetry`, `Quota`, `Plan`,
  `Product`.
- `lint-project` then `build-project`. Run `scripts/preflight.sh <workspace> <project> <gateway-namespace>`.
- OWASP step: run it with the official 2023 numbering (the asset-manager checklist numbers differ: say which you use),
  propose, wait for the user's choice.
- If `apic lint` reports errors, show them and ask the user whether to override. Never override silently.
- Gate: list files and decisions; ask before publishing.

## Phase 3: publish

- `publish-project` (NOTES sections 5 and 6): `PublishProject`, `migrateSubscriptions: true`.
- Check `ListPublishedProducts` and `ListPublishedApis`.
- On an error that suggests removing configuration (TLS profile, alias), stop and fix the cause instead.
- Gate.

## Phase 4: deployment check (read-only)

- `apic-diagnostics`: `scripts/nano-health.sh <ns> <filter>`. Wait out the republish swap. Confirm the secret and the TLS
  profile resolved and that the Runtime and API have no conditions: a successful publish does not mean a deployable API.
- Gate.

## Phase 5: consume and test

- A consumer organization must exist in the target catalog. `CreateSubscriptionForPublishedProduct` creates the
  application (NOTES section 7).
- Smoke tests (`apic-diagnostics`): 401 without and with a wrong secret, 200 reads, the approved writes, the response
  headers, then limits with `apic-diagnostics/scripts/ratelimit_burst.py` (three consumers to see the global cap).
- Final report: results table, deviations from the plan, applications created (the tools cannot delete them), files
  holding credentials (keep out of git).

## Known traps (details in NOTES.md)

- The plan quota label is an alias that a `RateLimit` policy must consume, else publish fails.
- Per-consumer limits need `consumerSpecific: true` and `dynamicValue` on the client id.
- Removing `tlsClientProfile` to pass publish gives 500 at run time.
- Renaming an alias on a republish with migration is refused; dropping the migration drops subscriptions.
- A subscription created while the cache is down, or deleted in API Manager, answers 401.
- Valkey `ClusterDown` makes every authenticated call return 500: a platform fault to report.
