# Yazi Catppuccin Mocha Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install and activate Yazi's official Catppuccin Mocha flavor so Yazi matches the workstation's fixed dark theme.

**Architecture:** Yazi's package manager will lock and install the official flavor inside the already-managed `config/yazi/` directory. A minimal `theme.toml` will select that flavor, while the existing bootstrap link makes the complete configuration available without new bootstrap scripting.

**Tech Stack:** Yazi/Ya 26.5.6, Yazi flavors, TOML, Python 3 contract tests, Zsh, mise.

## Global Constraints

- Work only in `/Users/zimakki/code/zimakki/dotfiles`, the canonical checkout; never apply bootstrap from a secondary worktree.
- Select `catppuccin-mocha` for dark mode only; do not install Latte or add automatic light/dark switching.
- Use `yazi-rs/flavors:catppuccin-mocha`; do not hand-author or override the official palette.
- Track the complete flavor directory and its generated `package.toml` lock metadata.
- Do not edit files inside `config/yazi/flavors/catppuccin-mocha.yazi/` by hand.
- Preserve `config/yazi/init.lua` and the existing `y` shell wrapper behavior.
- Preserve unrelated working-tree changes and do not push.

---

### Task 1: Install, select, and verify the official Mocha flavor

**Files:**
- Create: `config/yazi/theme.toml`
- Create: `config/yazi/package.toml`
- Create: `config/yazi/flavors/catppuccin-mocha.yazi/`
- Modify: `tests/bootstrap/config_contract.py`
- Preserve: `config/yazi/init.lua`

**Interfaces:**
- Consumes: the `~/.config/yazi -> config/yazi` mise-managed link and the Homebrew-provided `ya` 26.5.6 package manager.
- Produces: a locked `yazi-rs/flavors:catppuccin-mocha` dependency and a `[flavor].dark = "catppuccin-mocha"` runtime selection.

- [ ] **Step 1: Add the failing Yazi theme contract**

Insert this block in `tests/bootstrap/config_contract.py` immediately before the
existing temporary-directory test for the `y` shell wrapper:

```python
yazi_dir = source_for("~/.config/yazi")
yazi_theme = tomllib.loads((yazi_dir / "theme.toml").read_text(encoding="utf-8"))
assert yazi_theme == {"flavor": {"dark": "catppuccin-mocha"}}

yazi_packages = tomllib.loads((yazi_dir / "package.toml").read_text(encoding="utf-8"))
mocha_dependency = next(
    (
        dependency
        for dependency in yazi_packages.get("flavor", {}).get("deps", [])
        if dependency.get("use") == "yazi-rs/flavors:catppuccin-mocha"
    ),
    None,
)
assert mocha_dependency is not None
assert re.fullmatch(r"[0-9a-f]{7,40}", mocha_dependency["rev"])
assert re.fullmatch(r"[0-9a-f]{32}", mocha_dependency["hash"])

mocha_dir = yazi_dir / "flavors/catppuccin-mocha.yazi"
for relative in (
    "flavor.toml",
    "tmtheme.xml",
    "LICENSE",
    "LICENSE-tmtheme",
    "README.md",
    "preview.png",
):
    assert (mocha_dir / relative).is_file(), relative
tomllib.loads((mocha_dir / "flavor.toml").read_text(encoding="utf-8"))
```

- [ ] **Step 2: Run the focused contract and verify the expected failure**

Run:

```bash
python3 tests/bootstrap/config_contract.py
```

Expected: non-zero exit with `FileNotFoundError` for
`config/yazi/theme.toml`, proving the contract detects the missing theme.

- [ ] **Step 3: Install the official locked flavor**

Run:

```bash
ya pkg add yazi-rs/flavors:catppuccin-mocha
```

Expected: exit 0; `config/yazi/package.toml` and
`config/yazi/flavors/catppuccin-mocha.yazi/` are created through the managed
configuration symlink.

- [ ] **Step 4: Select Catppuccin Mocha**

Create `config/yazi/theme.toml` with `apply_patch`:

```toml
[flavor]
dark = "catppuccin-mocha"
```

- [ ] **Step 5: Expose all new managed files to repository checks**

Run:

```bash
git add -N -- config/yazi
```

Expected: the new Yazi files appear in `git diff` while their contents remain
unstaged.

- [ ] **Step 6: Run the focused contract and verify it passes**

Run:

```bash
python3 tests/bootstrap/config_contract.py
```

Expected: exit 0 with no output.

- [ ] **Step 7: Verify Yazi recognizes the installed flavor**

Run:

```bash
ya pkg list
yazi --debug
```

Expected: the package list contains
`yazi-rs/flavors:catppuccin-mocha`; debug output reports
`theme.toml`, `package.toml`, and a dark flavor of `catppuccin-mocha`.

- [ ] **Step 8: Smoke-test the interactive application**

Run:

```bash
expect -c '
set timeout 15
log_user 0
spawn -noecho env TERM=xterm-256color yazi /Users/zimakki/code/zimakki/dotfiles
after 4000
send -- "q"
expect eof
set result [wait]
exit [lindex $result 3]
'
```

Expected: exit 0, proving Yazi starts and exits cleanly in a pseudo-terminal
with the managed theme loaded.

- [ ] **Step 9: Run repository and bootstrap verification**

Run each command separately:

```bash
scripts/ci_checks.sh
scripts/bootstrap/preflight.zsh
mise bootstrap --dry-run
git diff --check
```

Expected: repository checks, preflight, bootstrap dry-run, and diff check all
exit 0. Preflight may retain the known warnings for uncommitted changes,
upstream divergence, and battery power.

- [ ] **Step 10: Commit the complete Yazi installation and theme**

Review `git diff`, then stage only the Yazi work:

```bash
git add -- \
  BrewFile \
  config/yazi \
  config/zsh/lib/functions.zsh \
  docs/superpowers/plans/2026-07-23-yazi-catppuccin-mocha.md \
  mise.toml \
  scripts/bootstrap/verify.zsh \
  tests/bootstrap/config_contract.py
git diff --cached --check
git diff --cached --name-status
git commit -m "feat: install and theme Yazi"
```

Expected: the commit contains the Homebrew declaration, managed Yazi
configuration and flavor, `y` wrapper, implementation plan, bootstrap
verification update, and their contract tests. It must not contain unrelated
files.
