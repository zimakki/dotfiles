#!/usr/bin/env bash
# Exercise bootstrap behavior in disposable homes. This script must never run
# Brew, real macOS defaults, process restarts, or write into the caller's HOME.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

[[ -n "$mise_bin" ]] || fail "mise is required"
[[ -n "$python_bin" ]] || fail "python3 is required"
command -v zsh >/dev/null 2>&1 || fail "zsh is required"

version="$($mise_bin --version | awk '{print $1}')"
minimum="$($python_bin - "$repo/mise.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    print(tomllib.load(handle)["min_version"])
PY
)"
"$python_bin" - "$version" "$minimum" <<'PY'
import re, sys
def parsed(value):
    match = re.match(r"^(\d+(?:\.\d+)+)", value)
    if not match:
        raise SystemExit(f"unparseable version: {value}")
    return tuple(map(int, match.group(1).split(".")))
if parsed(sys.argv[1]) < parsed(sys.argv[2]):
    raise SystemExit(f"mise >= {sys.argv[2]} required, got {sys.argv[1]}")
PY

root="$(mktemp -d "${TMPDIR:-/tmp}/mise-bootstrap-isolated.XXXXXX")"
trap 'rm -rf "$root"' EXIT
home="$root/home"
mkdir -p "$home" "$root/work" "$root/mise"

# mise may discover a real global config by both its symlink path and its
# resolved repository path on macOS. Explicitly ignore both while testing.
caller_global="${MISE_GLOBAL_CONFIG_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml}"
ignored_paths=()
if [[ -e "$caller_global" || -L "$caller_global" ]]; then
  ignored_paths+=("$caller_global")
  caller_global_resolved="$($python_bin - "$caller_global" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
)"
  [[ "$caller_global_resolved" == "$caller_global" ]] || ignored_paths+=("$caller_global_resolved")
