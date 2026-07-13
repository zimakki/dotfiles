# Managed configuration

Application-owned source files live under `config/<app>/`. Static sources are
mapped to their home-directory destinations by `mise.toml`; mutable sources are
applied by the narrow overlay workflow described below.

There are two ownership modes:

- **Static text** is symlinked by mise. Examples: Atuin, Ghostty, Hunk,
  Starship, Television, Warp, and Zsh.
- **Application-mutated JSON** is overlaid by the bootstrap exception task.
  Claude and Karabiner receive repo-managed keys while retaining unmanaged
  application state; they are deliberately absent from `[dotfiles]`.

Theme files stay with their application because every consumer uses a different
schema even when the shared visual target is Catppuccin Mocha/Mauve.

Root-level app config is not supported. Add stable sources under
`config/<app>/` and declare their destinations in `[dotfiles]` in `mise.toml`.
