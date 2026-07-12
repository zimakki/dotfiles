# dotfiles

This repo manages my macOS dotfiles, terminal/TUI app configs, shared theme
assets, and cross-agent skills. The `[dotfiles]` section of `mise.toml` is the
source of truth for static machine-linked files; `setup_sim_links.zsh` owns only
the dynamic Lazygit destination.

Managed areas currently include:

- Shell: `.zshenv`, `.zprofile`, `.zshrc`, Starship, Atuin, zsh syntax highlighting
- Terminal/TUI tools: Ghostty, Lazygit, Hunk, bat, Television, Warp keybindings/themes
- Developer tooling: Git config, global gitignore, mise global tools, Claude settings
- System/app config: Karabiner and Homebrew bundle

Not every tracked config-like artifact is symlinked. `.agents/skills/` is the
vendor-neutral source of truth for skills. `scripts/sync_agent_skills.sh --fix`
links each one into `~/.agents/skills`, `~/.claude/skills`, and
`${CODEX_HOME:-~/.codex}/skills`; the bootstrap exception task runs it automatically.
Run the script without `--fix` for a read-only lint/audit. When Hunk is
installed, the synchronizer also links its bundled `hunk-review` skill directly
from Hunk's stable Homebrew path so upgrades do not leave a stale copied skill.
`raycast.rayconfig` is a manual Raycast import artifact and should not be
symlinked.

Project instructions follow the same low-drift pattern: `AGENTS.md` is the
repo-authored source of truth for shared agent guidance, and `CLAUDE.md` is a
thin Claude Code shim that imports `@AGENTS.md`. Keep shared instructions in
`AGENTS.md` rather than duplicating them across agent-specific files.

## Fresh-machine setup

Install Xcode Command Line Tools, Homebrew, Git, and mise **2026.7.4 or newer**, then clone this repo. Prerequisites are deliberately separate; the repo never silently upgrades the live mise binary. From the checkout:

```sh
./scripts/phase2_preflight.sh
mise trust ./mise.toml
mise bootstrap --dry-run
mise bootstrap
# Bootstrap links the managed zshrc first; KEEP_ZSHRC then preserves that link.
[ -d ~/.oh-my-zsh ] || KEEP_ZSHRC=yes RUNZSH=no CHSH=no \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
[ -f ~/.oh-my-zsh/oh-my-zsh.sh ] && echo "✅ oh-my-zsh" || echo "❌ oh-my-zsh"
# bootstrap trusts the identical global config symlink during its final task
mise bootstrap status
./scripts/verify_setup.sh
```

On the first dry-run, mise may warn that the planned global config target is
not trusted yet because the symlink does not exist. The actual bootstrap creates
that link, and its final task trusts the identical reviewed config.

`mise bootstrap` is the conductor. Its pre-tools hook runs the canonical
`BrewFile` first, then installs seven pinned tools. It owns 19 static dotfile
links and 12 typed macOS defaults. The final task handles the dynamic Lazygit
destination, skill links, host-scoped battery preference, app restarts, and the
manual GUI/credential reminder. Inspect conflicts before deliberately using
`--force-dotfiles`.

The same discoverable `mise.toml` is linked globally at
`~/.config/mise/config.toml`, preserving global runtime behavior without a
second inventory. After that link exists, `mise run bootstrap` resolves the
exception script through it and works outside the checkout as well. The full
`mise bootstrap` conductor remains checkout-scoped because its Brew hook and
managed sources belong to this repository.

## Validation

Run the same portable checks as CI before committing:

```sh
scripts/ci_checks.sh
```

This checks shell syntax and common shell errors, JSON/TOML/YAML and Brewfile
syntax, the mise bootstrap ownership contract, exception manifest, and
cross-agent `SKILL.md` metadata, Codex interface metadata, and discovery. The
full `scripts/verify_setup.sh` remains the machine-level check for installed
apps, runtimes, and live dotfile links.

Migration and manual GUI details live in [`MIGRATION.md`](MIGRATION.md). The
completed incremental rollout and its recovery procedure are preserved as a
historical record in
[`docs/mise-bootstrap-rollout.md`](docs/mise-bootstrap-rollout.md).

### Theme

The terminal/TUI theme target is Catppuccin Mocha, using the Mauve accent where
an app asks for an accent choice.
