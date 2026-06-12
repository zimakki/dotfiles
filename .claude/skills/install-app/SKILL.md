---
name: install-app
description: Install a new application or tool through the dotfiles repo — pick the right channel (brew cask/formula, mise runtime, mas, npm -g), record it in the BrewFile or mise_config.toml, install it, and capture+symlink any config it creates. Use when the user asks to install, add, or set up an app or CLI tool.
---

# Install an app via the dotfiles repo

The dotfiles repo is the single entry point for machine setup. Nothing gets
installed ad-hoc: every install is recorded here first, so a new machine
reproduces it and `git log` explains it.

Input: an app/tool name (and optionally a URL). If no argument given, ask what
to install.

## 1. Pick the channel

In priority order:

1. **Language runtime** (node, python, elixir, erlang, ruby, go…) → **mise**,
   never brew. Add to `mise_config.toml` under `[tools]`, then `mise install`.
2. **GUI app** → `brew search --cask <name>`. If found: `cask "<token>"`.
3. **CLI tool** → `brew search <name>` / `brew info <name>`. If found: `brew "<token>"`.
4. **Mac App Store only** → `mas search "<name>"`. Add `mas "<App Name>", id: NNNN`
   to the BrewFile. If `brew "mas"` isn't in the BrewFile yet, add it (above the
   casks) and install it first.
5. **npm global** (rare — prefer per-project) → confirm with the user it really
   needs to be global, then `npm i -g` and note it in MIGRATION.md §1e.
6. **Nothing found** → check the project's website/docs (WebFetch) for a brew tap
   or alternate cask token. If it's truly manual-install-only, say so and add a
   commented line to the BrewFile as a record: `# cask "<name>" — not on brew, manual install from <url>`.

If the name is ambiguous (multiple plausible tokens), show `brew info` for the
candidates and ask.

## 2. Record, then install

1. Edit the **BrewFile** (note: capital F, `BrewFile` not `Brewfile`): add the
   line in alphabetical position within its section (formulae first, then casks).
2. Install: `brew install [--cask] <token>` (or `mise install` / `mas install <id>`).
3. Verify: `command -v <bin>` for CLIs, or `ls /Applications | grep -i <name>`
   for casks.

## 3. Capture config (the part that's easy to forget)

After install (and ideally after the user has launched/configured the app once),
look for config the app writes:

```sh
ls -d ~/.config/<app>* 2>/dev/null
ls -d ~/Library/Application\ Support/<App>* 2>/dev/null
ls ~/Library/Preferences/ | grep -i <app>
ls ~/.<app>* 2>/dev/null
```

Decide with the user what's worth tracking:

- **Plain-text config you'd edit by hand** (toml/yaml/json/lua) → copy into the
  repo root (follow existing naming: `<app>_config.toml`, `<app>.json`, or a
  directory like `television/`), add an entry to the `LINKS` array in
  `setup_sim_links.zsh` (`"<repo-file>:~/.config/<app>/<file>"`), then run
  `./setup_sim_links.zsh` (it backs up replaced files to `*.bak`).
- **Binary plists / app-managed state** → don't symlink. If the app has its own
  export (like Raycast's `.rayconfig`), note that in MIGRATION.md instead.
- **Anything containing secrets/tokens** → NEVER commit. Point the user at
  `~/.zsh_secrets` / 1Password instead.
- **macOS `defaults` the app needs** → add to `macos_defaults.sh`.

If the app needs shell init (an `eval "$(<tool> init zsh)"`, PATH entry, alias),
add it to `zshrc` — keeping zsh-syntax-highlighting as the LAST sourced line.

## 4. Commit

Commit straight to master and push (the user's standing policy):

```sh
git add <changed files>
git commit -m "Add <app> (<one-line purpose>)"
git push
```

One commit per app. Report what was installed, what config was captured, and
anything left manual (first-launch permissions, sign-in, etc.).
