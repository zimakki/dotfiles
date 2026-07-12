---
name: install-app
description: Install a new application or tool through the dotfiles repo — pick the right channel, record it in BrewFile or mise.toml, install it, and capture any managed config. Use when the user asks to install, add, or set up an app or CLI tool.
---

# Install an app via the dotfiles repo

The dotfiles repo is the single entry point for machine setup. Record automated
installs here before applying them so a new machine reproduces them and `git
log` explains them. Explicitly document rare manual or npm-global exceptions;
do not imply that a comment installs software.

Before touching shell config, PATH, or installer shell snippets, read
`docs/conventions/shell-config.md`.

Input: an app/tool name (and optionally a URL). If no argument given, ask what
to install.

## 1. Pick the channel

In priority order:

1. **Language runtime** (node, python, elixir, erlang, ruby, go…) → **mise**,
   never brew. Add a pinned version to `mise.toml` under `[tools]`, confirm the
   installed mise satisfies `min_version`, then run `mise bootstrap --only
   tools` so the BrewFile pre-tools hook preserves the required build order.
2. **GUI app** → `brew search --cask <name>`. If found: `cask "<token>"`.
3. **CLI tool** → `brew search <name>` / `brew info <name>`. If found: `brew "<token>"`.
4. **Mac App Store only** → `mas search "<name>"`. Add `mas "<App Name>", id: NNNN`
   to the BrewFile. If `brew "mas"` isn't in the BrewFile yet, add it (above the
   casks) and install it first.
5. **npm global** (rare — prefer per-project) → confirm with the user it really
   needs to be global, then `npm i -g` and note it in MIGRATION.md §1e.
6. **Nothing found** → check the project's official website/docs for a brew tap
   or alternate cask token. Record a custom `tap "owner/repo"` and use the fully
   qualified `owner/repo/token` so fresh-machine preflight can recognize it
   before the tap is installed. If it's truly manual-install-only, say so and
   add a commented line to the BrewFile as a record: `# cask "<name>" — not on
   brew, manual install from <url>`.

If the name is ambiguous (multiple plausible tokens), show `brew info` for the
candidates and ask.

## 2. Record, then install

1. Edit the **BrewFile** (note: capital F, `BrewFile` not `Brewfile`): add the
   line in alphabetical position within its section (formulae first, then casks).
2. Install: `brew install [--cask] <token>` (or `mise bootstrap --only tools` /
   `mas install <id>`).
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
  directory like `television/`) and add a static symlink entry under
  `[dotfiles]` in `mise.toml`. Preview with `mise bootstrap --dry-run --only
  dotfiles`; do not use `--force-dotfiles` without reviewing conflicts.
- **Binary plists / app-managed state** → don't symlink. If the app has its own
  export (like Raycast's `.rayconfig`), note that in MIGRATION.md instead.
- **Anything containing secrets/tokens** → NEVER commit. Point the user at
  `~/.zsh_secrets` / 1Password instead.
- **macOS `defaults` the app needs** → add typed values under
  `[bootstrap.macos.*]` in `mise.toml` when supported. Reserve
  `macos_defaults.sh` for unsupported `-currentHost` writes and app restarts.

If the app needs shell init, split the installer snippet by what each line does:

- A bin directory belongs in the guarded `path` array in `zshenv`, with an
  existence guard. Do not add PATH entries to `zshrc`. If the tool is
  mise-managed, no PATH entry is needed because the shim covers it.
- A shell init hook, completion, prompt widget, alias, or interactive function
  belongs in `zshrc`. Guard terminal UI setup with `[[ -t 1 ]]`.
- A non-secret exported env var needed by scripts, IDEs, agents, or commands
  belongs in `zshenv`.
- Deliberate machine-specific environment belongs in
  `hosts/<LocalHostName>.zsh`.

Keep zsh-syntax-highlighting as the LAST sourced line among interactive widgets.
If the highlighting colors change, update
`zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh`; it is symlinked to
`~/.zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh` and sourced immediately
before the Homebrew zsh-syntax-highlighting plugin.

Project-local shared skills live in `.agents/skills/` in this repo. Do not add
separate repo-owned copies under client-specific directories; `~/.agents/skills`,
`~/.claude/skills`, and `${CODEX_HOME:-~/.codex}/skills` are synchronized from
the canonical tree by `scripts/sync_agent_skills.sh`.

## 4. Validate and hand off

Run the portable checks and inspect the bootstrap preview:

```sh
scripts/ci_checks.sh
mise bootstrap --dry-run
```

When the change alters the number of tools, dotfiles, typed defaults, dynamic
links, or exception writes, update the corresponding ownership assertions in
`scripts/test_bootstrap_config.py` and any exact counts or version lists in
`README.md` and `MIGRATION.md` before running CI.

Commit or push only when requested or when the current task explicitly includes
that workflow. Prefer one atomic commit per app. Report what was installed,
what config was captured, and anything left manual.
