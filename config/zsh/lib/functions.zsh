# Interactive helper functions.

gci() {
  local branch
  branch="$(git branch --all | fzf | sed 's#remotes/origin/##')"
  [[ -n "$branch" ]] || return 1
  git checkout "$branch"
}

diff_files() {
  local file1 file2
  file1="$(git ls-tree -r --name-only HEAD | fzf --prompt='Select first file: ')"
  [[ -n "$file1" ]] || { print "No file selected!"; return 1; }

  file2="$(git ls-tree -r --name-only HEAD | fzf --prompt='Select second file: ')"
  [[ -n "$file2" ]] || { print "No file selected!"; return 1; }

  diff -u "$file1" "$file2" | delta
}

git_with_diff() {
  if [[ "$1" == status ]]; then
    shift
    command git status "$@" && command git diff
  else
    command git "$@"
  fi
}

tre() {
  command tre "$@" -e && source "/tmp/tre_aliases_$USER" 2>/dev/null
}

delete_nvim_cache() {
  local dir
  for dir in "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
    print "deleting $dir"
    rm -rf "$dir"
  done
}
