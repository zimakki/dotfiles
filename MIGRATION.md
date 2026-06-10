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

### 1c. Flag CLIs you haven't used in a while (usage audit)

Pruning by memory is hard. This cross-references each installed Homebrew CLI
against your **atuin** shell history to surface tools you haven't actually run
recently — strong candidates to leave off the new machine.

```sh
DB="$HOME/.local/share/atuin/history.db"   # atuin history database
THRESHOLD_DAYS=120                          # tune to taste
now=$(date +%s)

for f in $(brew leaves); do
  # executables this formula actually provides (command name != formula name)
  bins=$(brew list "$f" 2>/dev/null | grep -E '/s?bin/[^/]+$' | sed 's#.*/##' | sort -u)
  [ -z "$bins" ] && continue

  newest=0
  for b in $bins; do
    ts=$(sqlite3 "$DB" \
      "SELECT IFNULL(MAX(timestamp),0) FROM history
         WHERE command='$b' OR command LIKE '$b %';" 2>/dev/null)
    ts=$(( ${ts:-0} / 1000000000 ))         # atuin stores nanoseconds
    [ "$ts" -gt "$newest" ] && newest=$ts
  done

  if [ "$newest" -eq 0 ]; then
    echo "NEVER       $f  ($bins)"
  else
    days=$(( (now - newest) / 86400 ))
    [ "$days" -ge "$THRESHOLD_DAYS" ] && echo "STALE ${days}d  $f  (last $(date -r "$newest" +%Y-%m-%d))"
  fi
done | sort
```

Anything printed `NEVER` or `STALE` is a candidate to comment out / leave off
the new machine. **Review the list, don't auto-remove** — important caveats:

- **Indirect use doesn't show up.** Tools invoked by your editor, scripts, git
  hooks, or pulled in as build deps/libraries (e.g. `fd` via a nvim picker,
  `pkg-config`, `openssl@3`, `coreutils`) won't appear in interactive history
  even though they're needed. Keep libraries/build deps regardless.
- **History only reaches as far back as atuin does** — a useful tool you last
  ran before adopting atuin can look stale.
