# mise: put managed-tool shims on PATH for non-interactive shells (scripts, IDEs, agents).
# Interactive shells additionally get the full `mise activate` hook from ~/.zshrc, which layers on top.
eval "$(/opt/homebrew/bin/mise activate zsh --shims)"
