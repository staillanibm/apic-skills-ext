# Nano gateway, classic REST API (apiRouter mode)

All checks are read-only.

## Where to look

- `oc get rt,api -n <ns>`: one `Runtime` (`<product>-pro-<hash>`) and one `API` per published API.
- `oc get rt <name> -o jsonpath='{.spec.mode.apiRouter.routing}'`: subdomain, domain and base path.
- `oc get rt <name> -o jsonpath='{.spec.mode.apiRouter.plans}'`: plans and their `rateLimitMap` (alias to quota name).
- `oc get api <name> -o jsonpath='{.status.dependencies}'`: secrets, TLS client profiles, rate limit aliases resolved.
  `{.status.conditions}` holds deployment-blocking errors.
- Logs of the runtime pod: `oc logs <pod> -n <ns> --since=3m`.

## Behaviour to expect

- A fresh Runtime sits at 0 replicas. The first request starts a pod (about 15 seconds). Send one request without
  credentials first (a 401 does not consume quota) to wake it.
- Right after publish the Runtime shows "API ... not deployable: status not reconciled". It clears within about
  20 seconds.
- A republish stages a temporary product version with a base path `/<version>-<uuid>`, replaces the product in place and
  deletes the temporary one.

## Log signatures

| Log line | Meaning | Action |
|---|---|---|
| `Failed to extract the client ID from the request` | Request had no `X-IBM-Client-Id` | Expected for the no-credentials test (401) |
| `Invalid client credentials for client <id>` | Unknown client, wrong secret, deleted subscription, or a subscription created while the datastore was down | Check the subscription still exists; otherwise create a new subscription |
| `Cache error(au): ... ClusterDown: Hash slot not served` | The Valkey cluster is not formed; every authenticated call returns 500 | Not a project problem. Report to the cluster owner. `valkey-operator` logs "Not all leader are part of the cluster", leader pods log "Cluster is currently down: I am part of a minority partition" |
| `Body of the message request has not been loaded and parsed` | `ValidateAPISpecification` ran before the body was parsed | Add a `Parse` policy before it |
| `SQL Injection Attack ... detected` | `SQLInjectionFilter` rejected the request (500) | See NOTES section 8 |
| `Target URI '<url>' requires tlsClientProfile ...` | `Invoke` has no TLS client profile for an https backend | Restore `tlsClientProfile`, and make sure the catalog has that profile |
| `... Error accepting a client connection ... peer did not return a certificate` on valkey leaders | TLS noise from a client without a certificate | Seen alongside the cluster fault; not proven to be the cause |

Never restart or edit Valkey, the operator or the gateway without the user's explicit approval.

Status: verified (2026-10-07).