fi
ignored_config_paths=""
if (( ${#ignored_paths[@]} > 0 )); then
  ignored_config_paths="$(IFS=:; printf '%s' "${ignored_paths[*]}")"
fi

mise_env=(
  "HOME=$home"
  "XDG_CONFIG_HOME=$home/.config"
  "MISE_CONFIG_DIR=$root/mise/config"
  "MISE_DATA_DIR=$root/mise/data"
  "MISE_CACHE_DIR=$root/mise/cache"
  "MISE_STATE_DIR=$root/mise/state"
  "MISE_SYSTEM_CONFIG_FILE=$root/mise/system.toml"
  "MISE_GLOBAL_CONFIG_FILE=$home/.config/mise/config.toml"
  "MISE_TRUSTED_CONFIG_PATHS=$repo:$home/.config/mise/config.toml"
  "DOTFILES_BOOTSTRAP_TEST_ALLOW_WORKTREE=1"
)
[[ -z "$ignored_config_paths" ]] || mise_env+=("MISE_IGNORED_CONFIG_PATHS=$ignored_config_paths")

run_clean_env() {
  env -u MISE_CONFIG_FILE -u MISE_GLOBAL_CONFIG_ROOT "$@"
}
run_mise() {
  run_clean_env "${mise_env[@]}" "$mise_bin" "$@"
}
run_static_relink() {
  run_clean_env "${mise_env[@]}" "$python_bin" \
    "$repo/scripts/bootstrap/relink-static-config.py" "$@"
}

printf 'Testing canonical-checkout mutation guard\n'
guard_primary="$root/guard-primary"
guard_linked="$root/guard-linked"
git init --quiet --initial-branch=main "$guard_primary"
mkdir -p "$guard_primary/scripts/bootstrap" "$guard_primary/config/zsh"
printf 'guard fixture\n' > "$guard_primary/fixture"
cp "$repo/mise.toml" "$guard_primary/mise.toml"
cp "$repo/scripts/bootstrap/json-overlay.py" \
  "$guard_primary/scripts/bootstrap/json-overlay.py"
cp "$repo/scripts/bootstrap/relink-static-config.py" \
  "$guard_primary/scripts/bootstrap/relink-static-config.py"
printf '# guard zshenv fixture\n' > "$guard_primary/config/zsh/zshenv"
ln -s config/zsh/zshenv "$guard_primary/zshenv"
"$python_bin" - "$guard_primary/mise.toml" <<'PY'
from pathlib import Path
import re, sys

path = Path(sys.argv[1])
text = path.read_text()
text = re.sub(
    r"\[dotfiles\]\n.*?(?=\n\[bootstrap\.macos\.keyboard\])",
    '[dotfiles]\n"~/.zshenv" = "config/zsh/zshenv"\n',
    text,
    flags=re.DOTALL,
)
path.write_text(text)
PY
printf '# intentionally empty fixture\n' > "$guard_primary/BrewFile"
cp "$repo/scripts/bootstrap/preflight.zsh" \
  "$guard_primary/scripts/bootstrap/preflight.zsh"
git -C "$guard_primary" add fixture mise.toml BrewFile zshenv config/zsh/zshenv \
  scripts/bootstrap/preflight.zsh scripts/bootstrap/json-overlay.py \
  scripts/bootstrap/relink-static-config.py
git -C "$guard_primary" -c user.name=Bootstrap -c user.email=bootstrap@example.invalid \
  commit --quiet -m fixture
git -C "$guard_primary" worktree add --quiet -b linked-test "$guard_linked"
guard_linked_real="$(cd "$guard_linked" && pwd -P)"
zsh "$guard_primary/scripts/bootstrap/preflight.zsh" --guard-only
if zsh "$guard_linked/scripts/bootstrap/preflight.zsh" --guard-only >/dev/null 2>&1; then
  fail "mutation guard accepted a linked worktree"
fi
DOTFILES_BOOTSTRAP_TEST_ALLOW_WORKTREE=1 \
  zsh "$guard_linked/scripts/bootstrap/preflight.zsh" --guard-only >/dev/null
pass "canonical checkout passes, linked worktree fails, explicit test override passes"

guard_home="$root/guard-home"
mkdir -p "$guard_home"
ln -s "$guard_linked_real/zshenv" "$guard_home/.zshenv"
if HOME="$guard_home" \
  "$python_bin" "$guard_linked/scripts/bootstrap/relink-static-config.py" >/dev/null 2>&1; then
  fail "static-link migration bypassed the linked-worktree guard"
fi
[[ "$(readlink "$guard_home/.zshenv")" == "$guard_linked_real/zshenv" ]] \
  || fail "refused static-link migration changed its target"
HOME="$guard_home" DOTFILES_BOOTSTRAP_TEST_ALLOW_WORKTREE=1 \
  "$python_bin" "$guard_linked/scripts/bootstrap/relink-static-config.py" >/dev/null
[[ "$(readlink "$guard_home/.zshenv")" == "$guard_linked_real/config/zsh/zshenv" ]] \
  || fail "guarded static-link fixture did not migrate with the test override"
pass "static-link migration is guarded before rewriting a compatibility chain"

printf 'Testing guard coverage for full and partial mise bootstrap runs\n'
partial_home="$root/partial-home"
partial_bin="$root/partial-bin"
partial_log="$root/partial-mutations.log"
mkdir -p "$partial_home" "$partial_bin"
printf '#!/bin/sh\nprintf "brew %%s\\n" "$*" >> "$PARTIAL_LOG"\n' > "$partial_bin/brew"
printf '#!/bin/sh\nprintf "defaults %%s\\n" "$*" >> "$PARTIAL_LOG"\n' > "$partial_bin/defaults"
chmod +x "$partial_bin/brew" "$partial_bin/defaults"
partial_env=(
  "HOME=$partial_home"
  "XDG_CONFIG_HOME=$partial_home/.config"
  "MISE_CONFIG_DIR=$root/partial-mise/config"
  "MISE_DATA_DIR=$root/partial-mise/data"
  "MISE_CACHE_DIR=$root/partial-mise/cache"
  "MISE_STATE_DIR=$root/partial-mise/state"
  "MISE_SYSTEM_CONFIG_FILE=$root/partial-mise/system.toml"
  "MISE_GLOBAL_CONFIG_FILE=$partial_home/.config/mise/config.toml"
  "MISE_TRUSTED_CONFIG_PATHS=$guard_linked"
  "MISE_TASK_RUN_AUTO_INSTALL=false"
  "MISE_OFFLINE=true"
  "PARTIAL_LOG=$partial_log"
  "PATH=$partial_bin:/usr/bin:/bin"
)
[[ -z "$ignored_config_paths" ]] || partial_env+=("MISE_IGNORED_CONFIG_PATHS=$ignored_config_paths")
assert_partial_bootstrap_refused() {
  local label=$1
  shift
  if (
    cd "$guard_linked"
    run_clean_env "${partial_env[@]}" "$mise_bin" bootstrap "$@" --yes >/dev/null 2>&1
  ); then
    fail "linked-worktree guard accepted mise bootstrap $label"
  fi
}
assert_partial_bootstrap_refused "<full>"
assert_partial_bootstrap_refused "--only tools" --only tools
if [[ "$(uname -s)" == Darwin ]]; then
  if (
    cd "$guard_linked"
    run_clean_env "${partial_env[@]}" "$mise_bin" bootstrap --only macos-defaults --yes >/dev/null 2>&1
  ); then
    fail "linked-worktree guard accepted --only macos-defaults"
  fi
fi
[[ ! -e "$partial_log" ]] || fail "a mutation command ran before its worktree guard"
pass "full bootstrap, --only tools, and platform defaults stop before mutation"

printf 'Testing direct JSON mutation guard\n'
printf '%s\n' '{"managed":true}' > "$guard_linked/managed.json"
if "$python_bin" "$guard_linked/scripts/bootstrap/json-overlay.py" \
  --repo-root "$guard_linked" "$guard_linked/managed.json" "$root/guarded-live.json" \
  >/dev/null 2>&1; then
  fail "direct JSON overlay mutated from a linked worktree"
fi
[[ ! -e "$root/guarded-live.json" ]] || fail "refused JSON overlay still wrote its target"
DOTFILES_BOOTSTRAP_TEST_ALLOW_WORKTREE=1 \
  "$python_bin" "$guard_linked/scripts/bootstrap/json-overlay.py" \
  --repo-root "$guard_linked" "$guard_linked/managed.json" "$root/guarded-live.json" \
  >/dev/null
[[ -f "$root/guarded-live.json" ]] || fail "explicit JSON test override did not apply"
pass "direct JSON mutation is guarded with an explicit test-only override"

printf 'Testing dotfile dry-run isolation\n'
(
  cd "$repo"
  run_mise bootstrap dotfiles apply --dry-run >/dev/null
)
[[ ! -e "$home/.zshenv" && ! -L "$home/.zshenv" ]] \
  || fail "dotfile dry-run wrote into the temporary home"
pass "dry-run made no changes"

printf 'Testing dotfile apply and convergence\n'
(
  cd "$repo"
  run_mise bootstrap dotfiles apply --yes >/dev/null
)
link_count="$($python_bin - "$repo" "$home" <<'PY'
from pathlib import Path
import sys, tomllib

repo, home = map(Path, sys.argv[1:])
with (repo / "mise.toml").open("rb") as handle:
    config = tomllib.load(handle)
for target_name, entry in config["dotfiles"].items():
    target = home / target_name.removeprefix("~/")
    source_name = entry if isinstance(entry, str) else entry["source"]
    source = (repo / source_name).resolve()
    if not target.is_symlink() or target.resolve() != source:
        raise SystemExit(f"bad dotfile link: {target} -> {source}")
print(len(config["dotfiles"]))
PY
)"
(
  cd "$repo"
  run_mise bootstrap dotfiles apply --yes >/dev/null
  run_mise bootstrap dotfiles status --missing >/dev/null
)
pass "$link_count static links apply and converge on a second run"

printf 'Testing transitional static-link migration\n'
rm "$home/.zshenv" "$home/.config/television"
ln -s "$repo/zshenv" "$home/.zshenv"
ln -s "$repo/television" "$home/.config/television"
(
  cd "$repo"
  run_mise bootstrap dotfiles apply --yes >/dev/null
)
[[ "$(readlink "$home/.zshenv")" == "$repo/zshenv" ]] \
  || fail "mise unexpectedly normalized the compatibility-chain fixture"
if run_static_relink --check >/dev/null 2>&1; then
  fail "static-link check accepted indirect compatibility links"
fi
run_static_relink >/dev/null
[[ "$(readlink "$home/.zshenv")" == "$repo/config/zsh/zshenv" ]] \
  || fail "file compatibility link was not rewritten directly"
[[ "$(readlink "$home/.config/television")" == "$repo/config/television" ]] \
  || fail "directory compatibility link was not rewritten directly"
run_static_relink --check >/dev/null

outside_bridge="$root/outside-zprofile-link"
ln -s "$repo/config/zsh/zprofile" "$outside_bridge"
rm "$home/.zprofile"
ln -s "$outside_bridge" "$home/.zprofile"
if run_static_relink >/dev/null 2>&1; then
  fail "static-link migration accepted an outside-repo first hop"
fi
[[ "$(readlink "$home/.zprofile")" == "$outside_bridge" ]] \
  || fail "refused outside-repo link was not preserved"
rm "$home/.zprofile"
ln -s "$repo/config/zsh/zprofile" "$home/.zprofile"
run_static_relink --check >/dev/null
pass "repo-owned chains become direct while outside-repo chains are refused and preserved"

printf 'Testing hermetic global config discovery\n'
expected_node="$($python_bin - "$repo/mise.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    print(tomllib.load(handle)["tools"]["node"])
PY
)"
actual_node="$({
  cd "$root/work"
  run_mise config get tools.node
})"
[[ "$actual_node" == "$expected_node" ]] || fail "global config did not expose pinned tools"
config_listing="$({
  cd "$root/work"
  run_mise config ls --json
})"
"$python_bin" - "$config_listing" "${ignored_paths[@]}" <<'PY'
import json, os, sys
loaded = {os.path.realpath(item["path"]) for item in json.loads(sys.argv[1])}
for ignored in sys.argv[2:]:
    if ignored in {item["path"] for item in json.loads(sys.argv[1])} or os.path.realpath(ignored) in loaded:
        raise SystemExit(f"real config leaked into isolated test: {ignored}")
