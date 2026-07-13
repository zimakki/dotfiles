# Dotfiles Repo Guidance

This repo uses `AGENTS.md` as the shared source of truth for project
instructions across coding agents. `CLAUDE.md` is only a Claude Code
compatibility shim that imports this file.

This repo is the single entry point for machine setup. `mise bootstrap` is the
front door and coordinator. `BrewFile` is the sole Homebrew package/cask
inventory; the discoverable `mise.toml` owns mise tools, static dotfile links,
and typed macOS defaults.

Canonical app configuration belongs under `config/<app>/`; do not add
root-level config files. When adding or removing stable managed config, update
`[dotfiles]` in `mise.toml`.

Claude and Karabiner are app-mutated files and are not `[dotfiles]` entries.
Their repository-owned JSON overlays merge recursively into live regular files;
live keys absent from an overlay are preserved, while managed lists and scalar
values replace their counterparts. Keep opaque exports, generated state,
caches, automatic backups, and secrets outside Git.

Bootstrap exceptions are narrow and live under `scripts/bootstrap/`:

- `link-lazygit-config.zsh` resolves Lazygit's dynamic destination.
- `relink-static-config.py` removes transitional root-link dependencies after
  mise applies static dotfiles.
- `apply-macos-exceptions.zsh` handles unsupported host-scoped writes and
  necessary app restarts.
- `json-overlay.py` safely applies managed fragments to app-owned JSON files.
- `exceptions.zsh` coordinates exceptions; it is not another manifest.

Normal app/tool changes should use the project-local, cross-agent skills:

- `.agents/skills/install-app/SKILL.md`
- `.agents/skills/uninstall-app/SKILL.md`
- `.agents/skills/cleanup-report/SKILL.md`
- `.agents/skills/dotfiles-skill-linter/SKILL.md`

Current architecture and setup guidance lives in `docs/`; start with
`docs/README.md`. Before changing bootstrap behavior, read
`docs/decisions/0002-safe-bootstrap.md`. Never apply bootstrap from a
secondary worktree.

When adding a supported macOS preference, update `[bootstrap.macos.*]`; reserve
the exception script for behavior mise cannot express.

Shell config rule: environment belongs in `config/zsh/zshenv`; interactive
behavior belongs in `config/zsh/zshrc`; `config/zsh/zprofile` only repairs
login-shell ordering. Reusable aliases, functions, and secret-cache behavior
live under `config/zsh/lib/`. Before editing those files,
`config/zsh/hosts/*.zsh`, PATH, shell init hooks, or installing a tool, read
`docs/conventions/shell-config.md`.
