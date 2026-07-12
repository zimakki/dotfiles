---
name: uninstall-app
description: Cleanly remove an application or tool — uninstall it, update BrewFile or mise.toml, remove managed dotfiles and shell references, and sweep leftover config/cache directories. Use when the user wants to uninstall, remove, or stop using an app.
---

# Uninstall an app via the dotfiles repo

Treat removal as a coordinated machine and repository change. Before changing
shell config or PATH, read `docs/conventions/shell-config.md`.

Ask for the app or tool name when missing. Confirm the exact package token and
show the complete removal set before performing destructive actions.

## 1. Find every trace

Search the canonical manifests, app-oriented config, bootstrap exceptions,
shell config, and current docs:

```sh
rg -n -i '<app>' \
  BrewFile mise.toml config scripts/bootstrap docs .agents/skills
brew list | rg -i '<app>'
brew list --cask | rg -i '<app>'
ls -d ~/.config/<app>* ~/Library/Application\ Support/<App>* ~/.<app>* 2>/dev/null
ls ~/Library/Preferences/ ~/Library/LaunchAgents/ 2>/dev/null | rg -i '<app>'
```

Run `brew uses --installed <formula>` for a formula. Stop and discuss installed
dependents before uninstalling it.

## 2. Uninstall deliberately

- For Homebrew, use `brew uninstall [--cask] <token>`. Offer `--zap` only after
  showing the cask's zap stanza and confirming the user wants its data removed.
- For mise, remove the declaration, preview unused versions with `mise prune
  --dry-run`, then preview the exact version with `mise uninstall --dry-run`
  before uninstalling it.
- For Mac App Store apps, remove the manifest entry and uninstall by ID when
  supported.
- Show `brew autoremove --dry-run` afterward. Run the real autoremove only after
  the user approves that exact list.

## 3. Update the repository

1. Delete the inactive entry from `BrewFile`; it is an inventory, not a removal
   log. Put a durable rationale in an ADR only when future maintainers need it,
   and otherwise let the commit explain the change. Remove an unused
   third-party tap when appropriate.
2. Remove the app's `[dotfiles]` entry and its canonical `config/<app>/`
   content. If it uses a JSON overlay, remove its apply and verification calls
   instead; preserve the app-owned live file unless the user separately asks
   to delete it. Treat any root compatibility symlink as transitional; remove
   it with the app rather than turning it back into a source file.
3. Identify the old live destination explicitly. Mise does not infer that a
   now-undeclared symlink should be deleted, so ask before removing it from
   `$HOME`.
4. Remove interactive behavior from `config/zsh/zshrc` and the matching
   `config/zsh/lib/` module, PATH and shared environment from
   `config/zsh/zshenv`, and deliberate machine-only entries from
   `config/zsh/hosts/*.zsh`.
5. Remove supported macOS settings from `[bootstrap.macos.*]`. Touch
   `scripts/bootstrap/apply-macos-exceptions.zsh` only for an actual exception.
   Removing a declaration does not restore the old live preference; never
   guess its previous value.
6. Update current docs and bootstrap tests when their contract changes. Do not
   preserve completed rollout notes as a substitute for current guidance.

For mutable app config, remove only managed overlay keys unless the user asks to
remove all app state. Do not discard app-written Claude or Karabiner keys merely
because a managed source exists.

## 4. Sweep leftovers

Offer each path separately; never blanket-delete:

```text
~/.config/<app>/
~/Library/Application Support/<App>/
~/Library/Preferences/<bundle-id>.plist
~/Library/Caches/<bundle-id>/
~/Library/LaunchAgents/<bundle-id>*.plist
```

## 5. Validate and hand off

Run the repository checks from any checkout:

```sh
scripts/ci_checks.sh
```

Run the machine preview only from the canonical checkout:

```sh
scripts/bootstrap/preflight.zsh
mise bootstrap --dry-run
```

Update derived assertions under `tests/bootstrap/` when ownership changes.
Commit or push only when requested or explicitly included in the task. Report
what was removed, what was retained and why, and follow-ups such as credential
revocation.