PY
pass "temporary global config works without loading the caller's global path or target"

printf 'Testing static-dotfile conflict refusal\n'
conflict_home="$root/conflict-home"
mkdir -p "$conflict_home"
printf 'intentionally different\n' > "$conflict_home/.zshrc"
conflict_env=(
  "HOME=$conflict_home"
  "XDG_CONFIG_HOME=$conflict_home/.config"
  "MISE_CONFIG_DIR=$root/conflict-mise/config"
  "MISE_DATA_DIR=$root/conflict-mise/data"
  "MISE_CACHE_DIR=$root/conflict-mise/cache"
  "MISE_STATE_DIR=$root/conflict-mise/state"
  "MISE_SYSTEM_CONFIG_FILE=$root/conflict-mise/system.toml"
  "MISE_GLOBAL_CONFIG_FILE=$conflict_home/.config/mise/config.toml"
  "MISE_TRUSTED_CONFIG_PATHS=$repo"
  "DOTFILES_BOOTSTRAP_TEST_ALLOW_WORKTREE=1"
)
[[ -z "$ignored_config_paths" ]] || conflict_env+=("MISE_IGNORED_CONFIG_PATHS=$ignored_config_paths")
if (
  cd "$repo"
  run_clean_env "${conflict_env[@]}" "$mise_bin" bootstrap dotfiles apply --yes >/dev/null 2>&1
); then
  fail "mise replaced a conflicting dotfile without --force"
