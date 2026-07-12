# Shell Config Convention

This is the canonical convention for shell startup files in this dotfiles repo.
Read it before editing `zshenv`, `zprofile`, `zshrc`, `hosts/*.zsh`, PATH, shell
init hooks, or tool installer snippets.

## Contents

1. [The One Rule](#the-one-rule)
2. [Startup-File Model](#startup-file-model)
3. [Adding A PATH Entry](#adding-a-path-entry)
4. [Shell Hooks, Completions, And Prompt Widgets](#shell-hooks-completions-and-prompt-widgets)
5. [Per-Host Config](#per-host-config)
6. [macOS path_helper](#macos-path_helper)
7. [Secrets](#secrets)
8. [Decision Checklist](#decision-checklist)

## The One Rule

Environment belongs in `zshenv`. Interactive behavior belongs in `zshrc`.

Use `zshenv` for:

- PATH entries
- exported environment variables needed by commands, scripts, IDEs, agents, or
  other non-interactive shells
- machine-specific environment loaded through `hosts/<LocalHostName>.zsh`

Use `zshrc` for:

- aliases and functions that change command behavior
- prompt setup
- completion setup
- line-editor widgets
- interactive-only tool hooks

Do not add PATH entries to `zshrc`. A tool that only appears in `zshrc` will be
missing from non-interactive shells.

## Startup-File Model

`zshenv` is sourced for every zsh invocation. That includes interactive shells,
login shells, scripts, and commands launched by tools through `zsh -c` or
`zsh -lc`.

`zshrc` is sourced only for interactive zsh shells. It is the right place for
terminal behavior, but the wrong place for environment required by automation.

This matters because agents, IDEs, daemons, and scripts often shell out with
commands like:

```sh
zsh -lc 'command -v psql'
```

That command reads `zshenv`, but it does not read `zshrc`. A PATH fix in
`zshrc` will look correct in a terminal and still fail for those callers.

## Adding A PATH Entry

Add tool directories to the guarded `path` array block in `zshenv`.

Rules:

- Use `[[ -d "$dir" ]]` guards so the shared repo works across machines where a
  tool may or may not exist.
- Keep `typeset -U path PATH` in effect so repeated sourcing does not duplicate
  entries.
- Prepend only `"$HOME/.local/bin"` so user-installed binaries such as `claude`
  and `paseo` win.
- Append other tool directories with `path+=("$dir")` so mise shims keep
  priority over standalone installs.
- If a tool is managed by mise, prefer the mise shim and do not add a separate
  PATH entry.

Example pattern:

```zsh
typeset -U path PATH

[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)

_dotfiles_path_candidates=(
  "/Applications/Postgres.app/Contents/Versions/latest/bin"
  "$HOME/.bun/bin"
)
for _dir in "${_dotfiles_path_candidates[@]}"; do
  [[ -d "$_dir" ]] && path+=("$_dir")
done
unset _dir _dotfiles_path_candidates
```

Prefer adding presence-based tool directories to the shared guarded list rather
than creating per-host entries. A directory that exists on only one machine is
still safe in the shared list when it is guarded.

## Shell Hooks, Completions, And Prompt Widgets

Interactive shell behavior belongs in `zshrc`.

Put these in `zshrc`:

- `eval "$(tool init zsh)"` for prompt, widget, or completion setup
- shell completions
- aliases
- functions that alter interactive command behavior
- prompt setup such as starship

Guard terminal UI setup with:

```zsh
if [[ -t 1 ]]; then
  eval "$(tool init zsh)"
fi
```

This avoids line-editor and terminal-option errors when a tool launches zsh
without a real TTY.

Keep `zsh-syntax-highlighting` last among zle widgets and prompt-related
interactive setup. Other widgets should load before it.

## Per-Host Config

Machine-specific environment goes in:

```text
hosts/<LocalHostName>.zsh
```

Find a machine key with:

```sh
scutil --get LocalHostName
```

`zshenv` sources the matching host file if it exists. Missing host files are a
clean no-op, so new machines do not require a bootstrap file.

Use host files only for deliberate machine-specific intent, such as a proxy, a
machine-only toolchain, or an override. Do not use them for ordinary
presence-based tool directories; those belong in the guarded `zshenv` path list.

Host files are committed. They must not contain secrets.

If a Mac's LocalHostName changes, rename its host file to match. The loader will
otherwise silently stop sourcing it.

## macOS path_helper

macOS login shells run `/etc/zprofile`, which calls `path_helper`. It can reorder
PATH entries for login shells.

This repo has verified that `path_helper` otherwise puts Homebrew Node and the
system Python ahead of mise in login shells. The fully managed `zprofile`
therefore reasserts the portable mise shims after `/etc/zprofile`. Keep that
reassertion aligned with the shim setup in `zshenv`, and verify both shell modes
after changing either file.

## Secrets

Never commit secrets to this repo.

Use 1Password and the generated `~/.zsh_secrets` cache for secret material. If a
tool installer suggests an exported token, do not add it to `zshenv`, `zshrc`, or
`hosts/*.zsh`.

Non-secret exported settings may go in `zshenv` when they are needed outside
interactive terminals. Interactive-only settings may stay in `zshrc`.

## Decision Checklist

When an installer gives a shell snippet, split it by what each line does:

| Snippet type | Destination |
| --- | --- |
| Bin directory such as `export PATH="$HOME/.tool/bin:$PATH"` | Guarded `path` array in `zshenv` |
| Mise-managed runtime or tool | `[tools]` in `mise.toml`; no tool-specific PATH entry |
| Exported non-secret env var needed by scripts or tools | `zshenv` |
| Exported non-secret env var only used in interactive terminals | `zshrc` |
| Secret token or password | 1Password / `~/.zsh_secrets`, never committed |
| Completion, prompt, or zle widget init | `zshrc`, usually guarded by `[[ -t 1 ]]` |
| Alias or interactive function | `zshrc` |
| Deliberate machine-only environment override | `hosts/<LocalHostName>.zsh` |

Before committing shell config changes, verify from a non-interactive shell when
the change affects command discovery:

```sh
zsh -lc 'command -v <tool>'
zsh -c 'command -v <tool>'
```
