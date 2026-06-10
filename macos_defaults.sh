#!/usr/bin/env zsh
#
# macOS system preferences.
#   - Phase 1 (OLD Mac): capture your non-default settings into this file
#     (see MIGRATION.md → "Capture macOS settings").
#   - Phase 2 (NEW Mac): apply them once with:  ./macos_defaults.sh
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

# ── Keyboard ─────────────────────────────────────────────────────────────────
# (relocated here from zshrc, where they re-ran on every shell launch)
defaults write -g InitialKeyRepeat -int 10   # delay before repeat (System Settings min = 15)
defaults write -g KeyRepeat        -int 1    # repeat rate (System Settings min = 2)

# Use F1/F2/… as standard function keys. Verify your value on the old Mac with
#   defaults read -g com.apple.keyboard.fnState
# then uncomment with the correct bool:
# defaults write -g com.apple.keyboard.fnState -bool true

# ── Add more captured settings below (see header for how to discover keys) ────


echo "Applied. Some settings need a logout, or: killall SystemUIServer Dock Finder"