fi
grep -q 'intentionally different' "$conflict_home/.zshrc" \
  || fail "conflicting dotfile content changed"
pass "static conflicts are refused and preserved"

config_source() {
  "$python_bin" - "$repo/mise.toml" "$1" "$repo" <<'PY'
import sys, tomllib
from pathlib import Path
with open(sys.argv[1], "rb") as handle:
    entry = tomllib.load(handle)["dotfiles"][sys.argv[2]]
source = entry if isinstance(entry, str) else entry["source"]
print(Path(sys.argv[3], source))
PY
}

printf 'Testing login and non-login shell precedence\n'
zdot="$root/zdot"
mkdir -p "$zdot" "$root/fake-mise-data/shims"
# These are literal target keys in mise.toml, not shell paths to expand.
# shellcheck disable=SC2088
ln -s "$(config_source '~/.zshenv')" "$zdot/.zshenv"
# shellcheck disable=SC2088
ln -s "$(config_source '~/.zprofile')" "$zdot/.zprofile"
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

mkdir -p "$home/.local/bin"
printf '#!/bin/sh\nexit 0\n' > "$home/.local/bin/node"
chmod +x "$home/.local/bin/node"
expected="$home/.local/bin/node"
nonlogin="$(HOME="$home" ZDOTDIR="$zdot" MISE_DATA_DIR="$root/fake-mise-data" zsh -c 'command -v node')"
login="$(HOME="$home" ZDOTDIR="$zdot" MISE_DATA_DIR="$root/fake-mise-data" zsh -lc 'command -v node')"
[[ "$nonlogin" == "$expected" && "$login" == "$expected" ]] \
  || fail "user-bin precedence drift: non-login=$nonlogin login=$login"
