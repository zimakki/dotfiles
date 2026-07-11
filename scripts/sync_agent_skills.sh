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

discovery_skills=("${skill_dirs[@]}")
if command -v hunk >/dev/null 2>&1; then
  hunk_skill_file="$(hunk skill path 2>/dev/null || true)"
  if [[ -f "$hunk_skill_file" && "$(basename "$hunk_skill_file")" == "SKILL.md" ]]; then
    hunk_skill_dir="$(dirname "$hunk_skill_file")"
    if command -v brew >/dev/null 2>&1; then
      hunk_opt_dir="$(brew --prefix hunk 2>/dev/null || true)/libexec/skills/hunk-review"
      if [[ -f "$hunk_opt_dir/SKILL.md" && "$(realpath "$hunk_opt_dir")" == "$(realpath "$hunk_skill_dir")" ]]; then
        hunk_skill_dir="$hunk_opt_dir"
      fi
    fi
    discovery_skills+=("$hunk_skill_dir")
    pass "found Hunk's bundled hunk-review skill"
  else
    fail "hunk is installed but 'hunk skill path' did not return a SKILL.md"
  fi
else
  warn "hunk is not installed; skipping its bundled hunk-review skill"
fi

dest_roots=("$HOME/.agents/skills" "$HOME/.claude/skills" "${CODEX_HOME:-$HOME/.codex}/skills")
echo "Checking global discovery links"
for dest_root in "${dest_roots[@]}"; do
  if $fix; then mkdir -p "$dest_root"; fi
  manifest="$dest_root/.dotfiles-managed-skills"
  desired_names=()
  for skill in "${discovery_skills[@]}"; do
    desired_names+=("$(basename "$skill")")
  done

  if [[ -f "$manifest" ]]; then
    while IFS= read -r managed_name; do
      [[ -n "$managed_name" ]] || continue
      desired=false
      for desired_name in "${desired_names[@]}"; do
        if [[ "$managed_name" == "$desired_name" ]]; then
          desired=true
          break
        fi
      done
      $desired && continue

      obsolete="$dest_root/$managed_name"
      if [[ -L "$obsolete" ]]; then
        if $fix; then
          rm "$obsolete"
          pass "removed obsolete managed link $obsolete"
        else
          fail "obsolete managed skill link remains at $obsolete"
        fi
      elif [[ -e "$obsolete" ]]; then
        fail "obsolete managed skill path is no longer a symlink: $obsolete"
      fi
    done < "$manifest"
  fi

  for skill in "${discovery_skills[@]}"; do
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
  if $fix; then
    printf '%s\n' "${desired_names[@]}" | sort > "$manifest"
    pass "recorded managed skills in $manifest"
  elif [[ ! -f "$manifest" ]]; then
    fail "missing managed skill manifest $manifest; run with --fix"
  fi
done

echo "Audit complete: ${#skill_dirs[@]} canonical skills, ${#discovery_skills[@]} discoverable skills, $errors failures, $warnings warnings"
(( errors == 0 ))
