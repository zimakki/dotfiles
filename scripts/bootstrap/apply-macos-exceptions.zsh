#!/usr/bin/env zsh
# Host-scoped macOS preferences that mise cannot represent declaratively.
set -eu
setopt pipe_fail

REPO="${0:A:h:h:h}"
source "$REPO/scripts/bootstrap/preflight.zsh"

check=false
case "${1:-}" in
  "") ;;
  --check) check=true ;;
  -h|--help)
    print "usage: $0 [--check]"
    exit 0
    ;;
  *)
    print -u2 -- "usage: $0 [--check]"
    exit 2
    ;;
esac
(( $# <= 1 )) || {
  print -u2 -- "usage: $0 [--check]"
  exit 2
}

platform="${DOTFILES_BOOTSTRAP_TEST_PLATFORM:-$OSTYPE}"
if [[ "$platform" != darwin* ]]; then
  print "Skipping macOS preference exceptions on $platform."
  exit 0
fi

domain=com.apple.controlcenter
key=BatteryShowPercentage
current="$(defaults -currentHost read "$domain" "$key" 2>/dev/null || true)"
case "${current:l}" in
  1|true|yes) desired=true ;;
  *) desired=false ;;
esac

if $desired; then
  print "macOS host preference is already current: $domain $key"
  exit 0
fi

if $check; then
  print -u2 -- "macOS host preference drift: $domain $key should be true"
  exit 1
fi

bootstrap_require_canonical_checkout "$REPO"
defaults -currentHost write "$domain" "$key" -bool true

verified="$(defaults -currentHost read "$domain" "$key")"
case "${verified:l}" in
  1|true|yes) ;;
  *)
    print -u2 -- "macOS preference write did not persist: $domain $key"
    exit 1
    ;;
esac

# This host-scoped setting is owned by SystemUIServer. Finder and Dock are not
# restarted here: doing so on every converged bootstrap is disruptive, and the
# declarative mise defaults do not require this exception script to succeed.
if command -v pgrep >/dev/null 2>&1 && pgrep -x SystemUIServer >/dev/null 2>&1; then
  killall SystemUIServer
  print "Applied $domain $key and restarted SystemUIServer."
else
  print "Applied $domain $key; SystemUIServer was not running."
fi
