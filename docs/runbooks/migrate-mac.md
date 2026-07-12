# Migrate a Mac

Use this runbook to capture intentional state from an old Mac and restore it on
a new one. Run capture work in a separate Git worktree; run bootstrap only from
the canonical checkout that will remain on disk.

## Safety gates

- Never run `brew bundle cleanup --force`.
- Never overwrite `BrewFile` with `brew bundle dump --force`; dump to `/tmp`.
- Never apply bootstrap from a secondary or disposable worktree.
- Never force a dotfile conflict until the live file has been reviewed.
- Never commit credentials, opaque exports, caches, databases, or automatic
  backups.

## One-time app-oriented layout cutover

Existing machines initially have HOME links aimed at the former root-level
sources. Close Claude and Karabiner, update the canonical checkout, and leave
the root compatibility links and app-local `*.legacy.json` snapshots in place.
Then run the normal bootstrap. Its exception task:

1. rewrites repo-owned indirect static links to direct `config/<app>/` sources;
2. normalizes Lazygit's link to a direct first hop; and
3. merges the Claude and Karabiner overlays into regular app-owned HOME files,
   using the distinct legacy snapshots to preserve unmanaged pre-cutover keys.

Check the cutover explicitly:

```sh
python3 scripts/bootstrap/relink-static-config.py --check
scripts/bootstrap/link-lazygit-config.zsh --check
test ! -L ~/.claude/settings.json
test ! -L ~/.config/karabiner/karabiner.json
scripts/bootstrap/verify.zsh
```

Run verification twice. Delete the root compatibility links and legacy
snapshots only in a later commit, after every managed machine passes these
checks; mise itself considers an indirect chain converged and therefore cannot
prove that those anchors are removable.

## 1. Capture the old Mac

Create a migration branch in a separate worktree. This keeps edits away from
the checkout backing live symlinks:

```sh
cd <canonical-dotfiles-checkout>
git fetch origin
git worktree add ../dotfiles-migration -b migration/<name>
cd ../dotfiles-migration
```

Snapshot Homebrew inventory to a temporary file and compare it with the curated
manifest:

```sh
brew bundle dump --file=/tmp/Brewfile.oldmac --force --describe
comm -23 \
  <(rg -o '^(brew|cask) "[^"]+"' /tmp/Brewfile.oldmac | sort -u) \
  <(rg -o '^(brew|cask) "[^"]+"' BrewFile | sort -u)
```

Review each difference; do not blindly merge it. `BrewFile` may intentionally
omit old tools, while Homebrew dependency kegs may still be required by active
packages. Run `scripts/maintenance/audit-cli-usage.zsh` for the tested
Atuin/Homebrew stale-CLI report, and use the `cleanup-report` skill for
unused-app, orphaned-dependency, and config-directory analysis.

Capture other intentional state:

```sh
mise ls --global
npm ls -g --depth=0 2>/dev/null
pnpm ls -g 2>/dev/null
pipx list 2>/dev/null
cargo install --list 2>/dev/null
command -v mas >/dev/null && mas list
code --list-extensions 2>/dev/null
find ~/.config -maxdepth 3 -type f -mtime -30 2>/dev/null | sort
mise bootstrap status --json
```

Classify config using
[`../decisions/0001-app-oriented-config.md`](../decisions/0001-app-oriented-config.md).
New stable text config belongs under `config/<app>/` with a `[dotfiles]` entry.
Do not capture opaque or generated app state.

Claude and Karabiner use repository-owned JSON overlays rather than whole-file
links. Add only keys that should be enforced to `config/<app>/`; app-written
dictionary keys absent from the overlay remain live and untracked. Managed
lists and scalar values replace their live counterparts, so review those values
carefully. Check convergence without writing with:

```sh
python3 scripts/bootstrap/json-overlay.py --check \
  config/claude/settings.json ~/.claude/settings.json
python3 scripts/bootstrap/json-overlay.py --check \
  config/karabiner/karabiner.json ~/.config/karabiner/karabiner.json
```

During the first migration, the overlay tool can replace a symlink that points
back into this repository after preserving its JSON content. It refuses an
arbitrary external symlink.

For macOS preferences, add only settings that were deliberately changed and
that mise can express as typed values. When a setting is unknown, capture
`defaults read` before and after toggling it, diff the snapshots, and confirm
the responsible key. Keep unsupported host-scoped writes in the bootstrap
exception script; do not turn an entire defaults domain into a manifest.

Review every staged path explicitly before committing and merging the migration
branch. Use `git status` and add named paths; do not use `git add -A` around
home-directory captures.

## 2. Prepare recovery on the new Mac

Install Xcode Command Line Tools, Homebrew, Git, and a mise version satisfying
`min_version` in `mise.toml`. Clone the reviewed repository at its permanent
canonical path.

Keep the current terminal open during setup. Before applying preferences, make
a comparison snapshot and create a branch at the known-good Git revision:

```sh
git branch backup/pre-bootstrap HEAD
git rev-parse HEAD
defaults read > /tmp/defaults.before-dotfiles
scripts/bootstrap/preflight.zsh
```

Preflight must pass before continuing.

## 3. Preview and apply

```sh
mise trust ./mise.toml
mise bootstrap --dry-run
mise bootstrap

[ -d ~/.oh-my-zsh ] || KEEP_ZSHRC=yes RUNZSH=no CHSH=no \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

mise bootstrap status
scripts/bootstrap/verify.zsh
```

Open one new terminal only after verification passes. Confirm the prompt,
history search, completions, and mise-managed commands work in both shell modes:

```sh
zsh -c 'command -v node; command -v python'
zsh -lc 'command -v node; command -v python'
scripts/bootstrap/verify.zsh
```

Approve required macOS prompts and sign in to credential-backed tools manually.
Typical checks include Karabiner input monitoring, 1Password CLI sign-in, and
launching Postgres.app once if it is used.

After both verification passes and normal use are stable, remove the temporary
recovery branch with `git branch -d backup/pre-bootstrap`.

## Recover from a failed apply

Stop after the first failed stage and keep the existing terminal open. If zsh
startup is unhealthy, use a clean Bash without reading shell config:

```sh
/bin/bash --noprofile --norc
```

From the canonical checkout, compare against the recorded known-good revision
and fix forward. If a reviewed recovery branch already exists, switching the
canonical checkout back to it restores linked source content immediately.
Never remove or recreate a conflicting live file until its contents have been
saved and compared.

For a macOS preference regression, compare the current `defaults read` output
with `/tmp/defaults.before-dotfiles` and restore only understood keys. Removing
a declaration from `mise.toml` does not restore the previous live preference.

Re-run `mise bootstrap status` and `scripts/bootstrap/verify.zsh` twice after a
fix. Remove `backup/pre-bootstrap` and temporary snapshots only after normal
use is stable.
