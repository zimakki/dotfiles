---
name: install-app
description: Install a new application or tool through the dotfiles repo — pick the right channel, record it in BrewFile or mise.toml, install it, and capture any managed config. Use when the user asks to install, add, or set up an app or CLI tool.
---

# Install an app via the dotfiles repo

Record automated installs before applying them so a new machine reproduces the
result and Git explains it. Before changing shell config, PATH, or an installer
snippet, read `docs/conventions/shell-config.md`.

Ask for the app or tool name when it is missing. Resolve ambiguous package
names before making changes.

## 1. Pick the channel

Use the first suitable channel:

1. Add language runtimes and mise-supported global tools to `[tools]` in
   `mise.toml`; pin a version. Do not install runtimes such as Node or Python as
   direct Homebrew entries.
2. Add GUI apps as Homebrew casks.
3. Add CLI tools as Homebrew formulae.
4. Add Mac App Store-only apps with a `mas` entry; ensure `mas` itself is in
   `BrewFile`.
5. Prefer a mise backend over a raw global npm install. Use a raw global install
   only after confirming it is truly machine-wide; report it as an unmanaged
   exception rather than implying the repo will reproduce it.
6. For a third-party tap, verify the official project source, record the tap,
   and use the fully qualified token. If no automated channel exists, keep it
   out of `BrewFile` and document a genuinely repeatable manual step in the
   current setup runbook.

Use `brew search`, `brew info`, `mas search`, and official project
documentation to verify the selection. Do not infer a token from the display
name.

## 2. Record, install, and verify

Add formulae and casks in the existing sorted sections of `BrewFile` (capital
F). For mise tools, update `[tools]` and preserve the minimum-version and build
ordering contract.

Install through the chosen channel, then verify the actual executable or app.
Run `scripts/bootstrap/preflight.zsh` before any `mise bootstrap` apply. If the
checkout is a secondary worktree, record and test the repo change but do not
apply bootstrap to the machine.

## 3. Capture only intentional config

Inspect likely locations after the app has been configured once:

```sh
ls -d ~/.config/<app>* 2>/dev/null
ls -d ~/Library/Application\ Support/<App>* 2>/dev/null
ls ~/Library/Preferences/ | rg -i '<app>'
ls -d ~/.<app>* 2>/dev/null
```

Classify the result before adding it:

- Put stable, user-authored text under `config/<app>/` and add its destination
  to `[dotfiles]` in `mise.toml`. Use names meaningful inside the app folder,
  such as `config.toml`, `settings.json`, or `themes/<name>.toml`. Never create
  a new root-level app config source.
- For app-mutated files, prefer a supported import or owned-fragment workflow.
  For JSON without one, use a repository-owned overlay applied through
  `scripts/bootstrap/json-overlay.py`; add its invocation to the exception
  coordinator and a read-only check to verification. Do not introduce a
  whole-file symlink. Claude and Karabiner are existing overlay examples.
- Keep opaque exports, binary plists, caches, databases, automatic backups, and
  generated app state outside Git.
- Track generated upstream material only when it is an intentional override;
  do not vendor an app's full default catalog.
- Keep secrets and tokens in 1Password or ignored local files. Never commit
  them.
- Add supported scalar macOS preferences under `[bootstrap.macos.*]`. Use
  `scripts/bootstrap/apply-macos-exceptions.zsh` only for unsupported
  host-scoped writes or necessary app restarts.

From the canonical checkout, preview static config changes without forcing
conflicts:

```sh
mise bootstrap --dry-run --only dotfiles
```

Split shell installer snippets by purpose:

- Add bin directories to the guarded `path` array in `config/zsh/zshenv` with
  an existence check. Mise-managed tools need no separate PATH entry.
- Add interactive hooks, completions, and widgets to `config/zsh/zshrc`; put
  reusable aliases and functions in the matching `config/zsh/lib/` module.
  Guard terminal UI setup with `[[ -t 1 ]]`.
- Add non-secret environment needed by scripts, IDEs, or agents to
  `config/zsh/zshenv`.
- Add deliberate machine-only environment to
  `config/zsh/hosts/<LocalHostName>.zsh`.

Keep zsh-syntax-highlighting last among interactive widgets. Its app-owned
theme lives in `config/zsh/themes/`.

Repo-managed shared skills live only in `.agents/skills/`. Synchronize their
discovery links with `scripts/maintenance/sync-agent-skills.sh --fix`; never
commit home-directory links.

## 4. Validate and hand off

Run the repository checks from any checkout:

```sh
scripts/ci_checks.sh
```

Run the machine preview only from the canonical checkout:

```sh
scripts/bootstrap/preflight.zsh
mise bootstrap --dry-run
```

When ownership changes, update derived assertions under `tests/bootstrap/`.
Avoid duplicating exact tool, link, or defaults counts in prose.

Commit or push only when requested or explicitly included in the task. Prefer
one atomic commit per app. Report what was installed, what config was captured,
and every manual follow-up.
