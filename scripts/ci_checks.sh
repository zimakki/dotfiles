#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo"

section() { printf '\n==> %s\n' "$1"; }
need() {
	command -v "$1" >/dev/null 2>&1 || {
		printf 'Missing required CI tool: %s\n' "$1" >&2
		exit 1
	}
}

need git
need python3
need ruby
need shellcheck
need zsh

section "Shell syntax"
while IFS= read -r file; do
	[[ -f "$file" ]] || continue
	case "$(basename "$file")" in
	zshenv|zprofile|zshrc) zsh -n "$file" ;;
	*)
		case "$(head -n 1 "$file")" in
		*'/zsh' | *'/env zsh') zsh -n "$file" ;;
		*'/bash' | *'/env bash') bash -n "$file" ;;
		*'/sh') sh -n "$file" ;;
		esac
		;;
	esac
done < <(git ls-files '*.sh' '*.zsh' 'zshenv' 'zprofile' 'zshrc' '*/zshenv' '*/zprofile' '*/zshrc')

section "ShellCheck"
while IFS= read -r file; do
	[[ -f "$file" ]] || continue
	case "$(head -n 1 "$file")" in
	*'/bash' | *'/env bash' | *'/sh') shellcheck --severity=warning "$file" ;;
	esac
done < <(git ls-files '*.sh')

section "JSON and TOML syntax"
python3 - <<'PY'
import json
import pathlib, subprocess
import tomllib

tracked = subprocess.check_output(
    ["git", "ls-files", "-z", "--", "*.json", "*.toml"]
).split(b"\0")
for raw_path in filter(None, tracked):
    path = pathlib.Path(raw_path.decode())
    if not path.is_file():
        continue
    if path.suffix == ".json":
        json.loads(path.read_text(), parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))
    elif path.suffix == ".toml":
        tomllib.loads(path.read_text())
PY

section "Python syntax"
python3 - <<'PY'
import pathlib, subprocess

tracked = subprocess.check_output(["git", "ls-files", "-z", "--", "*.py"]).split(b"\0")
for raw_path in filter(None, tracked):
    path = pathlib.Path(raw_path.decode())
    if not path.is_file():
        continue
    compile(path.read_text(), str(path), "exec")
PY

section "Bootstrap ownership contract"
python3 tests/bootstrap/config_contract.py

section "Isolated bootstrap behavior"
tests/bootstrap/isolated.sh

section "YAML syntax"
paths="$(git ls-files -z -- '*.yaml' '*.yml' | ruby -e 'STDOUT.write(STDIN.read.split("\0").reject(&:empty?).join("\n"))')"
TRACKED_YAML="$paths" ruby - <<'RUBY'
require "yaml"

ENV.fetch("TRACKED_YAML", "").lines(chomp: true).each do |path|
  next unless File.file?(path)
  YAML.safe_load(File.read(path), permitted_classes: [], aliases: true, filename: path)
end
RUBY

section "Brewfile syntax"
ruby -c BrewFile

section "Cross-agent skills and discovery"
temp_home="$(mktemp -d)"
trap 'rm -rf "$temp_home"' EXIT
HOME="$temp_home" CODEX_HOME="$temp_home/.codex" \
	DOTFILES_BOOTSTRAP_TEST_ALLOW_WORKTREE=1 scripts/maintenance/sync-agent-skills.sh --fix
HOME="$temp_home" CODEX_HOME="$temp_home/.codex" scripts/maintenance/sync-agent-skills.sh

printf '\nAll repository checks passed.\n'
