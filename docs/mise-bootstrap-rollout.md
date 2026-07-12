# Mise bootstrap live rollout

> **Status: completed 2026-07-12.** This is a historical rollout record, not the
> current setup guide. Use [`../README.md`](../README.md) and
> [`../MIGRATION.md`](../MIGRATION.md) for current operations. The true
> pre-merge commit for this rollout is `2d3dfbb`; a recovery branch created
> after merge does not provide that rollback point.

This is the recovery-first sequence for merging the bootstrap branch and then
applying it to the current Mac. Merging does not run Brew, mise bootstrap,
defaults, or installers. Existing symlinks mean a new shell will immediately
read the merged `zshenv` and `zshrc`, so keep the current terminal open until
the shell checks pass.

## Recovery anchor

Before merging, the recovery branch needed to point at the verified pre-merge
commit:

```sh
cd ~/code/zimakki/dotfiles
git branch backup/pre-mise-bootstrap 2d3dfbb
git rev-parse backup/pre-mise-bootstrap
defaults read > /tmp/defaults.before-mise-bootstrap
```

If a new zsh is unhealthy, stay in the existing terminal or start a clean Bash:

```sh
/bin/bash --noprofile --norc
cd ~/code/zimakki/dotfiles
git switch backup/pre-mise-bootstrap
```

Switching back restores the old tracked shell sources immediately. Do not delete
the backup branch until the rollout is complete.

## Staged rollout

Stop after any failed stage and fix forward before continuing.

### 1. Merge and test shell startup

Do not run bootstrap yet.

```sh
zsh -n ~/.zshenv ~/.zshrc
zsh -c  'command -v node; command -v python'
zsh -lc 'command -v node; command -v python'
```

Open one new terminal window. Keep the original window open. Both shell modes
should resolve Node and Python through mise shims.

### 2. Upgrade mise explicitly

The config requires mise >=2026.7.4. Upgrade it through Homebrew, verify the
version, and do not combine this step with bootstrap:

```sh
brew upgrade mise
mise --version
```

### 3. Apply static dotfiles only

```sh
mise trust ./mise.toml
mise bootstrap dotfiles apply --dry-run
mise bootstrap dotfiles apply
mise bootstrap dotfiles status --missing
```

Inspect conflicts. Do not use `--force-dotfiles` during the initial rollout.
Open another terminal and repeat the shell checks from stage 1.

### 4. Apply Brew and tools

```sh
brew bundle check --file=BrewFile
mise bootstrap --dry-run --only tools
mise bootstrap --only tools
mise exec -- node --version
mise exec -- python --version
mise exec -- elixir --version
```

The tools phase runs the canonical BrewFile hook before compiling tools.

### 5. Apply macOS defaults

Review the commands before applying:

```sh
mise bootstrap macos defaults apply --dry-run
mise bootstrap macos defaults apply
mise bootstrap macos defaults status --missing
```

The pre-rollout defaults snapshot is the comparison point if a preference needs
to be restored.

### 6. Apply explicit exceptions

This stage creates the dynamic Lazygit link, syncs skills, trusts the global mise
config symlink, writes the host-scoped battery preference, and restarts Finder,
Dock, and SystemUIServer.

```sh
mise run bootstrap
```

### 7. Verify convergence

```sh
mise bootstrap status
scripts/verify_setup.sh
scripts/ci_checks.sh
```

Run the status and verification a second time. When both passes are clean and
normal terminal use is stable, delete the recovery branch:

```sh
git branch -d backup/pre-mise-bootstrap
```