pass "user-bin precedence is consistent across shell modes"

printf 'Testing interactive shell startup with a portable HOME\n'
# shellcheck disable=SC2088
ln -s "$(config_source '~/.zshrc')" "$zdot/.zshrc"
mkdir -p "$home/.oh-my-zsh" "$root/shell-bin"
printf 'compdef() { :; }\n' > "$home/.oh-my-zsh/oh-my-zsh.sh"
printf '#!/bin/sh\nexit 0\n' > "$root/shell-bin/zoxide"
printf '#!/bin/sh\nexit 0\n' > "$root/shell-bin/mise"
chmod +x "$root/shell-bin/zoxide" "$root/shell-bin/mise"
# macOS path_helper can reorder the inherited PATH in a login shell; zprofile
# deliberately restores ~/.local/bin first, so place the command fake there too.
printf '#!/bin/sh\nexit 0\n' > "$home/.local/bin/mise"
chmod +x "$home/.local/bin/mise"
for shell_mode in -ic -lic; do
  # Ignore runner-owned global startup files. Ubuntu's /etc/zsh/zshrc invokes
  # compinit, which requires a terminal and is unrelated to this repository's
  # portable HOME configuration. zsh -d disables GLOBAL_RCS while retaining
  # the user startup files under ZDOTDIR.
  if ! output="$(HOME="$home" ZDOTDIR="$zdot" DOTFILES_SKIP_SECRET_REFRESH=1 \
    MISE_DATA_DIR="$root/fake-mise-data" \
    MISE_GLOBAL_CONFIG_FILE="$home/.config/mise/config.toml" \
    MISE_TRUSTED_CONFIG_PATHS="$repo:$home/.config/mise/config.toml" \
    PATH="$root/shell-bin:$PATH" TERM=xterm-256color zsh -d "$shell_mode" 'exit' 2>&1)"; then
    fail "portable HOME shell startup failed in mode $shell_mode: $output"
  fi
  [[ -z "$output" ]] || fail "portable HOME shell startup emitted output in mode $shell_mode: $output"
done
pass "interactive login and non-login shells load cleanly outside the real HOME"

printf 'Testing recursive JSON overlays\n'
overlay_repo="$root/overlay-repo"
overlay_home="$root/overlay-home"
mkdir -p "$overlay_repo" "$overlay_home"
printf '%s\n' '{"managed":{"nested":1,"list":[1]},"scalar":"new"}' > "$overlay_repo/managed.json"
printf '%s\n' '{"unmanaged":true,"managed":{"nested":0,"extra":"keep","list":[9,8]},"scalar":{"old":1}}' > "$overlay_home/live.json"
overlay=(env DOTFILES_BOOTSTRAP_TEST_ALLOW_WORKTREE=1 \
  "$python_bin" "$repo/scripts/bootstrap/json-overlay.py" --repo-root "$overlay_repo")
if "${overlay[@]}" --check "$overlay_repo/managed.json" "$overlay_home/live.json" >/dev/null 2>&1; then
  fail "overlay check did not report drift"
