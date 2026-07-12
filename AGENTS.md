# Dotfiles Repo Guidance

This repo uses `AGENTS.md` as the shared source of truth for project
instructions across coding agents. `CLAUDE.md` exists only as a Claude Code
compatibility shim that imports this file.

This repo is the single entry point for machine setup. `mise bootstrap` is the
front door and coordinator. `BrewFile` is the sole Homebrew package/cask
inventory; the discoverable `mise.toml` owns mise tools, static dotfile links,
and typed macOS defaults. `setup_sim_links.zsh` and `macos_defaults.sh` are
exception-only helpers invoked by bootstrap, not general manifests.

Normal app/tool changes should use the project-local, cross-agent skills:

- `.agents/skills/install-app/SKILL.md`
- `.agents/skills/uninstall-app/SKILL.md`
- `.agents/skills/cleanup-report/SKILL.md`
- `.agents/skills/dotfiles-skill-linter/SKILL.md`

Migration and machine setup notes live in `MIGRATION.md`.

When adding or removing managed config, update `[dotfiles]` in `mise.toml`.
When adding a supported macOS preference, update `[bootstrap.macos.*]`; reserve
`macos_defaults.sh` for unsupported host-scoped writes and app restarts.

Shell config rule: environment belongs in `zshenv`; interactive behavior belongs
in `zshrc`. Before editing `zshenv`, `zshrc`, `hosts/*.zsh`, PATH, shell init
hooks, or installing a tool, read `docs/conventions/shell-config.md`.
