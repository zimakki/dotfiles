# dotfiles

This repo manages my macOS dotfiles, terminal/TUI app configs, shared theme
assets, and cross-agent skills. The symlink manifest in
`setup_sim_links.zsh` is the source of truth for machine-linked files.

Managed areas currently include:

- Shell: `.zshenv`, `.zshrc`, Starship, Atuin, zsh syntax highlighting
- Terminal/TUI tools: Ghostty, Lazygit, Hunk, bat, Television, Warp keybindings/themes
- Developer tooling: Git config, global gitignore, mise global tools, Claude settings
- System/app config: Karabiner and Homebrew bundle

Not every tracked config-like artifact is symlinked. `.agents/skills/` is the
vendor-neutral source of truth for skills. `scripts/sync_agent_skills.sh --fix`
links each one into `~/.agents/skills`, `~/.claude/skills`, and
`${CODEX_HOME:-~/.codex}/skills`; `setup_sim_links.zsh` runs it automatically.
Run the script without `--fix` for a read-only lint/audit. When Hunk is
installed, the synchronizer also links its bundled `hunk-review` skill directly
from Hunk's stable Homebrew path so upgrades do not leave a stale copied skill.
`raycast.rayconfig` is a manual Raycast import artifact and should not be
symlinked.

Project instructions follow the same low-drift pattern: `AGENTS.md` is the
repo-authored source of truth for shared agent guidance, and `CLAUDE.md` is a
thin Claude Code shim that imports `@AGENTS.md`. Keep shared instructions in
`AGENTS.md` rather than duplicating them across agent-specific files.

## Get up and running

> note: I have not run this on a new computer so I imagine I will have to install everything I need before I am really able to use this file.

I'm currently running [AstroVim](https://astronvim.com/) and you can find the astro vim config here: [AstroNvim](https://github.com/zimakki/AstroNvim)

### 1. Install all the brew stuff

Run the below command from the root of this folder:
`brew bundle install`

## Validation

Run the same portable checks as CI before committing:

```sh
scripts/ci_checks.sh
```

This checks shell syntax and common shell errors, JSON/TOML/YAML and Brewfile
syntax, the symlink manifest, and cross-agent skill metadata and discovery. The
full `scripts/verify_setup.sh` remains the machine-level check for installed
apps, runtimes, and live dotfile links.

### 2. Sim links

To run `setup_sim_links.zsh`:

- make sure you give the file permissions:
  `chmod +x ./setup_sim_links.zsh`
- run it!:
  `./setup_sim_links.zsh`

### Theme

The terminal/TUI theme target is Catppuccin Mocha, using the Mauve accent where
an app asks for an accent choice.