fi
"${overlay[@]}" "$overlay_repo/managed.json" "$overlay_home/live.json" >/dev/null
inode_before="$(ls -di "$overlay_home/live.json" | awk '{print $1}')"
"${overlay[@]}" "$overlay_repo/managed.json" "$overlay_home/live.json" >/dev/null
inode_after="$(ls -di "$overlay_home/live.json" | awk '{print $1}')"
[[ "$inode_before" == "$inode_after" ]] || fail "converged overlay rewrote the target"
"${overlay[@]}" --check "$overlay_repo/managed.json" "$overlay_home/live.json" >/dev/null
"$python_bin" - "$overlay_home/live.json" <<'PY'
import json, sys
with open(sys.argv[1]) as handle:
    value = json.load(handle)
assert value == {
    "unmanaged": True,
    "managed": {"nested": 1, "extra": "keep", "list": [1]},
    "scalar": "new",
}
PY

printf '%s\n' '{"outside":true}' > "$root/outside.json"
ln -s "$root/outside.json" "$overlay_home/arbitrary-link.json"
set +e
"${overlay[@]}" "$overlay_repo/managed.json" "$overlay_home/arbitrary-link.json" >/dev/null 2>&1
overlay_status=$?
set -e
[[ $overlay_status -eq 2 && -L "$overlay_home/arbitrary-link.json" ]] \
  || fail "overlay did not refuse and preserve an arbitrary symlink"

mkdir -p "$overlay_repo/config/claude"
mv "$overlay_repo/managed.json" "$overlay_repo/config/claude/settings.json"
printf '%s\n' '{"feedbackSurveyState":{"lastShownTime":42},"managed":{"extra":"legacy"}}' \
  > "$overlay_repo/config/claude/settings.legacy.json"
ln -s config/claude/settings.legacy.json "$overlay_repo/claude_settings.json"
ln -s "$overlay_repo/claude_settings.json" "$overlay_home/repo-link.json"
"${overlay[@]}" "$overlay_repo/config/claude/settings.json" "$overlay_home/repo-link.json" >/dev/null
[[ -f "$overlay_home/repo-link.json" && ! -L "$overlay_home/repo-link.json" ]] \
  || fail "repository-owned symlink was not migrated to a regular JSON file"
"$python_bin" - "$overlay_home/repo-link.json" <<'PY'
import json, sys
with open(sys.argv[1]) as handle:
    value = json.load(handle)
assert value["feedbackSurveyState"] == {"lastShownTime": 42}
assert value["managed"] == {"extra": "legacy", "nested": 1, "list": [1]}
assert value["scalar"] == "new"
PY
pass "overlays preserve unmanaged legacy state through the real two-hop compatibility chain"

printf 'Testing Lazygit conflict handling and output validation\n'
link_fake_bin="$root/link-fake-bin"
link_home="$root/link-home"
mkdir -p "$link_fake_bin" "$link_home/.config/lazygit"
printf '#!/bin/sh\nprintf "%%s\\n" "$HOME/.config/lazygit"\n' > "$link_fake_bin/lazygit"
chmod +x "$link_fake_bin/lazygit"
printf 'preserve me\n' > "$link_home/.config/lazygit/config.yml"
link_env=(
  "HOME=$link_home"
  "PATH=$link_fake_bin:/usr/bin:/bin"
  "DOTFILES_BOOTSTRAP_TEST_ALLOW_WORKTREE=1"
)
if env "${link_env[@]}" zsh "$repo/scripts/bootstrap/link-lazygit-config.zsh" >/dev/null 2>&1; then
  fail "Lazygit linker replaced a conflict by default"
fi
grep -q 'preserve me' "$link_home/.config/lazygit/config.yml" \
  || fail "Lazygit conflict content changed"
env "${link_env[@]}" zsh "$repo/scripts/bootstrap/link-lazygit-config.zsh" --backup >/dev/null
[[ -L "$link_home/.config/lazygit/config.yml" ]] || fail "Lazygit backup mode did not create link"
backup_count="$(find "$link_home/.config/lazygit" -maxdepth 1 -name 'config.yml.bak.*' | wc -l | tr -d ' ')"
[[ "$backup_count" == 1 ]] || fail "Lazygit backup mode did not preserve exactly one timestamped copy"
env "${link_env[@]}" zsh "$repo/scripts/bootstrap/link-lazygit-config.zsh" --check >/dev/null
rm "$link_home/.config/lazygit/config.yml"
ln -s "$repo/lazygit_config.yml" "$link_home/.config/lazygit/config.yml"
if env "${link_env[@]}" zsh "$repo/scripts/bootstrap/link-lazygit-config.zsh" --check >/dev/null 2>&1; then
  fail "Lazygit check accepted an indirect compatibility link"
