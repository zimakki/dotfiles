#!/usr/bin/env zsh
# Idempotent exceptions that mise bootstrap cannot express declaratively.
set -eu
setopt pipe_fail

REPO="${0:A:h:h:h}"
source "$REPO/scripts/bootstrap/preflight.zsh"
bootstrap_require_canonical_checkout "$REPO"

global_config="${MISE_GLOBAL_CONFIG_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml}"
if [[ ! -L "$global_config" || "${global_config:A}" != "${REPO:A}/mise.toml" ]]; then
  print -u2 -- "Bootstrap exception failed: $global_config is not linked to $REPO/mise.toml"
  exit 1
fi

# The operator trusted the reviewed repository config before bootstrap. Trust
# the newly-created global link to that exact file as well.
mise trust "$global_config"

"$REPO/scripts/bootstrap/link-lazygit-config.zsh"

python3 "$REPO/scripts/bootstrap/json-overlay.py" \
  "$REPO/config/claude/settings.json" \
  "$HOME/.claude/settings.json"
python3 "$REPO/scripts/bootstrap/json-overlay.py" \
  "$REPO/config/karabiner/karabiner.json" \
  "$HOME/.config/karabiner/karabiner.json"

"$REPO/scripts/maintenance/sync-agent-skills.sh" --fix

platform="${DOTFILES_BOOTSTRAP_TEST_PLATFORM:-$OSTYPE}"
if [[ "$platform" == darwin* ]]; then
  "$REPO/scripts/bootstrap/apply-macos-exceptions.zsh"
fi

print "Manual follow-up: complete GUI approvals, imports, and sign-ins in docs/runbooks/migrate-mac.md."
