#!/usr/bin/env zsh
#
# Legacy exception installer. Static links are owned by mise.toml [dotfiles].
#
# Invoked by scripts/bootstrap_exceptions.zsh after Brew installs lazygit.
set -eu

DOTFILES="$(realpath "$(dirname "$0")")"

# ─── Manifest: source_in_repo : destination ────────────────────────
LINKS=(
  "lazygit_config.yml:$(lazygit -cd)/config.yml"
)

# ─── Logic ─────────────────────────────────────────────────────────
link() {
  local src="$DOTFILES/$1" dest="${2/#\~/$HOME}"
  [[ ! -e "$src" ]] && echo "  SKIP $1 (not found)" && return 1
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" && "${dest:A}" == "${src:A}" ]]; then
    echo "  ✓ $dest already linked"
    return 0
  fi
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
echo "Syncing cross-agent skills..."
"$DOTFILES/scripts/sync_agent_skills.sh" --fix
echo "Done."
