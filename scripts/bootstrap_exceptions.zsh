#!/usr/bin/env zsh
# Idempotent exceptions that mise bootstrap cannot express declaratively.
set -eu
REPO="${0:A:h:h}"

# The operator already trusted the reviewed repo config. Trust its newly-created
# global symlink too so the identical config loads outside the checkout.
mise trust "$HOME/.config/mise/config.toml"

# Lazygit's config directory is computed by the installed binary.
"$REPO/setup_sim_links.zsh"

# Host-scoped defaults and app restarts are intentionally unsupported by mise.
[[ "$OSTYPE" == darwin* ]] && "$REPO/macos_defaults.sh"

print "Manual follow-up: complete GUI approvals/imports and credential sign-ins in MIGRATION.md."
