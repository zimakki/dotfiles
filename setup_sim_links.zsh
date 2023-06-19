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
