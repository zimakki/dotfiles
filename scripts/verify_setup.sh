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
starship_path=$(command -v starship 2>/dev/null || true)
[[ "$starship_path" == "$BP/bin/starship" ]] \
  && pass "starship from Homebrew ($starship_path)" \
  || fail "starship resolves to ${starship_path:-<none>} (want $BP/bin/starship)"
for f in zsh-autosuggestions/zsh-autosuggestions.zsh zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  [[ -f "$BP/share/$f" ]] && pass "plugin $f" || fail "missing $BP/share/$f"
done

hdr "mise runtimes (functional probes)"
nv=$(mise exec -C "$HOME" -- node --version 2>/dev/null)
[[ "$nv" == *"v24.13.1"* ]] && pass "node $nv" || fail "node: ${nv:-<none>} (want 24.13.1)"
pv=$(mise exec -C "$HOME" -- python --version 2>/dev/null)
[[ "$pv" == *"3.13"* ]] && pass "python $pv" || fail "python: ${pv:-<none>} (want 3.13)"
ev=$(mise exec -C "$HOME" -- elixir --version 2>/dev/null)
[[ "$ev" == *"1.20.2"* ]] && pass "elixir 1.20.2" || fail "elixir: ${ev:-<none>}"
[[ "$ev" == *"OTP 29"*  ]] && pass "erlang/OTP 29" || fail "OTP not 29: ${ev:-<none>}"

hdr "mise bootstrap state"
autoload -Uz is-at-least
if is-at-least 2026.7.4 "$(mise --version | awk '{print $1}')"; then
  pass "mise satisfies the bootstrap minimum"
else
  fail "mise >=2026.7.4 required"
fi
mise bootstrap status --missing >/dev/null 2>&1 \
  && pass "declarative bootstrap state converged" \
  || fail "bootstrap drift detected (run: mise bootstrap status --missing)"

hdr "Bootstrap exceptions"
lazygit_dest="$(lazygit -cd)/config.yml"
[[ -L "$lazygit_dest" && "$(realpath "$lazygit_dest" 2>/dev/null)" == "$REPO/lazygit_config.yml" ]] \
  && pass "dynamic Lazygit link" || fail "dynamic Lazygit link is missing or incorrect"
if "$REPO/scripts/sync_agent_skills.sh" >/dev/null; then
  pass "cross-agent skills and instruction shims validate from every discovery root"
else
  fail "cross-agent skill or instruction validation drift — run scripts/sync_agent_skills.sh --fix"
fi
skip "raycast.rayconfig is imported manually; do not symlink app state"

if [[ "$OSTYPE" == darwin* ]]; then
  battery=$(defaults -currentHost read com.apple.controlcenter BatteryShowPercentage 2>/dev/null)
  [[ "$battery" == 1 ]] && pass "currentHost battery percentage" || fail "currentHost battery percentage differs"
fi

hdr "Integration: interactive shell loads clean"
# Run under a pty (script) so ZLE-based plugins (atuin/tv) initialize exactly as
# in a real terminal; without a tty they emit harmless "can't change option: zle".
errout=$(script -q /dev/null env TERM=xterm-256color zsh -ic 'exit' 2>&1 | perl -pe 's/\r//g; s/\x04//g; s/\x08//g; s/\^D//g' | grep -vE "Saving session|Restored session|^[[:space:]]*$")
if [[ -z "$errout" ]]; then
  pass "interactive shell (pty) loaded clean"
else
  fail "shell load produced unexpected output:"; print "$errout" | sed 's/^/        /'
fi

hdr "Integration: mise runtime precedence"
for runtime in node python; do
  nonlogin=$(zsh -c "command -v $runtime" 2>/dev/null)
  login=$(zsh -lc "command -v $runtime" 2>/dev/null)
  if [[ -n "$nonlogin" && "$login" == "$nonlogin" && "$login" == *"/.local/share/mise/"* ]]; then
    pass "$runtime matches in login/non-login shells ($login)"
  else
    fail "$runtime path drift: zsh -c=${nonlogin:-<none>}, zsh -lc=${login:-<none>}"
  fi
done

hdr "Brewfile drift (installed vs recorded)"
# Direction 1: in BrewFile but not installed
brew bundle check --file="$BREWFILE" >/dev/null 2>&1 \
  && pass "everything in BrewFile is installed" \
  || fail "BrewFile entries missing from system — run: brew bundle --file=$BREWFILE"
# Direction 2: installed but not in BrewFile (dry-run only — NEVER --force here)
drift=$(brew bundle cleanup --file="$BREWFILE" 2>/dev/null | grep -E '^[a-z0-9@/._-]+$' | sort)
if [[ -z "$drift" ]]; then
  pass "nothing installed outside the BrewFile"
else
  fail "installed but not in BrewFile (record via install-app skill, or remove):"
  print "$drift" | sed 's/^/        /'
fi

hdr "mise environment"
mise doctor >/dev/null 2>&1 && pass "mise doctor OK" || fail "mise doctor reported problems (run: mise doctor)"

print "\n========================================"
print "Result: $passes passed, $fails failed"
if (( fails == 0 )); then print "✅ ALL CHECKS PASSED"; exit 0; else print "❌ $fails check(s) failed"; exit 1; fi
