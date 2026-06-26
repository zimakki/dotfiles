[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# Cache mise env directive results (incl. fnox secret resolution) so secrets
# aren't re-fetched from 1Password on every command — avoids repeated op/Touch ID prompts.
export MISE_ENV_CACHE=1

# mise: put managed-tool shims on PATH for non-interactive shells (scripts, IDEs, agents).
# Interactive shells additionally get the full `mise activate` hook from ~/.zshrc, which layers on top.
eval "$(/opt/homebrew/bin/mise activate zsh --shims)"
