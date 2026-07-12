#!/usr/bin/env zsh
# Readiness checks for a fresh Mac, plus the mutation guard shared by every
# bootstrap exception. Source this file to call
# bootstrap_require_canonical_checkout; execute it for the full preflight.

bootstrap_require_canonical_checkout() {
  local repo="${1:-${0:A:h:h:h}}"
  local git_dir common_dir_raw common_dir

  repo="$(cd "$repo" && pwd -P)" || return 1
  if ! git_dir="$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null)"; then
    print -u2 -- "Bootstrap refused: $repo is not a Git checkout."
    return 1
  fi
  common_dir_raw="$(git -C "$repo" rev-parse --git-common-dir)" || return 1
  common_dir="$(cd "$repo" && cd "$common_dir_raw" && pwd -P)" || return 1
  git_dir="$(cd "$git_dir" && pwd -P)" || return 1

  if [[ "$git_dir" == "$common_dir" ]]; then
    return 0
  fi

  if [[ "${DOTFILES_BOOTSTRAP_TEST_ALLOW_WORKTREE:-0}" == 1 ]]; then
    print -u2 -- "TEST ONLY: allowing bootstrap mutation from linked worktree $repo"
    return 0
  fi

  print -u2 -- "Bootstrap refused: $repo is a linked/secondary Git worktree."
  print -u2 -- "Run bootstrap from the canonical checkout whose .git directory is: $common_dir"
  print -u2 -- "This prevents HOME symlinks from pointing into an ephemeral worktree."
  return 1
}

