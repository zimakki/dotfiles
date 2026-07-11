#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="$repo/.agents/skills"
agents_file="$repo/AGENTS.md"
claude_file="$repo/CLAUDE.md"
fix=false

if [[ "${1:-}" == "--fix" ]]; then
  fix=true
elif [[ $# -gt 0 ]]; then
  echo "usage: $0 [--fix]" >&2
  exit 2
fi

errors=0
warnings=0
pass() { printf '  OK   %s\n' "$1"; }
warn() { printf '  WARN %s\n' "$1"; warnings=$((warnings + 1)); }
fail() { printf '  FAIL %s\n' "$1"; errors=$((errors + 1)); }

[[ -d "$source_root" ]] || { echo "Missing $source_root" >&2; exit 1; }

echo "Validating shared project instructions"
[[ -f "$agents_file" ]] && pass "$agents_file" || fail "missing $agents_file"
[[ -f "$claude_file" ]] && pass "$claude_file" || fail "missing $claude_file"
if [[ -f "$claude_file" ]]; then
  if grep -Eq '^[[:space:]]*@AGENTS\.md[[:space:]]*$' "$claude_file"; then
    pass "CLAUDE.md imports AGENTS.md"
  else
    fail "CLAUDE.md must import AGENTS.md with a standalone @AGENTS.md line"
  fi
fi
if [[ -f "$agents_file" ]]; then
  if grep -Eq '^[[:space:]]*@[[:graph:]]+\.md([[:space:]]|$)' "$agents_file"; then
    fail "AGENTS.md should not import markdown files; keep it canonical and non-recursive"
  else
    pass "AGENTS.md stays canonical and non-recursive"
  fi
fi

skill_dirs=()
while IFS= read -r -d '' skill; do skill_dirs+=("$skill"); done < <(
  find "$source_root" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z
)

echo "Validating canonical skills in $source_root"
for skill in "${skill_dirs[@]}"; do
  name="$(basename "$skill")"
  file="$skill/SKILL.md"
  if [[ ! -f "$file" ]]; then
    fail "$name has no SKILL.md"
    continue
  fi
  if [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ || ${#name} -gt 64 ]]; then
    fail "$name is not a valid skill directory name"
  fi
  declared="$(sed -n 's/^name:[[:space:]]*//p' "$file" | head -1)"
  description="$(sed -n 's/^description:[[:space:]]*//p' "$file" | head -1)"
  [[ "$declared" == "$name" ]] && pass "$name metadata" || fail "$name declares name '$declared'"
  [[ -n "$description" ]] || fail "$name has no description"
  [[ $(wc -l < "$file") -le 500 ]] || warn "$name/SKILL.md exceeds 500 lines; use progressive disclosure"
done

dest_roots=("$HOME/.agents/skills" "$HOME/.claude/skills" "${CODEX_HOME:-$HOME/.codex}/skills")
echo "Checking global discovery links"
for dest_root in "${dest_roots[@]}"; do
  if $fix; then mkdir -p "$dest_root"; fi
  for skill in "${skill_dirs[@]}"; do
    name="$(basename "$skill")"
    dest="$dest_root/$name"
    resolved_dest="$(realpath "$dest" 2>/dev/null || true)"
    if [[ -L "$dest" && "$resolved_dest" == "$(realpath "$skill")" ]]; then
      pass "$dest"
      continue
    fi
    if ! $fix; then
      fail "$dest is not linked to $skill"
      continue
    fi
    if [[ -e "$dest" || -L "$dest" ]]; then
      backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
      mv "$dest" "$backup"
      warn "backed up unmanaged $dest to $backup"
    fi
    ln -s "$skill" "$dest"
    pass "linked $dest"
  done
done

echo "Audit complete: ${#skill_dirs[@]} canonical skills, $errors failures, $warnings warnings"
(( errors == 0 ))
