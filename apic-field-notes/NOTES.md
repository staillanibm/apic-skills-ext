# Notes: REST APIs on the DataPower Nano Gateway (API Connect)

Field observations from publishing, securing and testing a REST proxy on the DataPower Nano Gateway with IBM's Flow
Pilot skills. A single running log, not a mirror of IBM's skill structure: read the section relevant to the task.
None of this reproduces IBM's skill text; it records what that text does not say or gets wrong.

Rules the notes never override: the JSON schemas from `apic schema get`, "never guess the backend endpoint URL", and
"`apic lint` must report no error before build and publish". Each section carries a status: **verified** (observed on a
real run), **doc** (from the IBM documentation only) or **untested** (a hypothesis: say so to the user).

Contents:

1. Secrets and credentials
2. Backend authentication
3. Plan quotas and rate limits
4. Subscription security
5. Publish: tool names, pre-flight, TLS client profile
6. Republish
7. Subscribing and obtaining credentials
8. Assembly policies: what works at runtime

---

## 1. Secrets and credentials

- Never print, log or paste a password, client secret, token or the decoded value of a Kubernetes secret. Show key
  names and lengths only.
- To check a secret's shape, list the keys only (`.data | keys`), never the values.
  `skills/rest-proxy-publish/scripts/check-secret-keys.sh <ns> <secret>` does it and suggests near names.
- Files written by the publish and subscription tools (`subscriptions/*-creds.json`) hold a client id and secret in
  clear text. Do not read them into the conversation: load them inside a script and redact the values in its output.
  Tell the user to keep them out of git.
- If a file you did not write appears in the project (for example an asset with `basic.static` credentials), do not
  publish that folder. Ask the owner; build from a clean copy if told to leave the file alone.
- Never create or modify anything in the gateway namespace without the user's explicit approval for that specific
  change. Reads (`get`, `describe`, `logs`) are fine.

Status: verified.

---

## 2. Backend authentication

The IBM skill has no step for presenting credentials to the backend.

**Basic auth to the backend.** Use a `SetAuthorization` policy with `spec.basic.secret: <kubernetes-secret-name>`,
placed **before** `Invoke` in `main`. Fetch its schema first (`apic schema get SetAuthorization --gateway lwgw`).

- The secret is a Kubernetes secret in the namespace where the gateway runtime runs, with keys `username` and
  `password`. Ask the user for its name, never guess it. If it does not exist, look for near matches
  (a one-letter difference between two near names happened) and ask.
- Do not use `basic.static` (credentials in the project files) or a `Set` policy with an encoded `Authorization`
  header unless the user explicitly accepts credentials in clear text in the project.
- `useIncoming` forwards the caller's own credentials: not what you want for a shared service account.
- The same schema also offers `oAuth2` and `jwt` (with `secret` or `useIncoming`) and `anonymous`.

**Backend security schemes in the spec.** If the backend spec declares `basicAuth` or `bearerAuth`, replace them in the
copy under `spec/` with what consumers really send (for subscriptions: `X-IBM-Client-Id` and `X-IBM-Client-Secret` as
`apiKey` in header).

