#!/usr/bin/env bash
# Exercise bootstrap ownership in disposable homes. This script must never run
# Brew, macOS defaults, process restarts, or write into the caller's real HOME.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mise_bin="${MISE_BIN:-$(command -v mise || true)}"
if [[ -n "${PYTHON_BIN:-}" ]]; then
  python_bin="$PYTHON_BIN"
elif [[ -x /opt/homebrew/bin/python3 ]]; then
  python_bin=/opt/homebrew/bin/python3
else
  python_bin="$(command -v python3 || true)"
fi

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf '  OK   %s\n' "$*"; }

[[ -n "$mise_bin" ]] || fail "mise is required (>=2026.7.4)"
[[ -n "$python_bin" ]] || fail "python3 is required"
command -v zsh >/dev/null || fail "zsh is required"

version="$($mise_bin --version | awk '{print $1}')"
"$python_bin" - "$version" <<'PY'
import sys
version = tuple(int(part) for part in sys.argv[1].split("."))
if version < (2026, 7, 4):
    raise SystemExit(f"mise >=2026.7.4 required, got {sys.argv[1]}")
PY

root="$(mktemp -d "${TMPDIR:-/tmp}/mise-bootstrap-isolated.XXXXXX")"
trap 'rm -rf "$root"' EXIT
home="$root/home"
mkdir -p "$home" "$root/work"

mise_env=(
  "HOME=$home"
  "MISE_DATA_DIR=$root/mise/data"
  "MISE_CACHE_DIR=$root/mise/cache"
  "MISE_STATE_DIR=$root/mise/state"
  "MISE_TRUSTED_CONFIG_PATHS=$repo:$home/.config/mise/config.toml"
)
run_mise() { env "${mise_env[@]}" "$mise_bin" "$@"; }

printf 'Testing dotfile dry-run isolation\n'
run_mise bootstrap dotfiles apply --dry-run >/dev/null
[[ ! -e "$home/.zshenv" && ! -L "$home/.zshenv" ]] \
  || fail "dotfile dry-run wrote into the temporary home"
pass "dry-run made no changes"

printf 'Testing dotfile apply and convergence\n'
run_mise bootstrap dotfiles apply --yes >/dev/null
"$python_bin" - "$repo" "$home" <<'PY'
from pathlib import Path
import sys, tomllib

repo, home = map(Path, sys.argv[1:])
config = tomllib.loads((repo / "mise.toml").read_text())
for target, entry in config["dotfiles"].items():
    target = home / target.removeprefix("~/")
    source = entry if isinstance(entry, str) else entry["source"]
    source = (repo / source).resolve()
    if not target.is_symlink() or target.resolve() != source:
        raise SystemExit(f"bad dotfile link: {target} -> {source}")
print(f"validated {len(config['dotfiles'])} static links")
PY
run_mise bootstrap dotfiles apply --yes >/dev/null
run_mise bootstrap dotfiles status --missing >/dev/null
pass "19 links apply and converge on a second run"

printf 'Testing global config after the first apply\n'
(
  cd "$root/work"
  env "${mise_env[@]}" "$mise_bin" config get tools.node
) | grep -qx '24.13.1' || fail "global config did not expose pinned tools"
pass "repo config remains available through the global symlink"

printf 'Testing conflict refusal\n'
conflict_home="$root/conflict-home"
mkdir -p "$conflict_home"
printf 'intentionally different\n' > "$conflict_home/.zshrc"
conflict_env=(
  "HOME=$conflict_home"
  "MISE_DATA_DIR=$root/conflict-mise/data"
  "MISE_CACHE_DIR=$root/conflict-mise/cache"
  "MISE_STATE_DIR=$root/conflict-mise/state"
  "MISE_TRUSTED_CONFIG_PATHS=$repo"
)
if env "${conflict_env[@]}" "$mise_bin" bootstrap dotfiles apply --yes >/dev/null 2>&1; then
  fail "mise replaced a conflicting dotfile without --force"
