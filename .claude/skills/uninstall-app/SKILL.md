---
name: uninstall-app
description: Cleanly remove an application or tool — uninstall it, update the BrewFile/mise config, remove symlink entries and zshrc references, and sweep leftover config/cache directories. Use when the user wants to uninstall, remove, or stop using an app.
---

# Uninstall an app via the dotfiles repo

Removal is the mirror of install: the machine AND the repo both change, and the
repo records *why* (prune-by-commenting, per BrewFile convention).

Before touching shell config or PATH cleanup, read
`docs/conventions/shell-config.md`.

Input: an app/tool name. Confirm the exact BrewFile token before acting.

## 1. Find every trace first (read-only)

```sh
grep -in "<app>" BrewFile mise_config.toml setup_sim_links.zsh zshenv zshrc hosts/*.zsh macos_defaults.sh MIGRATION.md
brew list | grep -i <app>; brew list --cask | grep -i <app>
ls -d ~/.config/<app>* ~/Library/Application\ Support/<App>* ~/.<app>* 2>/dev/null
ls ~/Library/Preferences/ | grep -i <app>
ls ~/Library/LaunchAgents/ | grep -i <app>
```

Also check whether anything else depends on it: `brew uses --installed <formula>`.
If there are dependents, stop and discuss.

Present the full list of what will be touched and get a confirmation —
uninstalls are destructive.

## 2. Uninstall

- brew formula/cask: `brew uninstall [--cask] <token>`. For casks, prefer
  `brew uninstall --zap --cask <token>` if the user wants config/caches gone too
  (show what zap would remove first: `brew info --cask <token>` stanza).
- mise runtime: remove from `mise_config.toml`, then `mise prune`.
- mas app: `mas uninstall <id>` (may need `sudo`) or drag-to-trash; remove the
  `mas` line from the BrewFile.
- Afterwards: `brew autoremove` to drop now-orphaned dependencies (show the list).

## 3. Update the repo

1. **BrewFile**: comment the line out with a reason and date rather than deleting —
   `# brew "<token>"  # removed 2026-06: <reason>` — matching the existing
   pruned-entry style. Delete outright only if the user says it was a mistake to
   ever have it.
2. **setup_sim_links.zsh**: remove the `LINKS` entry. Remove the now-dangling
   symlink in `$HOME` (`rm` the link only, not repo content).
3. **Repo config files**: `git rm` the app's tracked config (it stays in history).
4. **Shell config**: remove aliases, `eval` init lines, completions, and other
   interactive behavior from `zshrc`; remove the tool's PATH entry from the
   guarded `path` array in `zshenv`; remove deliberate machine-specific entries
   from matching `hosts/*.zsh` files.
5. **macos_defaults.sh / MIGRATION.md**: remove or annotate related lines.

## 4. Sweep leftovers on disk

Offer to delete (ask per item, never blanket-delete):

```sh
~/.config/<app>/   ~/Library/Application Support/<App>/
~/Library/Preferences/<bundle-id>.plist   ~/Library/Caches/<bundle-id>/
~/Library/LaunchAgents/<bundle-id>*.plist
```

## 5. Commit

```sh
git add -A && git commit -m "Remove <app>: <reason>" && git push
```

Report: what was uninstalled, what was kept (and why), and any follow-ups
(e.g. revoke an API key the app held).
