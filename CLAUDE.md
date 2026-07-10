# Dotfiles Repo Guidance

This repo is the single entry point for machine setup. Installs are recorded in
`BrewFile`, `mise_config.toml`, tracked config files, and symlinks managed by
`setup_sim_links.zsh`.

Normal app/tool changes should use the project-local skills:

- `.claude/skills/install-app/SKILL.md`
- `.claude/skills/uninstall-app/SKILL.md`
- `.claude/skills/cleanup-report/SKILL.md`

Migration and machine setup notes live in `MIGRATION.md`.

Shell config rule: environment belongs in `zshenv`; interactive behavior belongs
in `zshrc`. Before editing `zshenv`, `zshrc`, `hosts/*.zsh`, PATH, shell init
hooks, or installing a tool, read `docs/conventions/shell-config.md`.
