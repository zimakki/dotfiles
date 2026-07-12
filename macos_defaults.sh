#!/usr/bin/env zsh
#
# macOS preference exceptions. The 12 portable typed defaults are owned by
# mise.toml; this retains only currentHost and process restarts.
#   - Phase 1 (OLD Mac): capture your non-default settings into this file
#     (see MIGRATION.md → "Capture macOS settings").
#   - Phase 2 (NEW Mac): invoked by the mise bootstrap exception task.
#
# macOS has no reliable "diff from default", so this file is hand-curated.
# To find the key behind a System Settings toggle, use the before/after trick:
#
#   defaults read > /tmp/before.txt
#   # ...flip the setting in System Settings...
#   defaults read > /tmp/after.txt
#   diff /tmp/before.txt /tmp/after.txt
#
# To read a current value to paste below:  defaults read -g <key>
# (or `defaults read <domain> <key>` for an app-specific domain).

# ── Menu bar ─────────────────────────────────────────────────────────────────
# Show battery percentage next to the icon (per-host domain, so -currentHost)
defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true

# ── Add anything else below (see header for how to discover keys) ─────────────


# Apply Finder/Dock/menubar changes immediately (brief restart of each)
killall Finder Dock SystemUIServer 2>/dev/null || true
echo "Applied. A few settings may still need a logout/restart."