bootstrap_preflight_main() {
  set -u
  setopt pipe_fail

  local repo="${0:A:h:h:h}"
  if [[ "${1:-}" == "--guard-only" ]]; then
    (( $# <= 2 )) || {
      print -u2 -- "usage: $0 --guard-only [repo]"
      return 2
    }
    bootstrap_require_canonical_checkout "${2:-$repo}"
    return
  elif (( $# > 0 )); then
    print -u2 -- "usage: $0 [--guard-only [repo]]"
    return 2
  fi

  local brewfile="$repo/BrewFile"
  local blockers=0 warns=0
  local minimum mise_version free_g

  ok()   { print "  ✅ $1" }
  bad()  { print "  ❌ $1"; (( blockers += 1 )) }
  warn() { print "  ⚠️  $1"; (( warns += 1 )) }
  hdr()  { print "\n== $1 ==" }

  hdr "Repo safety"
  if bootstrap_require_canonical_checkout "$repo"; then
    ok "canonical checkout (safe source for HOME links)"
  else
    bad "linked worktrees must not mutate bootstrap state"
  fi
  if git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    ok "git branch: $(git -C "$repo" rev-parse --abbrev-ref HEAD)"
    [[ -z "$(git -C "$repo" status --porcelain)" ]] \
      && ok "working tree clean" \
      || warn "uncommitted changes in working tree"
    local divergence
    divergence="$(git -C "$repo" rev-list --left-right --count HEAD...@{u} 2>/dev/null || print '?')"
    [[ "$divergence" == $'0\t0' ]] \
      && ok "in sync with the locally known upstream ref" \
      || warn "upstream divergence is $divergence (run git fetch to refresh it)"
  else
    bad "not a Git repository at $repo"
  fi

  hdr "Toolchain"
  xcode-select -p >/dev/null 2>&1 \
    && ok "Xcode Command Line Tools present" \
    || bad "Xcode Command Line Tools missing: xcode-select --install"
  command -v brew >/dev/null 2>&1 \
    && ok "Homebrew: $(brew --version | head -1)" \
    || bad "Homebrew missing"
  minimum="$(sed -n 's/^min_version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$repo/mise.toml" | head -1)"
  if command -v mise >/dev/null 2>&1; then
    mise_version="$(mise --version | awk '{print $1}')"
    autoload -Uz is-at-least
    if [[ -n "$minimum" ]] && is-at-least "$minimum" "$mise_version"; then
      ok "mise $mise_version satisfies repository minimum $minimum"
    else
      bad "mise ${mise_version:-<unknown>} does not satisfy ${minimum:-the configured minimum}"
    fi
  else
    bad "mise missing"
  fi
  command -v python3 >/dev/null 2>&1 && ok "python3 present" || bad "python3 missing"
  command -v curl >/dev/null 2>&1 && ok "curl present" || bad "curl missing"
  command -v git >/dev/null 2>&1 && ok "git present" || bad "git missing"

  hdr "Disk and power"
  free_g="$(df -g / 2>/dev/null | awk 'NR==2 { print $4 }')"
  (( ${free_g:-0} >= 20 )) \
    && ok "${free_g}G free on /" \
    || warn "${free_g:-?}G free on / (20G or more is recommended)"
  pmset -g batt 2>/dev/null | grep -q "AC Power" \
    && ok "on AC power" \
    || warn "on battery; Erlang builds can be long"

  hdr "Bootstrap scripts"
  local script
  for script in \
    scripts/bootstrap/exceptions.zsh \
    scripts/bootstrap/relink-static-config.py \
    scripts/bootstrap/link-lazygit-config.zsh \
    scripts/bootstrap/apply-macos-exceptions.zsh \
    scripts/bootstrap/verify.zsh \
    scripts/maintenance/sync-agent-skills.sh; do
    [[ -x "$repo/$script" ]] && ok "$script executable" || bad "$script is not executable"
  done

  hdr "Brewfile entries"
  if [[ ! -f "$brewfile" ]]; then
    bad "BrewFile not found"
  elif command -v brew >/dev/null 2>&1; then
    local formulae_list casks_list have_lists=1 line kind token flag
    local -a declared_taps bad_hard bad_soft
    formulae_list="$(brew formulae 2>/dev/null || true)"
    casks_list="$(brew casks 2>/dev/null || true)"
    [[ -n "$formulae_list" && -n "$casks_list" ]] || have_lists=0
    (( have_lists )) || warn "Homebrew catalog unavailable; using per-token lookups"

    while IFS= read -r line; do
      if [[ "$line" =~ '^[[:space:]]*tap[[:space:]]+"([^"]+)"' ]]; then
        declared_taps+=("${match[1]}")
      fi
    done < "$brewfile"

    resolves_brew_entry() {
      local entry_kind="$1" entry_token="$2" lookup_flag
      [[ "$entry_token" == */* ]] && return 2
      if (( have_lists )); then
        if [[ "$entry_kind" == cask ]]; then
          grep -qxF -- "$entry_token" <<<"$casks_list" && return 0
        else
          grep -qxF -- "$entry_token" <<<"$formulae_list" && return 0
        fi
      fi
      [[ "$entry_kind" == cask ]] && lookup_flag=--cask || lookup_flag=--formula
      brew info "$lookup_flag" "$entry_token" >/dev/null 2>&1 && return 0
      return 1
    }

    local count=0 result tap declared_tap
    while IFS= read -r line; do
      [[ "$line" =~ '^[[:space:]]*(brew|cask)[[:space:]]+"([^"]+)"' ]] || continue
      kind="${match[1]}"
      token="${match[2]}"
      (( count += 1 ))
      resolves_brew_entry "$kind" "$token"
      result=$?
      if (( result == 1 )); then
        bad_hard+=("$kind \"$token\"")
      elif (( result == 2 )); then
        tap="${token%/*}"
        local found=false
        for declared_tap in "${declared_taps[@]}"; do
          [[ "$tap" == "$declared_tap" ]] && found=true && break
        done
        $found || bad_soft+=("$token")
      fi
    done < "$brewfile"

    (( ${#bad_hard} == 0 )) \
      && ok "all $count formula/cask entries resolve or use a declared tap" \
      || for token in "${bad_hard[@]}"; do bad "unknown $token"; done
    for token in "${bad_soft[@]}"; do warn "tap token $token has no matching tap declaration"; done
  else
    bad "cannot validate BrewFile without Homebrew"
  fi

  print "\n========================================"
  if (( blockers == 0 )); then
    print "✅ PRE-FLIGHT PASSED ($warns warning(s))"
    return 0
  fi
  print "❌ PRE-FLIGHT FAILED ($blockers blocker(s), $warns warning(s))"
  return 1
}

if [[ "${ZSH_EVAL_CONTEXT:-}" == toplevel ]]; then
  bootstrap_preflight_main "$@"
fi
