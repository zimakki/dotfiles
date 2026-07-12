---
name: cleanup-report
description: Audit the machine against the dotfiles repo and report cleanup candidates — Brewfile drift, orphaned dependencies, stale CLIs, unused apps, orphaned config dirs, and dead references in zshrc/symlinks. Report first, then offer to fix interactively. Use when the user asks what can be cleaned up, pruned, or audited.
---

# Cleanup report

Read-only audit first; print the full report; THEN offer fixes one finding at a
time (each fix follows the `uninstall-app` skill's conventions). Never remove
anything during the audit phase.

Before auditing shell config, read `docs/conventions/shell-config.md`.

Run the checks below (parallelize where possible). For each, report findings
with a short "why it's suspect" note, or "✅ clean".

## 1. BrewFile ↔ reality drift

```sh
brew bundle check --file=BrewFile --verbose        # in BrewFile, not installed
brew bundle cleanup --file=BrewFile                # installed, not in BrewFile (DRY-RUN — never --force)
```

Caveat: commented-out BrewFile entries are intentional prunes — anything
`cleanup` lists that matches a commented line is "pruned in repo but still
installed" (strong removal candidate). Anything not in the file at all was
installed ad-hoc and never recorded — candidate to either add (via
`install-app`) or remove.

## 2. Orphaned dependencies & forgotten CLIs

```sh
brew autoremove --dry-run     # deps nothing needs anymore
brew leaves -r                # formulae installed on request — eyeball against BrewFile
```

## 3. Stale CLI usage (atuin history cross-reference)

Run the audit script from MIGRATION.md §1c (brew leaves → each formula's real
binaries → newest atuin timestamp). Report `NEVER`/`STALE >120d` items. Apply
its caveats: libraries/build-deps and editor-invoked tools (fd, rg, pkg-config,
openssl…) look unused but aren't — mark those "indirect use, keep".

## 4. Unused GUI apps

```sh
mdls -name kMDItemLastUsedDate /Applications/*.app 2>/dev/null | paste - - | grep -v null
```

(mdls is unreliable on modern macOS — treat as a hint. The knowledgeC.db query
in MIGRATION.md §1d is better if the terminal has Full Disk Access.)
Cross-reference rarely-used apps against BrewFile casks.

## 5. Bootstrap, orphaned config & dead references

Run `mise bootstrap status --missing` with mise >= the `min_version` declared in
`mise.toml`. Report drift in static dotfiles, typed macOS defaults, and tools.
Treat `setup_sim_links.zsh` and `macos_defaults.sh` as exception-only surfaces.

- `~/.config` dirs for apps no longer installed:
  `for d in ~/.config/*/; do` … check the app still exists via
  `command -v` / `brew list` / `/Applications`. Also sort by mtime (`ls -lt ~/.config`) —
  untouched >1y is a hint.
- Home-dir dotfiles/dirs from retired tools (e.g. `~/.asdf`, `~/.doom_emacs.d`,
  `~/.tool-versions` files in projects).
- **Dead PATH entries**: `for p in ${(s/:/)PATH}; do [[ -d $p ]] || echo "MISSING: $p"; done`
  — then find which `zshenv`, `zshrc`, or `hosts/*.zsh` line adds each missing
  one.
- **Misplaced PATH entries**: flag PATH exports or path mutations in `zshrc`
  that should live in the guarded `path` array in `zshenv`. These are findings
  even if the target directory exists.
- **Shell references to absent commands**: grep `zshrc`, `zshenv`, and
  `hosts/*.zsh` for `eval "$(`, `source`, aliases, PATH/path entries, and
  exported tool vars; flag any whose underlying command/file no longer exists
  (this is what catches asdf-style residue).
- **Dangling symlinks** from `[dotfiles]` destinations and the dynamic Lazygit
  destination in `setup_sim_links.zsh`:
  `find ~ -maxdepth 3 -type l ! -exec test -e {} \; -print 2>/dev/null` (plus `~/.config`).
- Stray `*.bak` files left by the dynamic exception's conflict backup.

## 6. Optional deep scan

If `mole` is installed (`brew install mole`), offer `mole --dry-run` for app
remnants and orphaned data. Don't install it unprompted.

## Report format

Group by confidence:
- **Safe to remove** (pruned-in-repo-but-installed, dead PATH lines, dangling symlinks, .bak files)
- **Probably unused — confirm** (stale CLIs, unused apps, old config dirs)
- **Keep — looks unused but isn't** (libraries, editor-invoked tools)

Then ask which findings to act on. Apply fixes one at a time. Commit only when
requested or when the current task explicitly includes it, using one atomic
commit per logical change. Never run `brew bundle cleanup --force` or bulk
deletions in one shot.
