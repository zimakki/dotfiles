# Dotfiles Migration Plan (old Mac → new Mac)

This branch (`chore/curate-dotfiles-for-new-mac`) curates the dotfiles on the
**new** MacBook: runtimes moved to mise, the Brewfile pruned, the zshrc cleaned
up, and a leaked secret removed.

**Before installing anything on the new machine**, run **Phase 1** on the
**old** machine to capture anything still needed that pruning may have dropped.

> You can hand this file to Claude on the old machine:
> "Read MIGRATION.md and walk me through Phase 1."

---

## Git flow (do in this order)

1. **New machine** (done): work committed on `chore/curate-dotfiles-for-new-mac`, pushed, PR opened.
2. **Old machine**: `git fetch && git checkout chore/curate-dotfiles-for-new-mac`, run **Phase 1**, commit + push.
3. **New machine**: `git pull`, run **Phase 2** (install).
4. Merge the PR once both machines are happy.

## Safety rules (read first)

- **Phase 1 is capture-only and NON-DESTRUCTIVE.** It only reads what's installed.
- **NEVER run `brew bundle cleanup`** — it uninstalls anything not in the Brewfile, including commented-out lines.
- **NEVER run `brew bundle dump --force` onto `BrewFile`** — it overwrites the curated file (and all the explanatory comments). Always dump to a temp file.
- This is **diff-and-decide**, not blind re-merge. The Brewfile was pruned on purpose; only add back what you actually want.
- **`mise` owns `node` and `python`** now. Do not re-add them to the Brewfile. On the old machine, also remove the brew `node`/`python` to stop the version conflict.

---

## Phase 1 — OLD machine: capture what's missing

```sh
cd <path-to>/dotfiles
git fetch && git checkout chore/curate-dotfiles-for-new-mac
```

### 1a. Snapshot installed Homebrew packages (to a TEMP file)

```sh
brew bundle dump --file=/tmp/Brewfile.oldmac --force --describe
```

### 1b. Diff against the curated Brewfile

```sh
# items installed on old machine but NOT active in the curated Brewfile:
comm -23 \
  <(grep -oE '^(brew|cask) "[^"]+"' /tmp/Brewfile.oldmac | sort -u) \
  <(grep -oE '^(brew|cask) "[^"]+"' BrewFile | sort -u)
```

For each result, decide: **do I want this on the new machine?**
- Yes → uncomment it in `BrewFile` (if it's a commented line) or add a new line.
- No → leave it out.
- Remember the intentional removals: `node`, `python@*` (→ mise), redundant
  monitors, media libs, embedded/Nerves tools, emacs, etc. Don't blindly re-add.

### 1c. Capture non-Homebrew tools (NONE of these live in the Brewfile)

Run each, note anything you want reproduced, and decide where it belongs
(mise / `npm -g` / a setup script / etc.):

```sh
mise ls --global                 # global runtimes — compare to ~/.config/mise/config.toml
npm  ls -g --depth=0 2>/dev/null # global npm packages
pnpm ls -g 2>/dev/null           # global pnpm packages
pipx list 2>/dev/null            # pipx apps
cargo install --list 2>/dev/null # cargo binaries
ls ~/go/bin 2>/dev/null          # go install binaries
ls ~/.mix/escripts ~/.cache/rebar3/bin 2>/dev/null  # elixir/erlang escripts
code --list-extensions 2>/dev/null                  # VS Code extensions
```

### 1d. Capture configs/dotfiles not yet tracked in this repo

Compare the `LINKS` manifest in `setup_sim_links.zsh` against what configs you
actually rely on. Notable gaps to consider adding to the repo:

- `~/.config/mise/config.toml` — global runtime versions (created on the new
  machine but **not yet symlinked from this repo**; worth adding + a LINKS entry).
- Neovim config — `NVIM_APPNAME=astronvim_v5`; confirm that config is its own
  repo and is pushed.
- Anything under `~/.config` you use that isn't in `LINKS`.

**Do NOT commit secrets:** `~/.zsh_secrets`, `~/.ssh/*`, 1Password data, or any
file containing tokens/keys.

### 1e. Commit & push from the OLD machine

```sh
git add -A
git commit -m "Capture old-machine packages/tools"
git push
```

---

## Phase 2 — NEW machine: install (after Phase 1 is merged/pulled)

**Order matters** — build deps must exist before mise compiles erlang/elixir,
and lazygit must exist before the symlink script runs.

```sh
cd ~/code/zimakki/dotfiles
git pull

# 1. oh-my-zsh (not a brew package; required by zshrc line ~92)
KEEP_ZSHRC=yes RUNZSH=no CHSH=no \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# 2. Homebrew packages (also provides erlang build deps + lazygit)
brew bundle --file=~/code/zimakki/dotfiles/BrewFile

# 3. Language runtimes via mise (erlang/elixir compile from source here)
mise install        # uses ~/.config/mise/config.toml

# 4. Symlink dotfiles into place (backs up existing files to *.bak)
./setup_sim_links.zsh

# 5. Open a fresh shell and confirm there are no startup errors
```

### Post-install manual bits

- **Rotate the leaked `LIVE_BEATS` GitHub OAuth secret** — it was removed from
  the file but remains in git history, so it is still compromised.
- **1Password CLI**: `op signin` (and add your account) so the guarded
  `OPENAI_API_KEY` fetch works. Until then it skips silently.
- **Postgres.app**: launch it once, then create the Phoenix role if needed:
  `createuser -s postgres` (or set creds in each app's `dev.exs`).

---

## Quick reference — what changed on this branch

| Area | Change |
|------|--------|
| Runtimes | `node`/`python` removed from Brewfile → managed by mise (`~/.config/mise/config.toml`: node 22.12.0, python 3.13, elixir 1.18.3-otp-27, erlang 27.3.3) |
| Brewfile | Pruned monitors/disk/media/embedded/unused CLIs (commented out); dropped emacs tap, arc, arduino-ide; postgresql@14 → Postgres.app; added starship/atuin/television/zsh-autosuggestions |
| zshrc | Removed tmux/run_iex/yazi/emacs/doom; commented unidentified `entire`; guarded atuin env + 1Password fetch; source zsh-syntax-highlighting last; removed leaked secret |
| Files | Deleted orphaned `cmux_dev_layout.sh` |
