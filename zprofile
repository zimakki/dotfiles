# /etc/zprofile runs path_helper after zshenv on macOS login shells. Reassert the
# mise shims afterward so login and non-login shells resolve the same runtimes.
typeset -U path PATH
_mise_data_dir="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}"
[[ -d "$_mise_data_dir/shims" ]] && path=("$_mise_data_dir/shims" $path)
unset _mise_data_dir
