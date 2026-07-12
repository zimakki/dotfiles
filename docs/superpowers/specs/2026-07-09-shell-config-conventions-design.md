# Shell-Config Conventions: Skills & Guardrails — Design

**Date:** 2026-07-09
**Status:** Implemented in PR #6

> Historical design record. `AGENTS.md` is now the canonical shared instruction
> file, `CLAUDE.md` is only its compatibility shim, and repo skills are
> canonical under `.agents/skills/`. The Claude-specific paths and policies
> below are preserved to explain the original design, not as current operating
> instructions.

## Problem

Twice now, PATH entries for tools (most recently `psql` from Postgres.app) were placed in `zshrc`, where non-interactive shells (agents/IDEs/daemons via `zsh -lc`) never source them — so the tool was "not found." An audit also revealed ~11 dead PATH lines accumulated from tool installers. Earlier PR #6 commits fixed this with a guarded `path` array in `zshenv`, per-host `hosts/<LocalHostName>.zsh`, and `zshrc` cleanup, but nothing yet **prevents recurrence**.

Two failure modes to prevent:
1. **Skill-driven:** `install-app` *actively instructs the mistake* — its §3 says to add PATH entries to `zshrc`.
2. **Ad-hoc:** the `psql` mistake happened during ordinary work, not a skill invocation. Skills load only when triggered, so a rule buried in a skill would not have caught it. The repo has **no `CLAUDE.md`** — no always-loaded guardrail layer.

## Goal

Encode the shell-config convention once, make it visible in both the always-loaded layer (so ad-hoc work follows it) and the relevant skills (so installs/removals/audits follow it), and fix the active bug in `install-app`.

## Non-goals

- Re-doing PR #6's earlier config changes (handled by preceding commits in this PR).
- Restructuring the other skills' unrelated sections.
- A new standalone "shell-config" skill (rejected: adds a 4th skill and a trigger-arbitration problem; the convention is better as shared reference + always-loaded pointer).

## Best-practice basis

Per Anthropic's Skill authoring guidance: skills stay lean with detail in reference files **one level deep**; `CLAUDE.md` is the always-loaded entry point whose job is to **point** at relevant docs, not inline them. Skills are normally self-contained/portable, but these three are **permanently project-local** and the rule must **also** govern ad-hoc work — so a shared repo-level doc referenced by `CLAUDE.md` and the skills is the correct fit, accepting a deliberate departure from the "bundle inside each skill" default in exchange for DRY and always-loaded coverage.

Sources: platform.claude.com Skill authoring best practices; Agent Skills overview; humanlayer.dev "Writing a good CLAUDE.md".

## Architecture — three tiers

```
CLAUDE.md (repo root, ALWAYS loaded)
   │  short rule + "before touching shell config or installing tools, read →"
   ▼
docs/conventions/shell-config.md (canonical, loaded on demand)
   ▲   ▲   ▲
   │   │   └── .claude/skills/cleanup-report/SKILL.md  (audit against it)
   │   └────── .claude/skills/uninstall-app/SKILL.md   (remove per it)
   └────────── .claude/skills/install-app/SKILL.md     (install per it)
```

### Tier 1 — `docs/conventions/shell-config.md` (canonical, new)

Single source of truth. Table of contents at top (file will exceed 100 lines).
Sections:
1. **The one rule** — environment (PATH/exports) → `zshenv`; command behavior (aliases, prompt, `cd`/zoxide, completions) → `zshrc` (interactive-only).
2. **Startup-file model** — which files each shell type sources; why `zsh -lc` skips `zshrc`.
3. **Adding a PATH entry** — the guarded `path` array in `zshenv`: append tool dirs (mise shims keep priority), prepend only `~/.local/bin`; `typeset -U`; existence guard `[[ -d ]]` for cross-machine safety.
4. **Shell hooks / completions / prompt widgets** — go in `zshrc`, guarded by `[[ -t 1 ]]`; keep `zsh-syntax-highlighting` last.
5. **Per-host config** — `hosts/<LocalHostName>.zsh` keyed off `scutil --get LocalHostName`; committed; NO SECRETS; rename caveat.
6. **macOS path_helper** — `/etc/zprofile` reorders PATH for login shells; why order rarely matters (presence, not priority); the optional `.zprofile` re-assert and when it's warranted.
7. **Secrets** — never committed; 1Password / `~/.zsh_secrets`.
8. **Decision checklist** — a short "installer gave me a shell snippet — where does each line go?" table.

### Tier 2 — `CLAUDE.md` (repo root, new)

Short, always-loaded. Contents:
- One-line repo purpose (single entry point for machine setup; installs via BrewFile/mise; commit to master).
- The one-rule summary (env→zshenv / behavior→zshrc).
- **Pointer**: "Before editing `zshenv`/`zshrc`/PATH or installing a tool, read `docs/conventions/shell-config.md`."
- Pointers to the three skills and `MIGRATION.md`.
Keep it a pointer file, not a rules dump.

### Tier 3 — skill edits

**`install-app/SKILL.md`** — fix §3 (the active bug). Replace "add it to `zshrc`" with a decision:
- a **bin directory** → add to the guarded `path` array in `zshenv` (existence-guarded); do **not** add to `zshrc`; if the tool is mise-managed, no PATH entry needed (shim covers it).
- a **shell init hook / completion / prompt widget** (`eval "$(tool init zsh)"`, etc.) → `zshrc`, guarded by `[[ -t 1 ]]`, keeping zsh-syntax-highlighting last.
- an **exported env var** → `zshenv`.
- **machine-specific** → `hosts/<LocalHostName>.zsh`.
Add one-line pointer to the canonical doc.

**`uninstall-app/SKILL.md`** — extend §3.4: also remove the tool's entry from the `zshenv` guarded `path` array and from any `hosts/*.zsh`; keep the existing `zshrc` alias/eval cleanup. Add pointer.

**`cleanup-report/SKILL.md`** — add to §5: detect **PATH exports living in `zshrc`** that should be in `zshenv` (a new "misplaced, not just dead" finding) and be aware of `hosts/*.zsh`. Add pointer. (Existing dead-PATH-dir and dangling-symlink checks stay.)

## Data flow / usage

- Ad-hoc shell edit: `CLAUDE.md` (always loaded) → agent reads canonical doc → follows it.
- Install: `install-app` triggered → its fixed §3 + pointer → canonical doc for edge cases.
- Audit: `cleanup-report` flags misplaced PATH lines against the canonical rule.

## Verification

- `install-app` §3 no longer contains the string "add it to `zshrc`" for PATH; contains the zshenv/guarded-array guidance.
- `CLAUDE.md` exists at repo root and links to `docs/conventions/shell-config.md`.
- Canonical doc has a ToC and all 8 sections.
- Each of the three skills links to the canonical doc exactly once.
- Sanity: grep the three skills + CLAUDE.md for the canonical doc path resolves to an existing file.

## Risks

- **Drift:** if the config conventions change, the canonical doc must be updated (single place — that's the point). CLAUDE.md and skills only point, so they don't drift.
- **CLAUDE.md bloat:** mitigated by keeping it a pointer file; resist inlining rules.
- **Departure from self-contained-skill norm:** accepted deliberately; documented in the canonical doc's header and here.
