---
name: dotfiles-skill-linter
description: Audit and repair skills managed by this dotfiles repo for Agent Skills metadata, naming, progressive-disclosure limits, and global discovery across generic agents, Claude Code, and Codex. Use when adding or changing a skill, checking machine setup, diagnosing a missing skill, or asking to lint, sync, link, distribute, or audit skills.
---

# Lint and sync dotfiles skills

Treat `.agents/skills/` as the canonical, vendor-neutral source for skills, and
`AGENTS.md` as the canonical repo instruction file. Do not maintain copies under
client-specific directories beyond the required compatibility shims.

## Audit

From the dotfiles repository root, run:

```sh
scripts/maintenance/sync-agent-skills.sh
```

Report every failure and warning. The command validates canonical `SKILL.md`
metadata and Codex `agents/openai.yaml` interface metadata, checks the
`AGENTS.md`/`CLAUDE.md` instruction arrangement, and confirms that each repo
skill resolves from these user-level discovery roots:

- `~/.agents/skills`
- `~/.claude/skills`
- `${CODEX_HOME:-~/.codex}/skills`

From a secondary worktree, live discovery links are expected to resolve to the
canonical checkout and therefore appear as mismatches. Do not repair those
links from the worktree; use `scripts/ci_checks.sh` for its temporary-HOME
discovery test, and run the live audit again from the canonical checkout after
the change is merged.

Also run the current Codex validator against every canonical skill when both
the script and its Python `yaml` dependency are available:

```sh
for skill in .agents/skills/*; do
  python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py "$skill"
done
```

If either prerequisite is unavailable, report the secondary validator as
unavailable; do not modify a client-owned system skill or the global Python
interpreter during an audit.

Do not modify third-party or client-owned system skills during an audit.
Hunk is the exception to canonical repo ownership: when installed, its bundled
`hunk-review` skill is linked directly from the path reported by
`hunk skill path`, preferring Homebrew's stable `opt` path. Do not copy that
skill into the repo, because Hunk upgrades should update it in place.

## Repair

After reviewing the audit, run:

```sh
scripts/maintenance/sync-agent-skills.sh --fix
```

The repair is idempotent. It creates missing discovery directories and links.
If a destination is unmanaged, it preserves it as a timestamped backup before
creating the link. Each discovery root records repo-managed names in
`.dotfiles-managed-skills`, allowing later audits to detect renamed or removed
skills and `--fix` to prune only obsolete managed symlinks.

Run the read-only audit again, then `scripts/bootstrap/verify.zsh` when a full
machine verification is appropriate. Tell the user that already-running agent
sessions may need to restart before newly discovered skill metadata appears.

## Add or update a skill

Create skills only in `.agents/skills/<skill-name>/`. Follow the Agent Skills
specification: a lowercase hyphenated directory matching the frontmatter
`name`, a useful `description` explaining both capability and triggers, and a
concise `SKILL.md`. Put deterministic logic in `scripts/`, detailed material in
`references/`, and output resources in `assets/`.

Keep shared project instructions in `AGENTS.md`. Keep `CLAUDE.md` as a thin
compatibility shim that imports `@AGENTS.md`; do not duplicate project rules in
both files.

Generate or refresh `agents/openai.yaml` with Codex's skill-creator utilities,
validate the skill, run this linter with `--fix`, and commit the canonical files
and any setup-script changes. Never commit generated home-directory links.
