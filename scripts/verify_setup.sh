#!/usr/bin/env zsh
#
# Verify the new Mac is set up correctly. Read-only. Re-runnable anytime.
# Runs every automated post-check for Phase 2 and prints a PASS/FAIL report.
#
#   ./scripts/verify_setup.sh
#
set -u
REPO="${0:A:h:h}"
BREWFILE="$REPO/BrewFile"

passes=0; fails=0
pass() { print "  ✅ $1"; (( passes += 1 )) }
fail() { print "  ❌ $1"; (( fails  += 1 )) }
skip() { print "  ⏭  $1" }
hdr()  { print "\n== $1 ==" }

hdr "oh-my-zsh"
[[ -f ~/.oh-my-zsh/oh-my-zsh.sh ]] && pass "installed" || fail "missing (~/.oh-my-zsh/oh-my-zsh.sh)"

hdr "Homebrew bundle"
brew bundle check --file="$BREWFILE" >/dev/null 2>&1 \
  && pass "all Brewfile dependencies satisfied" \
  || fail "brew bundle NOT satisfied — run: brew bundle --file=$BREWFILE"

hdr "CLIs on PATH"
for c in starship atuin tv fzf zoxide lsd nvim delta bat lazygit rg fd gh; do
  command -v "$c" >/dev/null && pass "$c" || fail "$c not on PATH"
done
BP=$(brew --prefix 2>/dev/null)
for f in zsh-autosuggestions/zsh-autosuggestions.zsh zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  [[ -f "$BP/share/$f" ]] && pass "plugin $f" || fail "missing $BP/share/$f"
done

hdr "mise runtimes (functional probes)"
nv=$(mise exec -- node --version 2>/dev/null)
[[ "$nv" == *"22.12.0"* ]] && pass "node $nv" || fail "node: ${nv:-<none>} (want 22.12.0)"
pv=$(mise exec -- python --version 2>/dev/null)
[[ "$pv" == *"3.13"* ]] && pass "python $pv" || fail "python: ${pv:-<none>} (want 3.13)"
ev=$(mise exec -- elixir --version 2>/dev/null)
[[ "$ev" == *"1.20.1"* ]] && pass "elixir 1.20.1" || fail "elixir: ${ev:-<none>}"
[[ "$ev" == *"OTP 29"*  ]] && pass "erlang/OTP 29" || fail "OTP not 29: ${ev:-<none>}"

hdr "Symlinks (LINKS → repo)"
grep -oE '"[^"]+:(~|/|\$)[^"]*"' "$REPO/setup_sim_links.zsh" | tr -d '"' | while IFS=: read -r src dest; do
  d="${dest/#\~/$HOME}"
  [[ "$d" == *'$('* ]] && d=$(eval echo "$d") 2>/dev/null
  if [[ -L "$d" ]]; then
    tgt=$(realpath "$d" 2>/dev/null)
    [[ "$tgt" == "$REPO"/* ]] && pass "link $d" || fail "$d → $tgt (outside repo)"
  elif [[ -e "$REPO/$src" ]]; then
    fail "$d is not a symlink"
  else
    skip "$d (no repo source: $src)"
  fi
done

hdr "macOS defaults (read-back vs macos_defaults.sh)"
grep -E '^[[:space:]]*defaults write' "$REPO/macos_defaults.sh" | while IFS= read -r line; do
  rest=${line#*defaults write }
  toks=(${(zQ)rest})   # z=shell-split, Q=strip one level of quotes
  if [[ "${toks[1]}" == "-g" || "${toks[1]}" == "NSGlobalDomain" ]]; then
    domain="-g"; key="${toks[2]}"; tflag="${toks[3]}"; val="${toks[4]:-}"
  else
    domain="${toks[1]}"; key="${toks[2]}"; tflag="${toks[3]}"; val="${toks[4]:-}"
  fi
  case "$tflag" in
    -bool) [[ "$val" == "true" ]] && exp=1 || exp=0 ;;
    *)     exp="$val" ;;
  esac
  if [[ "$domain" == "-g" ]]; then act=$(defaults read -g "$key" 2>/dev/null); else act=$(defaults read "$domain" "$key" 2>/dev/null); fi
  [[ "$act" == "$exp" ]] && pass "$domain $key = $act" || fail "$domain $key = '${act:-<unset>}' (expected '$exp')"
done

hdr "Integration: interactive shell loads clean"
# Run under a pty (script) so ZLE-based plugins (atuin/tv) initialize exactly as
# in a real terminal; without a tty they emit harmless "can't change option: zle".
errout=$(script -q /dev/null zsh -ic 'exit' 2>&1 | tr -d '\r\004' | grep -vE "Saving session|Restored session|^[[:space:]]*$")
if [[ -z "$errout" ]]; then
  pass "interactive shell (pty) loaded clean"
else
  fail "shell load produced unexpected output:"; print "$errout" | sed 's/^/        /'
fi

hdr "mise environment"
mise doctor >/dev/null 2>&1 && pass "mise doctor OK" || fail "mise doctor reported problems (run: mise doctor)"

print "\n========================================"
print "Result: $passes passed, $fails failed"
if (( fails == 0 )); then print "✅ ALL CHECKS PASSED"; exit 0; else print "❌ $fails check(s) failed"; exit 1; fi
