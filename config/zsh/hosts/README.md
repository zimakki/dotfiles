# Per-machine zsh config

Each computer sharing this repo may have a file named after its **LocalHostName**:

    config/zsh/hosts/<LocalHostName>.zsh

Find a machine's key with:

    scutil --get LocalHostName

`config/zsh/zshenv` sources `config/zsh/hosts/<LocalHostName>.zsh` if it exists
(runs for every shell, so it's the environment layer — PATH, exports). Missing
file = no-op, so a fresh machine needs no bootstrap.

## Rules
- **NO SECRETS.** These files are committed. Secrets flow through 1Password.
- Presence-based tool dirs (a path that may or may not exist) belong in the
  guarded `path` array in `zshenv`, not here — that already self-heals per machine.
- Use this file only for *deliberate* per-machine intent (a proxy, a machine-only
  toolchain, an override).
- **If you rename the Mac's LocalHostName, rename its host file to match** —
  otherwise the loader silently stops sourcing it (missing file is a clean no-op,
  so there is no error to alert you).

## Current machines
- `zis-AccessOwl-MacBook-Pro` — macOS 26.5.2
- `zis-MacBook-Pro` — macOS
