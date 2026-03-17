#!/usr/bin/env zsh
#
#In order to run this file you are going to have to give it permission to run like this:
#>> chmod +x ./setup_sim_links.zsh
#
#then you can run it like this:
#>> ./setup_sim_links.zsh

# Get the absolute path of the current directory
CURRENT_DIR=$(realpath $(dirname $0))

# Define an array of files to setup_sim_links
FILES=(
  ".zshrc"
  ".gitconfig"
  "Brewfile"
  ".gitignore_global"
)

# Iterate over the files and create the symlinks
for FILE in "${FILES[@]}"; do
  # Set the path to the target file
  TARGET_FILE="${CURRENT_DIR}/${FILE#\.}"

  # Remove the dot (.) at the start of the file name
  DESTINATION_FILE="${HOME}/${FILE}"

  # Check if the destination file already exists
  if [[ -e "${DESTINATION_FILE}" ]]; then
    # Create a backup file with the .bak extension
    BACKUP_FILE="${DESTINATION_FILE}.bak"
    mv "${DESTINATION_FILE}" "${BACKUP_FILE}"
    echo "Existing file moved to backup: ${DESTINATION_FILE} -> ${BACKUP_FILE}"
  fi

  # Create the symlink to the target file
  ln -s "${TARGET_FILE}" "${DESTINATION_FILE}"


  # Display a success message
  echo "setup_sim_links created: ${DESTINATION_FILE} -> ${TARGET_FILE}"
done

# Claude Code settings - stored in ~/.claude/
CLAUDE_DESTINATION="${HOME}/.claude/settings.json"
CLAUDE_TARGET="${CURRENT_DIR}/claude_settings.json"

echo "Setting up Claude Code config"
echo "destination: ${CLAUDE_DESTINATION}"
echo "target: ${CLAUDE_TARGET}"

# Create the .claude directory if it doesn't exist
mkdir -p "$(dirname "${CLAUDE_DESTINATION}")"

# Check if the destination file already exists
if [[ -e "${CLAUDE_DESTINATION}" ]]; then
  BACKUP_FILE="${CLAUDE_DESTINATION}.bak"
  mv "${CLAUDE_DESTINATION}" "${BACKUP_FILE}"
  echo "Existing file moved to backup: ${CLAUDE_DESTINATION} -> ${BACKUP_FILE}"
fi

# Create the symlink
ln -s "${CLAUDE_TARGET}" "${CLAUDE_DESTINATION}"
echo "Symlink created: ${CLAUDE_DESTINATION} -> ${CLAUDE_TARGET}"

# Starship prompt config - goes in ~/.config/
STARSHIP_DESTINATION="${HOME}/.config/starship.toml"
STARSHIP_TARGET="${CURRENT_DIR}/starship.toml"

echo "Setting up Starship config"
echo "destination: ${STARSHIP_DESTINATION}"
echo "target: ${STARSHIP_TARGET}"

mkdir -p "$(dirname "${STARSHIP_DESTINATION}")"

if [[ -e "${STARSHIP_DESTINATION}" ]]; then
  BACKUP_FILE="${STARSHIP_DESTINATION}.bak"
  mv "${STARSHIP_DESTINATION}" "${BACKUP_FILE}"
  echo "Existing file moved to backup: ${STARSHIP_DESTINATION} -> ${BACKUP_FILE}"
fi

ln -s "${STARSHIP_TARGET}" "${STARSHIP_DESTINATION}"
echo "Symlink created: ${STARSHIP_DESTINATION} -> ${STARSHIP_TARGET}"

# Atuin config - goes in ~/.config/atuin/
ATUIN_DESTINATION="${HOME}/.config/atuin/config.toml"
ATUIN_TARGET="${CURRENT_DIR}/atuin_config.toml"

echo "Setting up Atuin config"
echo "destination: ${ATUIN_DESTINATION}"
echo "target: ${ATUIN_TARGET}"

mkdir -p "$(dirname "${ATUIN_DESTINATION}")"

if [[ -e "${ATUIN_DESTINATION}" ]]; then
  BACKUP_FILE="${ATUIN_DESTINATION}.bak"
  mv "${ATUIN_DESTINATION}" "${BACKUP_FILE}"
  echo "Existing file moved to backup: ${ATUIN_DESTINATION} -> ${BACKUP_FILE}"
fi

ln -s "${ATUIN_TARGET}" "${ATUIN_DESTINATION}"
echo "Symlink created: ${ATUIN_DESTINATION} -> ${ATUIN_TARGET}"

# cmux/Ghostty config - goes in ~/.config/ghostty/
GHOSTTY_DESTINATION="${HOME}/.config/ghostty/config"
GHOSTTY_TARGET="${CURRENT_DIR}/ghostty_config"

echo "Setting up cmux/Ghostty config"
echo "destination: ${GHOSTTY_DESTINATION}"
echo "target: ${GHOSTTY_TARGET}"

mkdir -p "$(dirname "${GHOSTTY_DESTINATION}")"

if [[ -e "${GHOSTTY_DESTINATION}" ]]; then
  BACKUP_FILE="${GHOSTTY_DESTINATION}.bak"
  mv "${GHOSTTY_DESTINATION}" "${BACKUP_FILE}"
  echo "Existing file moved to backup: ${GHOSTTY_DESTINATION} -> ${BACKUP_FILE}"
fi

ln -s "${GHOSTTY_TARGET}" "${GHOSTTY_DESTINATION}"
echo "Symlink created: ${GHOSTTY_DESTINATION} -> ${GHOSTTY_TARGET}"

# Warp keybindings - goes in ~/.warp/
WARP_DESTINATION="${HOME}/.warp/keybindings.yaml"
WARP_TARGET="${CURRENT_DIR}/warp_keybindings.yaml"

echo "Setting up Warp keybindings"
echo "destination: ${WARP_DESTINATION}"
echo "target: ${WARP_TARGET}"

mkdir -p "$(dirname "${WARP_DESTINATION}")"

if [[ -e "${WARP_DESTINATION}" ]]; then
  BACKUP_FILE="${WARP_DESTINATION}.bak"
  mv "${WARP_DESTINATION}" "${BACKUP_FILE}"
  echo "Existing file moved to backup: ${WARP_DESTINATION} -> ${BACKUP_FILE}"
fi

ln -s "${WARP_TARGET}" "${WARP_DESTINATION}"
echo "Symlink created: ${WARP_DESTINATION} -> ${WARP_TARGET}"

# lazygit is special... and needs to be in a special place
# Get the lazygit config directory using the lazygit -cd command
LAZYGIT_CONFIG_DIR=$(lazygit -cd)
DESTINATION_FILE="${LAZYGIT_CONFIG_DIR}/config.yml"
TARGET_FILE="${CURRENT_DIR}/lazygit_config.yml"

echo "Setting up lazygit config" 
echo "destination: ${DESTINATION_FILE}" 
echo "target: ${TARGET_FILE}"

# Create the config directory if it doesn't exist
mkdir -p "$(dirname "${DESTINATION_FILE}")"

# Check if the destination file already exists
if [[ -e "${DESTINATION_FILE}" ]]; then
  # Create a backup file with the .bak extension
  BACKUP_FILE="${DESTINATION_FILE}.bak"
  mv "${DESTINATION_FILE}" "${BACKUP_FILE}"
  echo "Existing file moved to backup: ${DESTINATION_FILE} -> ${BACKUP_FILE}"
fi

# Create the symlink to the target file
ln -s "${TARGET_FILE}" "${DESTINATION_FILE}"
echo "Symlink created: ${DESTINATION_FILE} -> ${TARGET_FILE}"