fi
grep -q 'intentionally different' "$conflict_home/.zshrc" \
  || fail "conflicting dotfile content changed"
pass "conflicts are refused and preserved"

printf 'Testing login and non-login shell precedence\n'
zdot="$root/zdot"
mkdir -p "$zdot" "$root/fake-mise-data/shims"
ln -s "$repo/zshenv" "$zdot/.zshenv"
ln -s "$repo/zprofile" "$zdot/.zprofile"
for runtime in node python; do
  printf '#!/bin/sh\nexit 0\n' > "$root/fake-mise-data/shims/$runtime"
  chmod +x "$root/fake-mise-data/shims/$runtime"
  expected="$root/fake-mise-data/shims/$runtime"
  nonlogin="$(HOME="$home" ZDOTDIR="$zdot" MISE_DATA_DIR="$root/fake-mise-data" zsh -c "command -v $runtime")"
  login="$(HOME="$home" ZDOTDIR="$zdot" MISE_DATA_DIR="$root/fake-mise-data" zsh -lc "command -v $runtime")"
  [[ "$nonlogin" == "$expected" && "$login" == "$expected" ]] \
    || fail "$runtime path drift: non-login=$nonlogin login=$login"
done
pass "login and non-login shells use the same mise shims"

printf 'Testing exception scripts with command fakes\n'
fake_bin="$root/fake-bin"
exception_home="$root/exception-home"
log="$root/commands.log"
mkdir -p "$fake_bin" "$exception_home/.config/mise"
ln -s "$repo/mise.toml" "$exception_home/.config/mise/config.toml"

make_fake() {
  local name=$1 body=$2
  printf '#!/bin/sh\n%s\n' "$body" > "$fake_bin/$name"
  chmod +x "$fake_bin/$name"
}
make_fake mise 'printf "mise %s\\n" "$*" >> "$BOOTSTRAP_TEST_LOG"'
make_fake lazygit 'printf "lazygit %s\\n" "$*" >> "$BOOTSTRAP_TEST_LOG"; printf "%s\\n" "$HOME/.config/lazygit"'
make_fake defaults 'printf "defaults %s\\n" "$*" >> "$BOOTSTRAP_TEST_LOG"'
make_fake killall 'printf "killall %s\\n" "$*" >> "$BOOTSTRAP_TEST_LOG"'

fake_path="$fake_bin:/usr/bin:/bin"
env HOME="$exception_home" CODEX_HOME="$exception_home/.codex" \
  BOOTSTRAP_TEST_LOG="$log" PATH="$fake_path" \
  zsh "$repo/scripts/bootstrap_exceptions.zsh" >/dev/null
env HOME="$exception_home" BOOTSTRAP_TEST_LOG="$log" PATH="$fake_path" \
  zsh "$repo/macos_defaults.sh" >/dev/null
env HOME="$exception_home" CODEX_HOME="$exception_home/.codex" \
  BOOTSTRAP_TEST_LOG="$log" PATH="$fake_path" \
  zsh "$repo/scripts/bootstrap_exceptions.zsh" >/dev/null

grep -q '^mise trust .*\.config/mise/config.toml$' "$log" || fail "global trust exception was not exercised"
grep -q '^defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true$' "$log" \
  || fail "currentHost default was not exercised"
grep -q '^killall Finder Dock SystemUIServer$' "$log" || fail "restart exception was not exercised"
[[ -L "$exception_home/.config/lazygit/config.yml" ]] || fail "dynamic Lazygit link was not created"
[[ -f "$exception_home/.agents/skills/.dotfiles-managed-skills" ]] || fail "skill sync did not use temporary HOME"
pass "exceptions are idempotent under fakes and stay inside temporary HOME"

printf '\nAll isolated bootstrap checks passed with mise %s.\n' "$version"
