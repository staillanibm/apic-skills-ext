---
name: apic-field-notes
description: Field notes that complement IBM's official API Connect Flow Pilot skills (asset-manager, build-project, lint-project, project-manager, publish-project, test-generator) when publishing a REST API or product on the DataPower Nano Gateway - backend authentication, subscription security, plan quotas and per-consumer rate limits, publish and republish behaviour, TLS client profile, subscriptions and credentials. Use whenever any of those IBM skills is active or about to be used for a REST API, or when working with apic CLI projects, plans, quotas, rate limits, subscriptions or catalogs. Read the section of NOTES.md that matches the task before proceeding.
---

# API Connect REST on nano: field notes

This skill carries no procedure of its own: it makes [`NOTES.md`](NOTES.md) discoverable. `NOTES.md` is a running log of
what IBM's skill text does not say or gets wrong, each section with a status (verified, doc, untested).

## When to read it

| If working with... | Read this section of NOTES.md |
|---|---|
| Any secret, credential or creds file | "1. Secrets and credentials" |
| `asset-manager`: calling a backend that needs authentication; backend security schemes in the spec | "2. Backend authentication" |
| `asset-manager`: Quota, Plan, RateLimit, RateLimitDef; "aliases ... are not used" at publish; limits per consumer | "3. Plan quotas and rate limits" |
| `asset-manager`: ExtractIdentity, Authenticate, Authorize for client id and secret; OWASP step | "4. Subscription security" |
| `publish-project`: tool names, pre-flight, a publish error about a TLS client profile | "5. Publish: tool names, pre-flight, TLS client profile" |
| `publish-project`: republish, `migrateSubscriptions`, an `undefined` endpoint | "6. Republish" |
| Subscribing an application, consumer organizations, credentials files | "7. Subscribing and obtaining credentials" |
| `asset-manager`: Parse, ValidateAPISpecification, Set/Remove headers, SQLInjectionFilter, OWASP policies | "8. Assembly policies: what works at runtime" |

Read the whole relevant section, not just the heading. The schemas from `apic schema get` always win over these notes.

## Related skills

- [`rest-proxy-publish`](../rest-proxy-publish/SKILL.md): the end-to-end flow, from backend to tested, subscribed API.
- [`apic-diagnostics`](../apic-diagnostics/SKILL.md): is it live, why 401 / 429 / 500, rate limit tests, read-only on the
  cluster.
