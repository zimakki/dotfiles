#!/usr/bin/env zsh
#
# Phase 2 pre-flight — confirm the new Mac is ready to install BEFORE running
# anything. Non-destructive, but it fetches remote refs while checking whether
# the checkout is current. Exits non-zero if any blocker is found; warnings don't block.
#
#   ./scripts/phase2_preflight.sh
#
set -u
REPO="${0:A:h:h}"                 # scripts/ -> repo root
BREWFILE="$REPO/BrewFile"

blockers=0; warns=0
ok()   { print "  ✅ $1" }
bad()  { print "  ❌ $1"; (( blockers += 1 )) }
warn() { print "  ⚠️  $1"; (( warns += 1 )) }
hdr()  { print "\n== $1 ==" }

hdr "Repo state"
if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  ok "git repo on branch: $(git -C "$REPO" rev-parse --abbrev-ref HEAD)"
  git -C "$REPO" fetch --quiet 2>/dev/null
  [[ -z "$(git -C "$REPO" status --porcelain)" ]] && ok "working tree clean" || warn "uncommitted changes in working tree"
  ab=$(git -C "$REPO" rev-list --left-right --count HEAD...@{u} 2>/dev/null || echo "?")
  [[ "$ab" == "0	0" ]] && ok "in sync with upstream" || warn "not in sync with upstream ($ab) — consider git pull"
else
  bad "not a git repo at $REPO"
fi

hdr "Toolchain"
xcode-select -p >/dev/null 2>&1 && ok "Xcode CLT present" || bad "Xcode Command Line Tools missing (erlang won't compile): xcode-select --install"
command -v brew >/dev/null && ok "Homebrew: $(brew --version | head -1)" || bad "Homebrew missing — install the documented prerequisite first"
if command -v mise >/dev/null; then
  mise_version=$(mise --version | awk '{print $1}')
  autoload -Uz is-at-least
  if is-at-least 2026.7.4 "$mise_version"; then
    ok "mise: $mise_version (bootstrap-compatible)"
  else
    bad "mise $mise_version is too old; >=2026.7.4 required (upgrade it through its install channel)"
  fi
else
  bad "mise missing — install >=2026.7.4 as a documented prerequisite"
fi
command -v curl >/dev/null && ok "curl present"                         || bad "curl missing"
command -v git  >/dev/null && ok "git present"                          || bad "git missing"

hdr "Disk space"
free_g=$(df -g / 2>/dev/null | awk 'NR==2{print $4}')
(( ${free_g:-0} >= 20 )) && ok "${free_g}G free on /" || warn "${free_g:-?}G free on / (recommend >=20G for casks + erlang build)"

hdr "Network"
reachable() { local h=$1 i; for i in 1 2 3; do curl -fsS -m 8 -o /dev/null "https://$h" && return 0; sleep 1; done; return 1 }
for host in github.com formulae.brew.sh raw.githubusercontent.com; do
  reachable "$host" && ok "reachable: $host" || bad "cannot reach $host (after 3 tries)"
done

hdr "Power"
pmset -g batt 2>/dev/null | grep -q "AC Power" && ok "on AC power" || warn "on battery — erlang build is long; plug in"

hdr "Scripts"
for s in setup_sim_links.zsh macos_defaults.sh scripts/bootstrap_exceptions.zsh; do
  [[ -x "$REPO/$s" ]] && ok "$s executable" || warn "$REPO/$s not executable (chmod +x)"
done

hdr "Brewfile formula/cask tokens"
if [[ ! -f "$BREWFILE" ]]; then
  bad "BrewFile not found at $BREWFILE"
else
  print "  (validating against the Homebrew catalog…)"
  formulae_list=$(brew formulae 2>/dev/null)
  casks_list=$(brew casks 2>/dev/null)
  have_lists=1; [[ -z "$formulae_list" || -z "$casks_list" ]] && have_lists=0
  (( have_lists )) || warn "couldn't fetch Homebrew catalog — falling back to per-token lookups"

  declared_taps=()
  while IFS= read -r line; do
    [[ "$line" =~ '^[[:space:]]*tap[[:space:]]+"([^"]+)"' ]] \
      && declared_taps+=("${match[1]}")
  done < "$BREWFILE"

  resolves() {  # kind tok -> 0 ok / 1 bad / 2 soft(tap-qualified)
    local kind=$1 tok=$2 flag
    [[ "$tok" == */* ]] && return 2
    if (( have_lists )); then
      if [[ "$kind" == cask ]]; then grep -qxF -- "$tok" <<<"$casks_list" && return 0
      else                           grep -qxF -- "$tok" <<<"$formulae_list" && return 0; fi
    fi
    [[ "$kind" == cask ]] && flag=--cask || flag=--formula
    brew info $flag "$tok" >/dev/null 2>&1 && return 0   # fallback for edge/versioned tokens
    return 1
  }

  bad_hard=(); bad_soft=(); n=0
  while IFS= read -r line; do
    [[ "$line" =~ '^[[:space:]]*(brew|cask)[[:space:]]+"([^"]+)"' ]] || continue
    kind="${match[1]}"; tok="${match[2]}"; (( n += 1 ))
    resolves "$kind" "$tok"
    case $? in
      1) bad_hard+=("$kind \"$tok\"") ;;
      2)
        tap_declared=0
        for declared_tap in $declared_taps; do
          [[ "${tok%/*}" == "$declared_tap" ]] && tap_declared=1 && break
        done
        (( tap_declared )) || bad_soft+=("$tok")
        ;;
    esac
  done < "$BREWFILE"
  if (( ${#bad_hard} == 0 )); then ok "all $n tokens are catalog-resolved or backed by declared taps"; else for t in $bad_hard; do bad "unknown $t (wrong brew/cask type or renamed)"; done; fi
  for t in $bad_soft; do warn "tap token $t has no matching tap declaration"; done
fi

print "\n========================================"
if (( blockers == 0 )); then
  print "✅ PRE-FLIGHT PASSED  ($warns warning(s)) — clear to start Phase 2"
  exit 0
else
  print "❌ PRE-FLIGHT FAILED  ($blockers blocker(s), $warns warning(s)) — fix before installing"
  exit 1
fi
