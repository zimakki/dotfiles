# dotfiles

This repository is the reproducible entry point for a macOS setup. It keeps
package inventory, runtimes, app configuration, shell configuration, macOS
preferences, and shared agent skills understandable without mirroring the
entire home directory.

## Repository map

| Path | Owns |
| --- | --- |
| `BrewFile` | The only Homebrew formula, cask, and Mac App Store inventory |
| `mise.toml` | Pinned mise tools, static dotfile destinations, and typed macOS defaults |
| `config/<app>/` | Canonical, app-oriented configuration sources |
| `scripts/bootstrap/` | Preflight, verification, and the few bootstrap exceptions |
| `scripts/maintenance/` | Explicit maintenance such as agent-skill synchronization |
| `.agents/skills/` | Vendor-neutral source for repo-managed agent skills |
| `tests/bootstrap/` | Bootstrap contract and isolated-machine tests |
| `docs/` | Current decisions, conventions, and runbooks |

Do not add root-level app config. Add it under `config/<app>/` and declare its
destination in `[dotfiles]` in `mise.toml`.

## Ownership model

- Plain, user-authored config is linked from `config/<app>/`.
- App-mutated JSON is merged into the live app-owned file. Claude and Karabiner
  use repository-owned overlays, preserving live keys the overlay does not
  manage.
- Opaque exports, caches, generated defaults, credentials, and app state stay
  outside Git. Track only intentional overrides.
- App-specific themes stay with their app because their schemas and loading
  rules differ.

`mise bootstrap` is the coordinator. It applies the canonical `BrewFile`
before tools, manages static links and typed defaults, then calls the narrow
exception scripts. Never run bootstrap from a secondary or disposable
worktree; preflight intentionally rejects it.

The architecture rationale is recorded in
[`docs/decisions/0001-app-oriented-config.md`](docs/decisions/0001-app-oriented-config.md)
and
[`docs/decisions/0002-safe-bootstrap.md`](docs/decisions/0002-safe-bootstrap.md).

## Fresh-machine setup

Install Xcode Command Line Tools, Homebrew, Git, and a mise version satisfying
`min_version` in `mise.toml`. Clone this repository at its canonical location,
then run:

```sh
scripts/bootstrap/preflight.zsh
mise trust ./mise.toml
mise bootstrap --dry-run
mise bootstrap

# Bootstrap links zshrc first; preserve it when installing Oh My Zsh.
[ -d ~/.oh-my-zsh ] || KEEP_ZSHRC=yes RUNZSH=no CHSH=no \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

mise bootstrap status
scripts/bootstrap/verify.zsh
```

Inspect every conflict before considering `--force-dotfiles`. The full capture,
recovery, and manual follow-up procedure is in
[`docs/runbooks/migrate-mac.md`](docs/runbooks/migrate-mac.md).

## Validate changes

Run the portable suite before committing:

```sh
scripts/ci_checks.sh
```

For a live-machine convergence check, run:

```sh
scripts/bootstrap/verify.zsh
```

Use the project-local `install-app`, `uninstall-app`, `cleanup-report`, and
`dotfiles-skill-linter` skills for routine maintenance. Agent skills are linked
into supported clients by `scripts/maintenance/sync-agent-skills.sh --fix`.

The shared visual target is Catppuccin Mocha, using Mauve where an app exposes
an accent choice.