**Confirm it works.** After publish, `oc get api <name> -o jsonpath='{.status.dependencies.secrets}'` lists the secret
and its keys (`username` required, `password` optional is the gateway's own wording). No condition means it resolved. A
live call returning 2xx from the backend confirms it.

Status: verified.

---

## 3. Plan quotas and rate limits

`references/products-plans-quotas.md` says Quotas, Plans and `RateLimit` are unrelated. For the nano gateway they are
not: a plan quota only takes effect through a `RateLimit` policy in the API assembly.

**Chain for a limit shared by all consumers of a plan.**
1. `Quota` (`maxRequest`, `interval`, `extensions.dp-nano-gateway.spec.exceedAction: return429`).
2. `Plan` with `spec.qos.withQuota.<label>: [ $ref: <quota> ]`.
3. A `RateLimit` policy whose `extensions.dp-nano-gateway.spec.limits` has an `aliasLimit` with `name: <label>` and
   `operation: consume`, in `main` **after** `Authorize` and before `Invoke`.

The plan label **is** the alias. If no policy in the API consumes it, publish fails with "aliases from the rate limit
map of plan '<plan>' are not used in any API or Global Policy".

The IBM documentation (`udng-configuring-plan-rate-limits-datapower-nano-gateway-api-studio`) recommends the special
alias `plan-limit` with target `all` (ignored silently when the effective plan has no such key). Prefer it for a first
publish. Do not rename an existing alias on a republish with subscription migration: the server validates the old
migrated plan against the new API and refuses; changing it needs a publish without migration, which drops
subscriptions (ask the user first). Status of `plan-limit` itself: doc, untested.

**Scope.**
- The plan quota is shared by **all** consumers of the plan. Verified: 10 calls then 429, across two applications.
- Per-consumer limit on a REST API (apiRouter mode): `RateLimitDef` with `consumerSpecific: true` **and**
  `extensions.dp-nano-gateway.spec.dynamicValue: "$header('request', 'X-IBM-Client-Id')"`, consumed from the same
  `RateLimit` policy through `limits[].limitDef` (`operation: consume`, not `update`, which never rejects).
  - `consumerSpecific: true` alone left the counter shared (verified once: a second application got 429 as soon as the
    first had used its calls). The MCP-mode recipe in `idig-field-notes` does not use `dynamicValue`: the modes differ.
  - With `dynamicValue` on the client id, each application has its own counter (verified twice).
- A call refused by the per-consumer limit did not consume the plan quota (5 accepted + 2 refused by one application,
  then another application still got its 5).
- Both levels coexist in one `RateLimit` policy. Global cap with three consumers (plan 10 per minute, per consumer 5):
  verified. Two applications made 5 calls each (200), the third got 429.

`status.dependencies.rateLimitAliases` of the compiled API stayed empty although the plan alias was mapped in the
Runtime, so it does not prove an alias is consumed. Showing a global cap needs more applications than
`plan max / per-consumer max`.

Always fetch the `Quota`, `Plan`, `RateLimit` and `RateLimitDef` schemas first; this section only says how they connect.

---

## 4. Subscription security

- The skill (Step 11 and `references/security-analysis.md`) maps client credentials to
  `Authenticate (subscriptionCredentials)`. The nano schema only has `apiDefinition`, `subscription`, `jwt`, `oauth2`.
  Use `subscription`. The schema wins.
- Client id + client secret: `ExtractIdentity` with `credentialType.apiKey.clientId.httpHeader.name: X-IBM-Client-Id`
  and `clientSecret.httpHeader.name: X-IBM-Client-Secret`, then `Authenticate` and `Authorize` with
  `operation.subscription: {}`.
- Order in `main`: the skill text lists `Authorize` before `Authenticate`; its own example (`DPNano_Product_Weather`)
  and the working project use `ExtractIdentity`, `Authenticate`, `Authorize`. Use the example order, then rate limit,
  then backend auth, then `Invoke`. Security assets go under `<project>/security/`.
- OWASP step: a proxy using one shared backend identity lifts every caller to that identity (object-level and
  function-level authorization cannot be enforced at the gateway). Report it as a finding for the backend owner; do not
  invent a gateway rule the user did not ask for.

Status: verified.

---

## 5. Publish: tool names, pre-flight, TLS client profile

**Tool names.** The skill names `PublishProjectToInteractGateway` on `ai-gateway-management-mcp-server`. With only the
`apic-management-mcp-server`, use `PublishProject`: `zipFilePath` (absolute), `directory` (required, the workspace root),
`catalog`, `migrateSubscriptions: true`. Discovery: `ListCatalogs`, `ListGatewaysInCatalog`, `ListConsumerOrgs`,
`ListPlans`, `ListPublishedProducts`, `ListPublishedApis`. On a republish the result prints the endpoint as `undefined`
and skips the creds file (`overwrite=false`): a display defect, the real endpoint is unchanged (check the `Runtime`
routing with `oc`).

**Pre-flight (read-only)**, `skills/rest-proxy-publish/scripts/preflight.sh` does the first part:
1. `apic lint` with no error, `apic build`.
2. `ListGatewaysInCatalog`: a gateway of the right type in state `ready`.
3. https backend: the `Invoke` policy needs a `tlsClientProfile`, and it must exist in the catalog (catalog settings,
   TLS client profiles). It cannot be listed with the MCP tools: ask the user to confirm it exists and what it trusts.
4. `ListConsumerOrgs` for the target catalog: organizations are per catalog (one in `sandbox` is not in `sandbox-nano`).
5. Secrets referenced by the assembly exist in the gateway namespace (keys only).

**TLS client profile.** Publish said "TLS client profile ... not configured in the catalog". Removing
`tlsClientProfile` from `Invoke` made the publish succeed but every call to the https backend returned 500 at run time
("Target URI ... requires tlsClientProfile in the HTTP endpoint target configuration"). Fix the catalog, not the policy.
The profile appears as a `TLSClientProfile` custom resource and in `status.dependencies.tlsClientProfiles` of the API.

**Publish success is not deployment success.** A policy can pass publish and still block the Runtime: read
`oc get rt` conditions (`ApiDependenciesNotMet` for example) after the swap, before testing.

**Lint errors.** Lint errors are a hard stop in the IBM skills. A `SetAuthorization` with `basic.secret` fails
`apic lint` (3 errors) although the schema allows it and it works at runtime; `SQLInjectionFilter` rule names are
linted against the schema list, not the runtime list (section 8). Show the errors and ask the user before overriding.

Status: verified.

---

## 6. Republish

The skill says republish is the same call with `migrate_subscriptions: true`. What happens:
- The gateway stages a temporary product version with a base path like `/1.0.0-<uuid>` and a second `Runtime`, replaces
  the real product in place, then deletes the temporary one. Wait 15 to 30 seconds before testing; meanwhile `oc get rt`
  shows two runtimes and the temporary path answers.
- The final `Runtime` keeps its name and base path, and scales to zero until the next request.
- The server validates the previous (migrated) plan against the new API: renaming a rate limit alias fails while
  `migrateSubscriptions` is true.
- `migrateSubscriptions: false` drops existing subscriptions and credentials. Never without asking; every consumer must
  resubscribe.
- Adding a policy or limit definition, or changing a limit value, republishes cleanly with migration (verified).

Status: verified.

---

## 7. Subscribing and obtaining credentials

- Create the consumer organization first (API Manager). `CreateSubscriptionForPublishedProduct` fails with "No consumer
  organizations found in catalog" otherwise.
- That tool always creates a **new** application; it cannot subscribe one created earlier with `CreateConsumerApp`
  (which then stays unused). Do not create one first.
- Arguments: `isMCP: false`, `directory`, `catalog`, `consumer_org`, `product_name` as `name:version`, `plan_name`,
  `consumer_app_name`. The file `subscriptions/<product>-creds.json` is written in `directory` and skipped if it exists:
  pass `overwrite: true` or another `directory` for a second application. The second file can have an empty
  `published_assets`: reuse the endpoint from the first.
- Subscribe only when the gateway datastore is healthy (see `apic-diagnostics`). A subscription made while the cache is
  down is unusable (401 "Invalid client credentials"): create a new one. A subscription deleted in API Manager answers
  401 immediately.
- Applications cannot be deleted with these tools: create as few as possible and list them for the user at the end.
- From a machine that does not trust the gateway certificate, `curl -k` is acceptable in development only; say so.

Status: verified.

---

## 8. Assembly policies: what works at runtime

- **`Parse` before `ValidateAPISpecification` on a request body.** Without it the call returns 500 ("Body has not been
  loaded and parsed"). `Parse` limits (`documentType.json`: `maxDocumentSize`, `maxDepth`, `maxValueLength`) also cap
  the payload size. The IBM page shows the options directly under `spec`; the CLI schema nests them in
  `documentType`, and that form worked.
- **`ValidateAPISpecification` (request)** rejects out-of-range or malformed query, path and body with 400.
- **`Set` / `Remove` on `response`** after `Invoke` add and strip headers (`Set` verified).
- **`SQLInjectionFilter`: not recommended.**
  - `message` is a message name (`request`), not an error text. A text there makes every call return 500.
  - Rule names: the CLI schema and lint use `mSSQLCommands` and `orAndAttack`; the runtime and the IBM page use
    `mssqlCommands` and `andOrAttack`. The schema names block the deployment (`ApiDependenciesNotMet`), the runtime
    names fail lint.
  - Blocked requests return 500, and `andOrAttack` rejected ordinary text (an apostrophe plus the word "order").
    `UNION SELECT` in a query value passed.
- **OWASP numbering:** use the 2023 list (API4 resource consumption, API7 SSRF, API8 security misconfiguration).

Status: verified, except `Remove` (not proven separately).
