# Dotfiles Migration Plan (old Mac → new Mac)

This branch (`chore/curate-dotfiles-for-new-mac`) curates the dotfiles on the
**new** MacBook: runtimes moved to mise, the Brewfile pruned, the zshrc cleaned
up, and a leaked secret removed.

**Goal:** stand up the new Mac from these curated dotfiles without losing
anything you rely on. **Phase 1** (old Mac) is a full audit — it captures the
packages, CLI/GUI tools, configs, app list, and macOS settings worth keeping.
**Phase 2** (new Mac) installs it all in the right order. Run Phase 1 *before*
installing on the new machine.

**Prerequisites:** the dotfiles repo is already cloned and your GitHub SSH
access works on both machines (set up separately).

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

**Use a git worktree** so your live configs are never touched. Your dotfiles are
symlinked from your *main* checkout; a worktree is a separate directory, so
checking out this branch there leaves the main checkout — and your symlinks —
untouched. (Don't run `setup_sim_links.zsh` here.)

```sh
cd <your main dotfiles checkout>
git fetch origin
git worktree add ../dotfiles-migration chore/curate-dotfiles-for-new-mac
cd ../dotfiles-migration
# ...do Phase 1 here, then commit + push...
# when finished: git worktree remove ../dotfiles-migration
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

- `~/.config/mise/config.toml` — global runtime/bootstrap config. Tracked as
  discoverable `mise.toml` and linked declaratively by mise bootstrap.
- Neovim config — `NVIM_APPNAME=astronvim_v6`; confirm that config is its own
  repo and is pushed.
- Ghostty terminal — already tracked (`ghostty_config` → `~/.config/ghostty/config`);
  just make sure the old Mac's version is committed.
- Anything under `~/.config` you use that isn't in `LINKS`.

**Audit `~/.config` by modification time.** Recently-touched config is a strong
sign of an app you actively use and may want to track. Surface candidates and
diff them against what's already symlinked:

```sh
# config files changed in the last 30 days (active apps bubble up)
find ~/.config -maxdepth 3 -type f -mtime -30 2>/dev/null | sort

# everything in ~/.config, most-recently-modified first
ls -lt ~/.config

# destinations already symlinked from this repo (spot the gaps):
grep -oE '~/[^"]+' setup_sim_links.zsh | sort
```

For any actively-used `~/.config/<app>` not already symlinked: copy it into the
repo and add a `LINKS` entry (`<repo-file>:~/.config/<app>/<file>`). The same
mtime trick works on `~/Library/Application Support` and `~/Library/Preferences`
if an app keeps its config there instead.

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

Review what you're about to commit — don't blanket-add (it can sweep in secrets
like an unprotected `raycast.rayconfig`):

```sh
git status                                            # eyeball every change
git add BrewFile karabiner.json macos_defaults.sh    # add intended files explicitly
# password-protected Raycast export only (it's gitignored):
# git add -f raycast.rayconfig
git commit -m "Capture old-machine packages, tools, and configs"
git push
```

---

## Phase 2 — NEW machine: mise bootstrap (after Phase 1 is merged/pulled)

Install Xcode Command Line Tools, Homebrew, Git, and mise >=2026.7.4 before
cloning. The repo deliberately does not upgrade the live mise binary. Bootstrap
then guarantees that the canonical BrewFile finishes before tool compilation.

### Pre-flight (gate the whole phase)

```sh
cd ~/code/zimakki/dotfiles
git pull
./scripts/phase2_preflight.sh   # branch/toolchain/disk/network + validates every Brewfile token
```
Don't continue unless this exits ✅.

### One operator flow

```sh
# Install oh-my-zsh before applying the fully managed zshrc.
[ -d ~/.oh-my-zsh ] || KEEP_ZSHRC=yes RUNZSH=no CHSH=no \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
[ -f ~/.oh-my-zsh/oh-my-zsh.sh ] && echo "✅ oh-my-zsh" || echo "❌ oh-my-zsh"

# Snapshot defaults, trust the reviewed config, preview, apply, inspect, verify.
defaults read > /tmp/defaults.before
mise trust ./mise.toml
mise bootstrap --dry-run
mise bootstrap
mise bootstrap status
./scripts/verify_setup.sh
```

### Verify everything

```sh
./scripts/verify_setup.sh    # runs all automated post-checks → PASS/FAIL report
```
Re-runnable anytime. Mise refuses conflicting files by default; inspect them
before deliberately using `--force-dotfiles`. Revert defaults by diffing against
`/tmp/defaults.before`.

### Manual checklist (GUI / credentials — can't be automated)

- [ ] **Karabiner**: approve the input-monitoring / system-extension prompt, then test a remapped key.
- [ ] **Raycast**: Settings → Advanced → Import → `raycast.rayconfig` (needs the export password); confirm a hotkey.
- [ ] **1Password**: `op signin`, then `op whoami` succeeds (enables the `OPENAI_API_KEY` fetch).
- [ ] **Postgres.app**: launch once; `pg_isready`; `createuser -s postgres` if Phoenix needs it.
- [ ] Eyeball: starship prompt renders, nerd-font glyphs show, atuin `Ctrl-R` + television `Ctrl-T` work.

---

## ✅ Done when

- A fresh shell opens with no errors (prompt = starship, history = atuin).
- `mise ls` shows node 24.13.1, python 3.13.14, elixir 1.20.2-otp-29, erlang 29.0.2, bun 1.3.14, fnox 1.29.0, and portless 0.15.1.
- `brew bundle check` passes.
- Your key apps launch, Karabiner remaps work, and Raycast config is imported.

---

## Quick reference — what changed on this branch

| Area | Change |
|------|--------|
| Bootstrap | `mise.toml` is the discoverable front door and global config source; BrewFile remains the only package/cask inventory |
| Runtimes | Seven pinned mise tools: node 24.13.1, python 3.13.14, elixir 1.20.2-otp-29, erlang 29.0.2, bun 1.3.14, fnox 1.29.0, portless 0.15.1 |
| Brewfile | Pruned monitors/disk/media/embedded/unused CLIs (commented out); dropped emacs tap, arc, arduino-ide; postgresql@14 → Postgres.app; added starship/atuin/television/zsh-autosuggestions |
| zshrc | Removed tmux/run_iex/yazi/emacs/doom; commented unidentified `entire`; guarded atuin env + 1Password fetch; source zsh-syntax-highlighting last; removed leaked secret |
| Files | Deleted orphaned `cmux_dev_layout.sh` |
