#!/usr/bin/env zsh
# Read-only verification for a bootstrapped machine.
set -u
setopt pipe_fail

REPO="${0:A:h:h:h}"
BREWFILE="$REPO/BrewFile"
source "$REPO/scripts/bootstrap/preflight.zsh"

passes=0
fails=0
pass() { print "  ✅ $1"; (( passes += 1 )) }
fail() { print "  ❌ $1"; (( fails += 1 )) }
hdr()  { print "\n== $1 ==" }

configured_value() {
  python3 - "$REPO/mise.toml" "$1" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    config = tomllib.load(handle)
value = config
for component in sys.argv[2].split("."):
    value = value[component]
print(value)
PY
}

hdr "Bootstrap source"
if bootstrap_require_canonical_checkout "$REPO"; then
  pass "repository is the canonical checkout"
else
  fail "repository is a linked worktree and must not own HOME links"
fi

hdr "oh-my-zsh"
[[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]] && pass "installed" || fail "missing"

hdr "Homebrew bundle"
if brew bundle check --file="$BREWFILE" >/dev/null 2>&1; then
  pass "all BrewFile dependencies satisfied"
else
  fail "BrewFile dependencies are missing"
fi

hdr "CLIs on PATH"
for command_name in starship atuin tv fzf zoxide lsd nvim delta bat lazygit rg fd gh; do
  command -v "$command_name" >/dev/null 2>&1 \
    && pass "$command_name" \
    || fail "$command_name not on PATH"
done
brew_prefix="$(brew --prefix 2>/dev/null || true)"
starship_path="$(command -v starship 2>/dev/null || true)"
[[ -n "$brew_prefix" && "$starship_path" == "$brew_prefix/bin/starship" ]] \
  && pass "starship comes from Homebrew" \
  || fail "starship resolves to ${starship_path:-<none>}"
for plugin in \
  zsh-autosuggestions/zsh-autosuggestions.zsh \
  zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  [[ -f "$brew_prefix/share/$plugin" ]] && pass "plugin $plugin" || fail "missing $plugin"
done

hdr "mise runtimes"
node_expected="$(configured_value tools.node)"
node_actual="$(mise exec -C "$HOME" -- node --version 2>/dev/null || true)"
[[ "$node_actual" == "v$node_expected" ]] \
  && pass "node $node_actual" \
  || fail "node ${node_actual:-<none>} (want v$node_expected)"

python_expected="$(configured_value tools.python)"
python_actual="$(mise exec -C "$HOME" -- python --version 2>/dev/null || true)"
[[ "$python_actual" == "Python $python_expected" ]] \
  && pass "$python_actual" \
  || fail "python ${python_actual:-<none>} (want Python $python_expected)"

elixir_expected="$(configured_value tools.elixir)"
elixir_version="${elixir_expected%%-*}"
erlang_expected="$(configured_value tools.erlang)"
erlang_major="${erlang_expected%%.*}"
elixir_actual="$(mise exec -C "$HOME" -- elixir --version 2>/dev/null || true)"
[[ "$elixir_actual" == *"Elixir $elixir_version"* ]] \
  && pass "elixir $elixir_version" \
  || fail "elixir output does not contain $elixir_version"
[[ "$elixir_actual" == *"Erlang/OTP $erlang_major"* || "$elixir_actual" == *"OTP $erlang_major"* ]] \
  && pass "Erlang/OTP $erlang_major" \
  || fail "Erlang output does not contain OTP $erlang_major"

hdr "mise bootstrap state"
minimum="$(configured_value min_version)"
autoload -Uz is-at-least
mise_version="$(mise --version | awk '{print $1}')"
if is-at-least "$minimum" "$mise_version"; then
  pass "mise $mise_version satisfies $minimum"
else
  fail "mise $mise_version is older than $minimum"
fi
mise bootstrap status --missing >/dev/null 2>&1 \
  && pass "declarative bootstrap state converged" \
  || fail "bootstrap drift detected"

hdr "Bootstrap exceptions"
python3 "$REPO/scripts/bootstrap/relink-static-config.py" --check >/dev/null 2>&1 \
  && pass "static HOME links use direct declared sources" \
  || fail "static HOME links still depend on compatibility paths"
"$REPO/scripts/bootstrap/link-lazygit-config.zsh" --check >/dev/null 2>&1 \
  && pass "dynamic Lazygit link" \
  || fail "dynamic Lazygit link is missing or incorrect"
python3 "$REPO/scripts/bootstrap/json-overlay.py" --check \
  "$REPO/config/claude/settings.json" "$HOME/.claude/settings.json" >/dev/null 2>&1 \
  && pass "Claude managed settings overlay" \
  || fail "Claude managed settings have drifted"
python3 "$REPO/scripts/bootstrap/json-overlay.py" --check \
  "$REPO/config/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json" >/dev/null 2>&1 \
  && pass "Karabiner managed settings overlay" \
  || fail "Karabiner managed settings have drifted"
"$REPO/scripts/maintenance/sync-agent-skills.sh" >/dev/null \
  && pass "cross-agent skills and instruction shims" \
  || fail "cross-agent skill discovery drift"
if [[ "$OSTYPE" == darwin* ]]; then
  "$REPO/scripts/bootstrap/apply-macos-exceptions.zsh" --check >/dev/null 2>&1 \
    && pass "host-scoped macOS defaults" \
    || fail "host-scoped macOS default drift"
fi

hdr "Interactive shell"
errout="$(script -q /dev/null env DOTFILES_SKIP_SECRET_REFRESH=1 TERM=xterm-256color \
  zsh -ic 'exit' 2>&1 \
  | perl -pe 's/\r//g; s/\x04//g; s/\x08//g; s/\^D//g' \
  | grep -vE "Saving session|Restored session|^[[:space:]]*$" || true)"
if [[ -z "$errout" ]]; then
  pass "interactive shell loaded cleanly"
else
  fail "interactive shell emitted unexpected output"
  print "$errout" | sed 's/^/        /'
fi

hdr "Runtime precedence"
for runtime in node python; do
  nonlogin="$(zsh -c "command -v $runtime" 2>/dev/null || true)"
  login="$(zsh -lc "command -v $runtime" 2>/dev/null || true)"
  if [[ -n "$nonlogin" && "$login" == "$nonlogin" && "$login" == *"/.local/share/mise/"* ]]; then
    pass "$runtime matches in login and non-login shells"
  else
    fail "$runtime path differs between shell modes"
  fi
done

hdr "Package and mise health"
drift="$(brew bundle cleanup --file="$BREWFILE" 2>/dev/null \
  | grep -E '^[a-z0-9@/._-]+$' | sort || true)"
[[ -z "$drift" ]] \
  && pass "nothing installed outside BrewFile" \
  || {
    fail "Homebrew packages exist outside BrewFile"
    print "$drift" | sed 's/^/        /'
  }
mise doctor >/dev/null 2>&1 && pass "mise doctor" || fail "mise doctor reported problems"

print "\n========================================"
print "Result: $passes passed, $fails failed"
(( fails == 0 )) && print "✅ ALL CHECKS PASSED" && exit 0
print "❌ $fails check(s) failed"
exit 1
