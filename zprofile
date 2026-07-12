# /etc/zprofile runs path_helper after zshenv on macOS login shells. Reassert
# the same ~/.local/bin > mise shims > remaining PATH order established there.
typeset -U path PATH
_mise_data_dir="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}"
[[ -d "$_mise_data_dir/shims" ]] && path=("$_mise_data_dir/shims" $path)
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
unset _mise_data_dir
