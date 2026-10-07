# API Connect REST on nano: skills extension

> Use these skills on development environments only. The assistant publishes projects, runs live calls and reads cluster
> state on the environment it is given.

IBM's Flow Pilot skills (in `../skills/`) are never modified. This directory adds three skills that you install **next to**
them. Same pattern as `idig-skills-ext`: separate skills, not overrides.

| Skill | What it does |
|---|---|
| [`apic-field-notes`](apic-field-notes/SKILL.md) | Pointer skill. Loaded whenever an IBM skill is active for a REST API; sends the assistant to the right section of [`NOTES.md`](apic-field-notes/NOTES.md): backend authentication, subscription security, plan quotas and per-consumer rate limits, publish and republish, TLS client profile, subscriptions and credentials. |
| [`apic-diagnostics`](apic-diagnostics/SKILL.md) | Checking a REST API after publish: is it live, why 401 / 429 / 500, rate limit tests. Read-only on the cluster. Script `scripts/nano-health.sh`, `scripts/ratelimit_burst.py`. |
| [`rest-proxy-publish`](rest-proxy-publish/SKILL.md) | The end-to-end flow, in five phases with an approval after each: backend, secured API, publish, deployment check, consume and test. Scripts `scripts/preflight.sh`, `scripts/check-secret-keys.sh`. Evaluation in `evals/rest-proxy.md`. |

## Prerequisites

Everything the IBM skills need, including the `apic` CLI; `oc` with read access to the gateway cluster; `python3`.

## Installation

```bash
cd skills-ext
cp -R apic-field-notes apic-diagnostics rest-proxy-publish <path-to-skills>/
```

`<path-to-skills>` is the folder where the IBM skills are installed (in this workspace `.agents/skills`, with
`.claude/skills` and `.bob/skills` holding links to it). Repeat for each AI tool.

## Check

Ask the assistant to publish a REST API. Before acting it should read the relevant section of
`apic-field-notes/NOTES.md`.

## Maintaining the notes

Add what you learn to `NOTES.md` as a new section or a bullet in an existing one, with a status (verified, doc,
untested) and, for a correction, what the IBM text says and what really happens. Keep `apic-field-notes/SKILL.md`'s table
in step.
