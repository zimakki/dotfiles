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

# ── Finder ───────────────────────────────────────────────────────────────────
# Read your old-Mac values (`defaults read com.apple.finder <key>` or -g),
# then uncomment the ones you use and set them to match.
# defaults write -g AppleShowAllExtensions -bool true                  # show all file extensions
# defaults write com.apple.finder AppleShowAllFiles -bool true         # show hidden files
# defaults write com.apple.finder ShowPathbar -bool true               # path bar
# defaults write com.apple.finder ShowStatusBar -bool true             # status bar
# defaults write com.apple.finder _FXSortFoldersFirst -bool true       # folders on top
# defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"  # list view (icnv/clmv/Flwv/Nlsv)
# defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"  # search current folder

# ── Dock ─────────────────────────────────────────────────────────────────────
# Read with `defaults read com.apple.dock <key>`, then uncomment/match.
# defaults write com.apple.dock autohide -bool true
# defaults write com.apple.dock autohide-delay -float 0
# defaults write com.apple.dock autohide-time-modifier -float 0.2
# defaults write com.apple.dock tilesize -int 48
# defaults write com.apple.dock magnification -bool false
# defaults write com.apple.dock show-recents -bool false
# defaults write com.apple.dock mineffect -string "scale"              # genie/scale/suck
# defaults write com.apple.dock orientation -string "bottom"           # left/right/bottom

# ── Add anything else below (see header for how to discover keys) ─────────────


# Apply Finder/Dock/menubar changes immediately (brief restart of each)
killall Finder Dock SystemUIServer 2>/dev/null || true
echo "Applied. A few settings may still need a logout/restart."
