---
name: cleanup-report
description: Audit the machine against the dotfiles repo and report cleanup candidates — Brewfile drift, orphaned dependencies, stale CLIs, unused apps, orphaned config dirs, and dead references in zshrc/symlinks. Report first, then offer to fix interactively. Use when the user asks what can be cleaned up, pruned, or audited.
---

# Cleanup report

Run a read-only audit, report all findings, then offer fixes one at a time using
the `uninstall-app` conventions. Never remove anything during the audit.

Before auditing shell config, read `docs/conventions/shell-config.md`.
Parallelize independent checks where possible.

## 1. Homebrew drift

```sh
brew bundle check --file=BrewFile --verbose
brew bundle cleanup --file=BrewFile
brew autoremove --dry-run
brew leaves -r
```

Never pass `--force` to cleanup. Classify a commented `BrewFile` match as
“pruned in repo but still installed”; classify a token absent from the file as
an ad-hoc install that should be added or removed.

## 2. Stale tools and apps

Run the tested Atuin/Homebrew usage audit, which defaults to a 120-day stale
threshold:

```sh
scripts/maintenance/audit-cli-usage.zsh
```

Report its never-used and stale formulae. Do not reimplement its binary
discovery or timestamp loop inline; the script handles zsh arrays without
implicit whitespace splitting.

Treat this only as evidence. Libraries, build dependencies, editor-invoked
tools, and commands used before Atuin history began can look unused.

For GUI apps, prefer the macOS activity database when the terminal has Full
Disk Access; otherwise use visible launcher recency and filesystem timestamps.
Treat Spotlight `kMDItemLastUsedDate` as a weak hint. Cross-reference candidates
with active `BrewFile` casks.

## 3. Repository structure drift

- Confirm canonical app config lives below `config/<app>/` and every stable
  managed source has the intended `[dotfiles]` destination.
- Flag root-level app config files or symlinks; canonical sources belong below
  `config/<app>/`.
- Flag opaque exports, caches, databases, automatic backups, secrets, and
  unmodified generated defaults tracked in Git.
- Treat Claude and Karabiner as app-owned live files with managed JSON overlays.
  Run `scripts/bootstrap/json-overlay.py --check` for each one and report drift;
  never apply an overlay during the audit.
- Treat `scripts/bootstrap/` as an exception boundary. Package inventory,
  static links, typed defaults, and tools belong in their manifests.

## 4. Machine drift and dead references

Run `mise bootstrap status --missing` with a mise version satisfying
`min_version` in `mise.toml`. Report static-link, typed-default, and tool drift.
Do not apply bootstrap from a secondary worktree.

Audit:

- `~/.config` directories for apps no longer installed; use modification time
  only as a hint.
- retired home-directory state such as old runtime managers and project version
  files.
- missing PATH entries from `${(s/:/)PATH}` and the line in
  `config/zsh/zshenv`, `config/zsh/zshrc`, or `config/zsh/hosts/*.zsh` that
  added each one.
- PATH mutations in `config/zsh/zshrc`; environment belongs in
  `config/zsh/zshenv` even when the directory exists.
- shell hooks, sources, aliases, and exported tool variables whose command or
  file no longer exists.
- dangling destinations declared in `[dotfiles]`, the dynamic Lazygit link
  managed by `scripts/bootstrap/link-lazygit-config.zsh`, and discovery links
  managed by `scripts/maintenance/sync-agent-skills.sh`.
- timestamped conflict backups that are no longer needed.

Use a scoped dangling-link search rather than deleting its output:

```sh
find "$HOME" "$HOME/.config" -maxdepth 3 -type l \
  ! -exec test -e {} \; -print 2>/dev/null
```

## 5. Optional deep scan

If Mole is already installed, offer its dry-run for app remnants and orphaned
data. Do not install audit tooling without permission.

## Report

Group findings as:

- **Safe to remove** — clear pruned installs, dead references, dangling links,
  or reviewed backups.
- **Probably unused; confirm** — stale tools, apps, and config directories.
- **Keep; indirect dependency** — libraries and automation-invoked tools.

Ask which findings to act on. Apply one reviewed fix at a time. Never run
`brew bundle cleanup --force`, force a dotfile conflict, or perform a bulk
deletion.
