#!/usr/bin/env zsh
# Cross-reference requested Homebrew formulae with Atuin command history.
# Read-only: results are review hints, never removal instructions.
set -eu

DB="${ATUIN_HISTORY_DB:-$HOME/.local/share/atuin/history.db}"
THRESHOLD_DAYS="${1:-${THRESHOLD_DAYS:-120}}"

[[ "$THRESHOLD_DAYS" == <-> ]] || {
  print -u2 "usage: $0 [threshold-days]"
  exit 2
}
[[ -f "$DB" ]] || {
  print -u2 "Atuin history database not found: $DB"
  exit 1
}
command -v brew >/dev/null || { print -u2 "brew is required"; exit 1; }
command -v sqlite3 >/dev/null || { print -u2 "sqlite3 is required"; exit 1; }

now=$(date +%s)
formulae=("${(@f)$(brew leaves 2>/dev/null)}")

for formula in "${formulae[@]}"; do
  [[ -n "$formula" ]] || continue
  bins=("${(@f)$(brew list "$formula" 2>/dev/null |
    grep -E '/s?bin/[^/]+$' | sed 's#.*/##' | sort -u)}")
  (( ${#bins[@]} == 1 )) && [[ -z "${bins[1]}" ]] && continue

  newest=0
  for bin in "${bins[@]}"; do
    [[ -n "$bin" ]] || continue
    sql_bin="${bin//\'/\'\'}"
    timestamp=$(sqlite3 -readonly "$DB" \
      "SELECT IFNULL(MAX(timestamp), 0) FROM history
       WHERE command='$sql_bin' OR command LIKE '$sql_bin %';" 2>/dev/null)
    timestamp=$(( ${timestamp:-0} / 1000000000 ))
    (( timestamp > newest )) && newest=$timestamp
  done

  if (( newest == 0 )); then
    print "NEVER       $formula  (${(j:, :)bins})"
    continue
  fi

  days=$(( (now - newest) / 86400 ))
  if (( days >= THRESHOLD_DAYS )); then
    print "STALE ${days}d  $formula  (last $(date -r "$newest" +%Y-%m-%d))"
  fi
done | sort