- **GUI casks aren't covered** — this audits CLI formulae only.
- Name≠command is handled (we read each formula's real `bin/`); formulae that
  install nothing into bin are skipped.

(No atuin on the old machine? Point `$DB` logic at `~/.zsh_history` instead —
it needs `EXTENDED_HISTORY` timestamps to be useful.)

### 1d. Make sure the apps you use are in the Brewfile

Find which GUI apps you actually use on the old Mac, then confirm each is a
`cask` in the Brewfile.

**Best signal — `knowledgeC.db`** (macOS's on-device activity database, the one
Screen Time reads). It logs real app *usage* with timestamps, independent of how
you launch apps (Raycast, Dock, Finder — all counted). The terminal needs **Full
Disk Access** first: System Settings → Privacy & Security → Full Disk Access →
add your terminal app.

```sh
DB="$HOME/Library/Application Support/Knowledge/knowledgeC.db"
sqlite3 "$DB" "
SELECT ZVALUESTRING AS app,
       COUNT(*) AS uses,
       datetime(MAX(ZSTARTDATE)+978307200,'unixepoch','localtime') AS last_used
FROM ZOBJECT
WHERE ZSTREAMNAME='/app/usage'
GROUP BY app ORDER BY uses DESC LIMIT 40;"
```

Returns bundle IDs (`com.google.Chrome`, …) ranked by usage. (Swap
`/app/usage` for `/app/inFocus` to rank by focus time instead.)

**Raycast is itself a ranking.** Raycast orders "Search Applications" by your own
frecency, so the top of that list *is* your most-used apps — a quick manual
cross-check. (Its store under `~/Library/Application Support/com.raycast.macos/`
is undocumented, so use the visible ordering rather than querying it.)

**Dock keepers** — deliberate, always-wanted apps:

```sh
defaults read com.apple.dock persistent-apps \
  | grep -o '"file-label"[^;]*' | sed 's/.*= //'
```

**No Full Disk Access?** Recently-touched prefs are a rough proxy for recent use:

```sh
ls -lt ~/Library/Preferences/*.plist ~/Library/Containers 2>/dev/null | head -40
```

> Skip `mdls -name kMDItemUseCount/kMDItemLastUsedDate` — those LaunchServices
> attributes are unreliable on modern macOS (often empty/stale), whatever the
> launcher.

Then, for each frequently-used app **not** already in the Brewfile:

```sh
brew search --cask "<app name>"     # find the cask token
# then add to BrewFile:  cask "<token>"
```

**Mac App Store apps** won't show under brew — capture them with `mas`:

```sh
brew install mas      # if needed
mas list              # App Store apps + their IDs
# add to BrewFile:  brew "mas"  and  mas "App Name", id: 1234567890
```

> **If none of these produce a useful list** (Full Disk Access denied,
> `knowledgeC.db` empty/locked, etc.), ask Claude to research current
> alternatives and adapt — e.g. `log show` launch events, `lsappinfo`, the
> CoreDuet / Screen Time `RMAdminStore`, Raycast's own store, or a third-party
> usage tool. These methods drift across macOS versions, so verify against your
> machine rather than assuming.

Not everything is on Homebrew; a few apps you'll still install manually.

### 1e. Capture non-Homebrew tools (NONE of these live in the Brewfile)

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

### 1f. Capture configs/dotfiles not yet tracked in this repo

Compare the `LINKS` manifest in `setup_sim_links.zsh` against what configs you
actually rely on. Notable gaps to consider adding to the repo:

- `~/.config/mise/config.toml` — global runtime versions. Now **tracked** in
  this repo as `mise_config.toml` and symlinked via `setup_sim_links.zsh`.
- Neovim config — `NVIM_APPNAME=astronvim_v5`; confirm that config is its own
  repo and is pushed.
- Ghostty terminal — already tracked (`ghostty_config` → `~/.config/ghostty/config`);
  just make sure the old Mac's version is committed.
- Anything under `~/.config` you use that isn't in `LINKS`.

**Do NOT commit secrets:** `~/.zsh_secrets`, `~/.ssh/*`, 1Password data, or any
file containing tokens/keys.

**Karabiner-Elements (keyboard config).** The cask is already in the Brewfile,
so only the config needs capturing. On the OLD machine, copy it into the repo (a
symlink entry already exists in `setup_sim_links.zsh`):

```sh
cp ~/.config/karabiner/karabiner.json karabiner.json
# optional: custom complex-modification rule files you authored
# cp -R ~/.config/karabiner/assets/complex_modifications ./karabiner_complex_modifications
```

Commit it (step 1f). On the new machine, `setup_sim_links.zsh` symlinks
`karabiner.json` → `~/.config/karabiner/karabiner.json` and Karabiner picks it up
on launch.

> Caveat: Karabiner rewrites `karabiner.json` whenever you change settings in its
> UI. With the symlink that's normally fine (it writes in place), but if Karabiner
> ever replaces the symlink with a real file, just re-run `setup_sim_links.zsh` to
> re-link. Never track `~/.config/karabiner/automatic_backups/`.

**macOS system settings (keyboard, function keys, etc.).** These get captured
into `macos_defaults.sh` (applied once on the new Mac in Phase 2). macOS has no
"diff from default", so add only the settings you actually changed. On the OLD Mac:

1. Read current values and append a `defaults write` line for each to
   `macos_defaults.sh`. Starting points:
   ```sh
   defaults read -g com.apple.keyboard.fnState   # F1/F2 as standard function keys
   defaults read -g InitialKeyRepeat             # key-repeat delay (already seeded)
   defaults read -g KeyRepeat                     # key-repeat rate  (already seeded)
   defaults read -g | less                        # browse all global-domain tweaks
   defaults read com.apple.finder | less          # Finder settings
   defaults read com.apple.dock   | less          # Dock settings
   ```
   `macos_defaults.sh` already has commented Finder/Dock templates — uncomment
   the ones you use and set them to your old-Mac values.
2. To find the key behind a System Settings toggle you don't know, use the
   before/after diff:
   ```sh
   defaults read > /tmp/before.txt
   # ...flip the toggle in System Settings...
   defaults read > /tmp/after.txt
   diff /tmp/before.txt /tmp/after.txt
   ```
   Add the discovered `defaults write …` line to `macos_defaults.sh`.

**Raycast.** The raw files aren't portable/diffable, so use Raycast's own export:
Raycast → Settings → Advanced → **Export** → a `.rayconfig` file (offer it a
password). Then either:
- commit it to the repo as `raycast.rayconfig` — ⚠️ it can contain snippets and
  secrets, so only do this with the **password-protected** export; or
- keep it outside git (1Password / iCloud) and note where it lives.

### 1g. Commit & push from the OLD machine

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

# 5. Apply macOS system settings (keyboard repeat, function keys, etc.)
./macos_defaults.sh

# 6. Open a fresh shell and confirm there are no startup errors
```

### Post-install manual bits

- **Rotate the leaked `LIVE_BEATS` GitHub OAuth secret** — it was removed from
  the file but remains in git history, so it is still compromised.
- **1Password CLI**: `op signin` (and add your account) so the guarded
  `OPENAI_API_KEY` fetch works. Until then it skips silently.
- **Postgres.app**: launch it once, then create the Phoenix role if needed:
  `createuser -s postgres` (or set creds in each app's `dev.exs`).
- **Raycast**: Settings → Advanced → Import → select your `.rayconfig`.

---

## Quick reference — what changed on this branch

| Area | Change |
|------|--------|
| Runtimes | `node`/`python` removed from Brewfile → managed by mise. Tracked as `mise_config.toml` (node 22.12.0, python 3.13, elixir 1.20.1-otp-29, erlang 29.0.2) and symlinked to `~/.config/mise/config.toml` |
| Brewfile | Pruned monitors/disk/media/embedded/unused CLIs (commented out); dropped emacs tap, arc, arduino-ide; postgresql@14 → Postgres.app; added starship/atuin/television/zsh-autosuggestions |
| zshrc | Removed tmux/run_iex/yazi/emacs/doom; commented unidentified `entire`; guarded atuin env + 1Password fetch; source zsh-syntax-highlighting last; removed leaked secret |
| Files | Deleted orphaned `cmux_dev_layout.sh` |
