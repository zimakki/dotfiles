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

Root-level config names are temporary compatibility symlinks. Existing static
HOME links can reach the new source through them; the bootstrap exception task
then rewrites those HOME links to point directly into `config/`, and verification
rejects any remaining indirect first hop.

Claude and Karabiner are a special one-time cutover. Their root compatibility
links point to `settings.legacy.json` and `karabiner.legacy.json`, respectively,
not to the managed overlays. This preserves pre-cutover app state until the
overlay task materializes each HOME target as a regular file. The Claude legacy
snapshot intentionally omits the dead `statusLine` command while retaining the
volatile `feedbackSurveyState` key.

Keep all compatibility links and legacy snapshots until every machine has run
bootstrap and passed verification. Remove them together in a follow-up cleanup;
they are migration anchors, not authoring locations.
