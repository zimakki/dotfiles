#!/usr/bin/env zsh
#
# Dotfile symlink installer
#
# Usage:
#   chmod +x ./setup_sim_links.zsh
#   ./setup_sim_links.zsh

DOTFILES="$(realpath "$(dirname "$0")")"

# ─── Manifest: source_in_repo : destination ────────────────────────
LINKS=(
  "zshrc:~/.zshrc"
  "gitconfig:~/.gitconfig"
  "BrewFile:~/Brewfile"
  "gitignore_global:~/.gitignore_global"
  "claude_settings.json:~/.claude/settings.json"
  "starship.toml:~/.config/starship.toml"
  "atuin_config.toml:~/.config/atuin/config.toml"
  "television:~/.config/television"
  "ghostty_config:~/.config/ghostty/config"
  "warp_keybindings.yaml:~/.warp/keybindings.yaml"
  "lazygit_config.yml:$(lazygit -cd)/config.yml"
  "bat_config:~/.config/bat/config"
)

# ─── Logic ─────────────────────────────────────────────────────────
link() {
  local src="$DOTFILES/$1" dest="${2/#\~/$HOME}"
  [[ ! -e "$src" ]] && echo "  SKIP $1 (not found)" && return 1
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    rm -rf "$dest.bak"
    mv "$dest" "$dest.bak"
    echo "  backed up $dest"
  fi
  ln -s "$src" "$dest"
  echo "  ✓ $dest → $src"
}

echo "Setting up dotfile symlinks..."
for entry in "${LINKS[@]}"; do
  link "${entry%%:*}" "${entry#*:}"
done
echo "Done."
