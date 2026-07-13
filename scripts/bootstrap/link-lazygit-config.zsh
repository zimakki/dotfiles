#!/usr/bin/env zsh
# Lazygit chooses a platform-specific config directory at runtime, so mise's
# static dotfile map cannot own this one link.
set -eu
setopt pipe_fail

REPO="${0:A:h:h:h}"
source "$REPO/scripts/bootstrap/preflight.zsh"

mode=refuse
check=false
while (( $# > 0 )); do
  case "$1" in
    --backup) mode=backup ;;
    --force) mode=force ;;
    --check) check=true ;;
    -h|--help)
      print "usage: $0 [--check | --backup | --force]"
      exit 0
      ;;
    *)
      print -u2 -- "unknown argument: $1"
      exit 2
      ;;
  esac
  shift
done
if $check && [[ "$mode" != refuse ]]; then
  print -u2 -- "--check cannot be combined with --backup or --force"
  exit 2
fi

command -v lazygit >/dev/null 2>&1 || {
  print -u2 -- "Lazygit config link failed: lazygit is not installed."
  exit 1
}

config_dir="$(lazygit -cd)" || {
  print -u2 -- "Lazygit config link failed: 'lazygit -cd' returned an error."
  exit 1
}
if [[ -z "$config_dir" || "$config_dir" == *$'\n'* || "$config_dir" != /* ]]; then
  print -u2 -- "Lazygit config link failed: 'lazygit -cd' must return one absolute path."
  exit 1
fi

home_real="${HOME:A}"
config_dir_real="${config_dir:A}"
if [[ "$config_dir_real" != "$home_real"/* ]]; then
  print -u2 -- "Lazygit config link failed: config directory is outside HOME: $config_dir"
  exit 1
fi

source_file="$REPO/config/lazygit/config.yml"
dest="$config_dir/config.yml"
[[ -f "$source_file" ]] || {
  print -u2 -- "Lazygit config link failed: missing source $source_file"
  exit 1
}

first_link_hop() {
  local link="$1" link_text candidate
  link_text="$(readlink "$link")" || return 1
  if [[ "$link_text" == /* ]]; then
    candidate="$link_text"
  else
    candidate="${link:h}/$link_text"
  fi
  print -r -- "${candidate:a}"
}

if [[ -L "$dest" ]]; then
  first_hop="$(first_link_hop "$dest")"
  if [[ "$first_hop" == "${source_file:a}" ]]; then
    print "Lazygit config is directly linked: $dest"
    exit 0
  fi
fi

if $check; then
  print -u2 -- "Lazygit config drift: $dest is not linked to $source_file"
  exit 1
fi

bootstrap_require_canonical_checkout "$REPO"
mkdir -p "$config_dir"

if [[ -e "$dest" || -L "$dest" ]]; then
  case "$mode" in
    refuse)
      print -u2 -- "Lazygit config conflict: $dest already exists and was preserved."
      print -u2 -- "Re-run with --backup to keep a timestamped copy, or --force to replace a file/symlink."
      exit 1
      ;;
    backup)
      stamp="$(date -u +%Y%m%dT%H%M%SZ)"
      backup="$dest.bak.$stamp"
      suffix=0
      while [[ -e "$backup" || -L "$backup" ]]; do
        (( suffix += 1 ))
        backup="$dest.bak.$stamp.$suffix"
      done
      mv "$dest" "$backup"
      print "Backed up Lazygit config to $backup"
      ;;
    force)
      if [[ -d "$dest" && ! -L "$dest" ]]; then
        print -u2 -- "Lazygit config conflict is a directory; refusing recursive deletion: $dest"
        exit 1
      fi
      rm -- "$dest"
      print "Removed conflicting Lazygit config: $dest"
      ;;
  esac
fi

ln -s "$source_file" "$dest"
print "Linked Lazygit config: $dest -> $source_file"
