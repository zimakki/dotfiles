[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# Cache mise env directive results (incl. fnox secret resolution) so secrets
# aren't re-fetched from 1Password on every command — avoids repeated op/Touch ID prompts.
export MISE_ENV_CACHE=1
export KERL_BUILD_DOCS="yes"

# Put managed-tool shims on PATH without running mise during shell startup.
# Interactive shells additionally get the live activation hook from ~/.zshrc.
_mise_data_dir="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}"
[[ -d "$_mise_data_dir/shims" ]] && path=("$_mise_data_dir/shims" $path)
unset _mise_data_dir

# ---------------------------------------------------------------------------
# PATH — single source of truth for tool directories.
# Lives in zshenv (not zshrc) so NON-interactive shells (scripts, IDEs, agents
# that shell out via `zsh -lc`) resolve these too; zshrc is interactive-only.
#
# Each dir is added ONLY if it exists on THIS machine, so the same block is
# correct on every computer that shares this repo and self-heals as tools come
# and go. `typeset -U` keeps entries unique (idempotent — safe to re-source).
#
# Precedence: mise shims (prepended above) > tool
# dirs below. That's why the variable tool dirs are APPENDED (path+=), not
# prepended — a standalone install (e.g. a bare ~/.bun/bin on some machine) must
# NOT shadow mise's managed shim. Only ~/.local/bin is prepended, so user
# binaries (claude, paseo) win.
# ---------------------------------------------------------------------------
typeset -U path PATH

# ~/.local/bin: user-installed binaries (claude, paseo) — prepend so they win.
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)

# Other tool dirs whose presence varies across computers. Appended (see note
# above) so mise shims keep priority. `latest` in the Postgres.app path is a
# symlink tracking the current version. Listed order == precedence order.
_dotfiles_path_candidates=(
  "/Applications/Postgres.app/Contents/Versions/latest/bin"
  "$HOME/.bun/bin"
  "$HOME/Library/pnpm"
  "$HOME/.cache/rebar3/bin"
  "$HOME/.mix/escripts"
  "$HOME/.codeium/windsurf/bin"
  "$HOME/.antigravity/antigravity/bin"
  "/opt/homebrew/opt/file-formula/bin"
)
for _dir in "${_dotfiles_path_candidates[@]}"; do
  [[ -d "$_dir" ]] && path+=("$_dir")
done
unset _dir _dotfiles_path_candidates

# ---------------------------------------------------------------------------
# Per-host config: source hosts/<LocalHostName>.zsh if present.
# LocalHostName is stable + filename-safe (unlike $HOST, which is network-
# dependent). Repo dir is resolved from THIS file's real path (symlink-aware),
# since ZDOTDIR is unset and ~/.zshenv is a symlink into the repo.
# ---------------------------------------------------------------------------
_dotfiles_dir="${${(%):-%N}:A:h}"
_host_name="$(scutil --get LocalHostName 2>/dev/null)"
if [[ -n "$_host_name" && -f "$_dotfiles_dir/hosts/$_host_name.zsh" ]]; then
  source "$_dotfiles_dir/hosts/$_host_name.zsh"
fi
unset _dotfiles_dir _host_name