fi
env "${link_env[@]}" zsh "$repo/scripts/bootstrap/link-lazygit-config.zsh" >/dev/null
[[ "$(readlink "$link_home/.config/lazygit/config.yml")" == "$repo/config/lazygit/config.yml" ]] \
  || fail "Lazygit compatibility link was not normalized to a direct first hop"
rm "$link_home/.config/lazygit/config.yml"
printf 'replace me\n' > "$link_home/.config/lazygit/config.yml"
env "${link_env[@]}" zsh "$repo/scripts/bootstrap/link-lazygit-config.zsh" --force >/dev/null
[[ -L "$link_home/.config/lazygit/config.yml" ]] || fail "Lazygit force mode did not replace a file"
printf '#!/bin/sh\nprintf "/tmp/not-in-home\\n"\n' > "$link_fake_bin/lazygit"
if env "${link_env[@]}" zsh "$repo/scripts/bootstrap/link-lazygit-config.zsh" --check >/dev/null 2>&1; then
  fail "Lazygit linker accepted output outside HOME"
fi
pass "Lazygit conflicts refuse by default, backup/force are explicit, and command output is constrained"

printf 'Testing complete exception task with command fakes\n'
fake_bin="$root/fake-bin"
exception_home="$root/exception-home"
log="$root/commands.log"
defaults_state="$root/defaults-state"
mkdir -p "$fake_bin" "$exception_home/.config/mise"
"$python_bin" - "$repo" "$exception_home" <<'PY'
import os
from pathlib import Path
import sys, tomllib

repo, home = map(Path, sys.argv[1:])
with (repo / "mise.toml").open("rb") as handle:
    dotfiles = tomllib.load(handle)["dotfiles"]
for target_name, entry in dotfiles.items():
    source_name = entry if isinstance(entry, str) else entry["source"]
    target = home / target_name.removeprefix("~/")
    target.parent.mkdir(parents=True, exist_ok=True)
    os.symlink(repo / source_name, target)
PY

make_fake() {
  local name=$1 body=$2
  printf '#!/bin/sh\n%s\n' "$body" > "$fake_bin/$name"
  chmod +x "$fake_bin/$name"
}
make_fake mise 'printf "mise %s\n" "$*" >> "$BOOTSTRAP_TEST_LOG"'
make_fake lazygit 'printf "lazygit %s\n" "$*" >> "$BOOTSTRAP_TEST_LOG"; printf "%s\n" "$HOME/.config/lazygit"'
make_fake defaults '
printf "defaults %s\n" "$*" >> "$BOOTSTRAP_TEST_LOG"
case "$2" in
  read) [ -f "$BOOTSTRAP_DEFAULT_STATE" ] && { printf "1\n"; exit 0; }; exit 1 ;;
  write) : > "$BOOTSTRAP_DEFAULT_STATE" ;;
esac'
make_fake pgrep 'printf "pgrep %s\n" "$*" >> "$BOOTSTRAP_TEST_LOG"; exit 0'
make_fake killall 'printf "killall %s\n" "$*" >> "$BOOTSTRAP_TEST_LOG"'
ln -s "$python_bin" "$fake_bin/python3"

fake_path="$fake_bin:/usr/bin:/bin"
task_mise_env=(
  "HOME=$exception_home"
  "XDG_CONFIG_HOME=$exception_home/.config"
  "CODEX_HOME=$exception_home/.codex"
  "MISE_CONFIG_DIR=$root/task-mise/config"
  "MISE_DATA_DIR=$root/task-mise/data"
  "MISE_CACHE_DIR=$root/task-mise/cache"
  "MISE_STATE_DIR=$root/task-mise/state"
  "MISE_SYSTEM_CONFIG_FILE=$root/task-mise/system.toml"
  "MISE_GLOBAL_CONFIG_FILE=$exception_home/.config/mise/config.toml"
  "MISE_TRUSTED_CONFIG_PATHS=$repo:$exception_home/.config/mise/config.toml"
  "MISE_TASK_RUN_AUTO_INSTALL=false"
  "MISE_OFFLINE=true"
  "DOTFILES_BOOTSTRAP_TEST_ALLOW_WORKTREE=1"
  "DOTFILES_BOOTSTRAP_TEST_PLATFORM=darwin"
)
[[ -z "$ignored_config_paths" ]] || task_mise_env+=("MISE_IGNORED_CONFIG_PATHS=$ignored_config_paths")
run_bootstrap_task() {
  (
    cd "$root/work"
    run_clean_env "${task_mise_env[@]}" BOOTSTRAP_TEST_LOG="$log" \
      BOOTSTRAP_DEFAULT_STATE="$defaults_state" PATH="$fake_path" \
      "$mise_bin" run bootstrap >/dev/null
  )
}

