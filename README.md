# IBM API Connect Flow Pilot skills extension

> [!WARNING]
> **Use this extension only on development environments.** Never point it at a gateway or cluster
> used in production: the AI assistant publishes projects and runs live calls on the environment it
> is given.

IBM publishes AI skills for API Connect and DataPower Interact Gateway (IDIG) under the name
**API Connect Flow Pilot**. This repository extends them.

- It does not replace or modify any IBM file.
- It is a set of Markdown files and scripts, organized per IBM skill, that you link next to the IBM skills.
- API Connect Flow Pilot has no extension hook, so the precedence mechanism is the one of the
  webMethods Flow Pilot (`extended-skill/`), carried over here by an `AGENTS.md` preflight.

---

## Ambition

IBM's skills generate, lint, build and publish API Connect projects. This extension lets you adapt them
to your own practices, without forking them and without losing your changes when IBM ships a new version:

1. **Complete** the IBM skills: extra rules, policies, defaults and steps.
2. **Correct** them when the IBM content is wrong or outdated: "the skill says X, do Y instead".
3. **Override** conventions and preferences (naming, formatting, defaults), with a precedence that is
   explicit and predictable.
4. **Plug in your own scripts**, run before or after a skill.
5. **Keep the guard rails.** Extensions never override the rules that keep a project valid and safe
   (see [What cannot be overridden](#what-cannot-be-overridden)).

---

## Prerequisites

### API Connect Flow Pilot

**➡ [Download Flow Pilot from IBM](https://www.ibm.com/resources/mrs/assets/DownloadList?source=WebMtds_FlowPilot&lang=en_US)**

- This extension was written for **API Connect Flow Pilot 12.1.1.2.4**.
- The extension directories are named after the IBM skills (`asset-manager`, `publish-project`…).
  Install the IBM skills first.

### An AI tool that reads `AGENTS.md`

The preflight that loads the extensions is written in the `AGENTS.md` file at the root of the project.
Claude Code falls back to `AGENTS.md` when there is no `CLAUDE.md` in the project or its parents.

---

## Installation

```bash
git clone <this-repository> skills-ext
cd skills-ext
./install.sh <path-to-skills>
```

`<path-to-skills>` is the folder where the IBM skills are installed, for example `~/.agents/skills`.
For each installed skill that has an extension directory, the script creates a symlink
`<path-to-skills>/<skill>/extended-skill` pointing to `<repo>/<skill>`.

- A skill that is not installed is skipped.
- A real `extended-skill` directory is never replaced.
- Repeat for each AI tool.

Then copy `AGENTS.md` (from the project that uses this extension) to the root of your project, or merge
its preflight section into yours.

### Check

Ask the assistant to use any IBM skill. Its reply must start with `skills-ext applied: <files>`, or with
`skills-ext: none found` when there is nothing to apply.

---

## Layout

```
_global/                  # applies to every skill
  10-example.md
<skill-name>/             # one directory per IBM skill, same name as the skill
  10-naming.md            # any number of .md files
  custom-instructions.md  # optional, always applied last
  scripts/                # your own scripts, referenced from the .md files
install.sh
```

Extension files are free-form Markdown. Typical content:

- **Corrections**: what the IBM skill says, and what to do instead.
- **Rules**: naming, defaults, prohibitions, policies to add.
- **Steps**: to add, or to replace in the IBM skill.
- **Scripts**: to run before or after the skill, from `<skill-name>/scripts/`.

### Adding an extension

Create `<skill-name>/NN-topic.md`, or `_global/NN-topic.md` for something that applies to every skill.
Prefix the file with a number to control the order.

---

## Precedence

From weakest to strongest:

1. The original `SKILL.md` (IBM).
2. `_global/*.md`, in alphabetical order.
3. `<skill-name>/*.md`, in alphabetical order, with `custom-instructions.md` last.

When two files disagree, the later one wins. `README.md` files are skipped.

## What cannot be overridden

Extensions override conventions and preferences. They never override these rules; on conflict the rule
wins and the assistant explains why:

- **Project validity**: the JSON schemas retrieved dynamically by `asset-manager`.
- **No guessed endpoint URL**: the assistant never guesses, defaults or infers one.
- **Lint before build and publish**: `apic lint` must report no error.

---

## Limits

- The extensions are applied because the assistant is instructed to do so, not enforced by a hook.
  The `skills-ext applied:` line at the start of each reply lets you check that it happened.
- If IBM renames or reworks a step, a correction that targets it may become obsolete. Review the
  extensions when you upgrade the IBM skills.
