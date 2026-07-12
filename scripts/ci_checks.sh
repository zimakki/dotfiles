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
	case "$(head -n 1 "$file")" in
	*'/zsh' | *'/env zsh') zsh -n "$file" ;;
	*'/bash' | *'/env bash') bash -n "$file" ;;
	*'/sh') sh -n "$file" ;;
	esac
done < <(git ls-files '*.sh' '*.zsh' zshenv zshrc)

section "ShellCheck"
while IFS= read -r file; do
	case "$(head -n 1 "$file")" in
	*'/bash' | *'/env bash' | *'/sh') shellcheck --severity=warning "$file" ;;
	esac
done < <(git ls-files '*.sh')

section "JSON and TOML syntax"
python3 - <<'PY'
import json
import pathlib
import tomllib

for path in pathlib.Path(".").rglob("*"):
    if not path.is_file() or ".git" in path.parts:
        continue
    if path.suffix == ".json":
        json.loads(path.read_text(), parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))
    elif path.suffix == ".toml":
        tomllib.loads(path.read_text())
PY

section "Bootstrap ownership contract"
python3 scripts/test_bootstrap_config.py

section "Isolated bootstrap behavior"
scripts/test_bootstrap_isolated.sh

section "YAML syntax"
ruby - <<'RUBY'
require "yaml"

Dir.glob("**/*.{yaml,yml}", File::FNM_DOTMATCH).reject { |path| path.start_with?(".git/") }.each do |path|
  YAML.safe_load(File.read(path), permitted_classes: [], aliases: true, filename: path)
end
RUBY

section "Brewfile syntax"
ruby -c BrewFile

section "Exception manifest sources"
missing=0
while IFS= read -r source; do
	if [[ ! -e "$source" ]]; then
		printf 'Missing source referenced by setup_sim_links.zsh: %s\n' "$source" >&2
		missing=1
	fi
done < <(sed -n 's/^[[:space:]]*"\([^:"]*\):.*"$/\1/p' setup_sim_links.zsh)
((missing == 0))

section "Cross-agent skills and discovery"
temp_home="$(mktemp -d)"
trap 'rm -rf "$temp_home"' EXIT
HOME="$temp_home" CODEX_HOME="$temp_home/.codex" scripts/sync_agent_skills.sh --fix
HOME="$temp_home" CODEX_HOME="$temp_home/.codex" scripts/sync_agent_skills.sh

printf '\nAll repository checks passed.\n'