: > "$log"
run_bootstrap_task
run_bootstrap_task

grep -q '^mise trust .*\.config/mise/config.toml$' "$log" \
  || fail "global trust exception was not exercised"
write_count="$(grep -c '^defaults -currentHost write ' "$log" || true)"
restart_count="$(grep -c '^killall SystemUIServer$' "$log" || true)"
[[ "$write_count" == 1 ]] || fail "macOS exception should write once across two converged runs"
[[ "$restart_count" == 1 ]] || fail "SystemUIServer should restart only after the changed write"
[[ -L "$exception_home/.config/lazygit/config.yml" ]] \
  || fail "dynamic Lazygit link was not created"
[[ -f "$exception_home/.agents/skills/.dotfiles-managed-skills" ]] \
  || fail "skill sync did not use temporary HOME"
[[ -f "$exception_home/.claude/settings.json" && ! -L "$exception_home/.claude/settings.json" ]] \
  || fail "Claude overlay was not written as app-owned JSON"
[[ -f "$exception_home/.config/karabiner/karabiner.json" && ! -L "$exception_home/.config/karabiner/karabiner.json" ]] \
  || fail "Karabiner overlay was not written as app-owned JSON"
"$python_bin" "$repo/scripts/bootstrap/json-overlay.py" --check \
  "$repo/config/claude/settings.json" "$exception_home/.claude/settings.json" >/dev/null
"$python_bin" "$repo/scripts/bootstrap/json-overlay.py" --check \
  "$repo/config/karabiner/karabiner.json" "$exception_home/.config/karabiner/karabiner.json" >/dev/null
pass "exception task is hermetic, idempotent, and avoids restarts when settings are unchanged"

printf 'Testing exception failure propagation\n'
: > "$log"
make_fake mise 'printf "mise %s\n" "$*" >> "$BOOTSTRAP_TEST_LOG"; exit 13'
if run_bootstrap_task >/dev/null 2>&1; then
  fail "bootstrap task hid a failing trust command"
fi
grep -q '^mise trust ' "$log" || fail "failing trust command was not exercised"
if grep -q '^lazygit ' "$log"; then
  fail "bootstrap continued to Lazygit after trust failed"
fi

make_fake mise 'printf "mise %s\n" "$*" >> "$BOOTSTRAP_TEST_LOG"'
rm -f "$defaults_state"
make_fake defaults '
printf "defaults %s\n" "$*" >> "$BOOTSTRAP_TEST_LOG"
case "$2" in
  read) exit 1 ;;
  write) exit 17 ;;
esac'
: > "$log"
if env HOME="$exception_home" BOOTSTRAP_TEST_LOG="$log" \
  BOOTSTRAP_DEFAULT_STATE="$defaults_state" PATH="$fake_path" \
  DOTFILES_BOOTSTRAP_TEST_ALLOW_WORKTREE=1 DOTFILES_BOOTSTRAP_TEST_PLATFORM=darwin \
  zsh "$repo/scripts/bootstrap/apply-macos-exceptions.zsh" >/dev/null 2>&1; then
  fail "macOS exception hid a failed defaults write"
fi
grep -q '^defaults -currentHost write ' "$log" || fail "failing defaults write was not exercised"
if grep -q '^killall ' "$log"; then
  fail "macOS exception restarted a process after a failed write"
fi
pass "trust and macOS preference failures stop before later side effects"

printf '\nAll isolated bootstrap checks passed with mise %s.\n' "$version"
