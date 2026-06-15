#!/bin/zsh
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

export PATH="$HOME/.local/bin:$PATH"

# Path to your oh-my-zsh installation.
export ZSH="/Users/zimakki/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="robbyrussell"
# ZSH_THEME="amuse"
# Need to run this first: git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
ZSH_THEME=""

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# Caution: this setting can cause issues with multiline prompts (zsh 5.7.1 and newer seem to work)
# See https://github.com/ohmyzsh/ohmyzsh/issues/5765
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="yyyy-mm-dd"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
	dotenv
	mix
	git
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
	export EDITOR='nvim'
else
	export EDITOR='nvim'
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#

# ngrok shell completion
if command -v ngrok &>/dev/null; then
	eval "$(ngrok completion)"
fi

# From fzf instructions
# Guard with `-t 1`: only set up line-editor UI when stdout is a real terminal
# (e.g. tools like Expert that run `zsh -i -c` with no TTY → avoids "can't change option: zle")
if [[ -t 1 ]]; then
  eval "$(fzf --zsh)"
  bindkey -r '^T' # Unbind fzf's Ctrl+T (tv handles this)
fi

# function for listing and checking out branches
function gci() {
	git checkout $(git branch --all | fzf | sed 's/remotes\/origin\///')
}

# Function to diff two files using fzf and delta
function diff_files() {
  # Select the first file
  local file1=$(git ls-tree -r --name-only HEAD | fzf --prompt="Select first file: ")
  [[ -z "$file1" ]] && echo "No file selected!" && return 1

  # Select the second file
  local file2=$(git ls-tree -r --name-only HEAD | fzf --prompt="Select second file: ")
  [[ -z "$file2" ]] && echo "No file selected!" && return 1

  # Run the diff command
  diff -u "$file1" "$file2" | delta
}

# (no `export -f` — that's a bashism; in zsh the function is already available,
#  and `export -f` just prints the definition on every shell startup)

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

##############################################################################
# alias's
##############################################################################
## Changing "ls" to "lsd"
alias ls='lsd -al --group-dirs first' # my preferred listing
alias vi='nvim'
alias vim='nvim'
alias cdd='cd ../..'
alias cddd='cd ../../..'
alias cdddd='cd ../../../..'
## use delta with rg for much nicer outputs!
alias rg='rg --json -C 2 handle | delta'
# alias cat to bat for colors!
alias cat='bat'
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias git='git_with_diff'

git_with_diff() {
	if [[ "$1" == "status" ]]; then
		shift
		command git status "$@" && git diff
	else
		command git "$@"
	fi
}

# to get help in iex for erlang functions
# Note: This needs to be set BEFORE you install Erlang to work
export KERL_BUILD_DOCS="yes"

# Elixir: enable history in iex
export ERL_AFLAGS="-kernel shell_history enabled"


#mise activate output
#
export MISE_SHELL=zsh
export __MISE_ORIG_PATH="$PATH"

mise() {
  local command
  command="${1:-}"
  if [ "$#" = 0 ]; then
    command /opt/homebrew/bin/mise
    return
  fi
  shift

  case "$command" in
  deactivate|s|shell)
    # if argv doesn't contains -h,--help
    if [[ ! " $@ " =~ " --help " ]] && [[ ! " $@ " =~ " -h " ]]; then
      eval "$(command /opt/homebrew/bin/mise "$command" "$@")"
      return $?
    fi
    ;;
  esac
  command /opt/homebrew/bin/mise "$command" "$@"
}

_mise_hook() {
  eval "$(/opt/homebrew/bin/mise hook-env -s zsh)";
}
typeset -ag precmd_functions;
if [[ -z "${precmd_functions[(r)_mise_hook]+1}" ]]; then
  precmd_functions=( _mise_hook ${precmd_functions[@]} )
fi
typeset -ag chpwd_functions;
if [[ -z "${chpwd_functions[(r)_mise_hook]+1}" ]]; then
  chpwd_functions=( _mise_hook ${chpwd_functions[@]} )
fi

if [ -z "${_mise_cmd_not_found:-}" ]; then
    _mise_cmd_not_found=1
    [ -n "$(declare -f command_not_found_handler)" ] && eval "${$(declare -f command_not_found_handler)/command_not_found_handler/_command_not_found_handler}"

    function command_not_found_handler() {
        if /opt/homebrew/bin/mise hook-not-found -s zsh -- "$1"; then
          _mise_hook
          "$@"
        elif [ -n "$(declare -f _command_not_found_handler)" ]; then
            _command_not_found_handler "$@"
        else
            echo "zsh: command not found: $1" >&2
            return 127
        fi
    }
fi
# end mise stuff ---------------------------------------------------------------------------



export PATH="/usr/local/opt/curl/bin:$PATH"

# curl
# For compilers to find curl you may need to set:
export LDFLAGS="-L/usr/local/opt/curl/lib"
export CPPFLAGS="-I/usr/local/opt/curl/include"
export PATH="/usr/local/sbin:$PATH"

# make sure we use astronvim v5
export NVIM_APPNAME=astronvim_v5


#Add zoxide to your shell
# zoxide is used to jump around directories. Example: `z mia` will jump to the directory that has mia in it
# the `--cmd` flag is used so that zoxide replaces the cd command in the shell
eval "$(zoxide init --cmd cd zsh)"

# Fallback cd function for when Zoxide isn't properly initialized (e.g., non-interactive shells)
cd() {
    if command -v __zoxide_z >/dev/null 2>&1 && type __zoxide_z >/dev/null 2>&1; then
        __zoxide_z "$@"
    else
        builtin cd "$@"
    fi
}

# stuff for tre
tre() { command tre "$@" -e && source "/tmp/tre_aliases_$USER" 2>/dev/null; }

#lunar vim settings
export PATH=/Users/zimakki/.local/bin:$PATH

# trying to fix an issue that doom doctor reported
# In .zshrc/.bashrc
if [ -d "$(brew --prefix)/opt/grep/libexec/gnubin" ]; then
	PATH="$(brew --prefix)/opt/grep/libexec/gnubin:$PATH"
fi

delete_nvim_cache() {
	echo "deleting ~/.local/share/nvim"
	rm -rf ~/.local/share/nvim
	echo "deleting ~/.local/state/nvim"
	rm -rf ~/.local/state/nvim
	echo "deleting ~/.cache/nvim"
	rm -rf ~/.cache/nvim
}

# for the chatgpt.nvim plugin - it needs an api key for open_ai
_load_api_keys() {
	local secrets_file="$HOME/.zsh_secrets"
	local max_age_days=7

	# Fresh cache (< max_age_days)? source it silently.
	if [[ -f "$secrets_file" ]]; then
		local file_age=$(( ($(date +%s) - $(stat -f %m "$secrets_file")) / 86400 ))
		if (( file_age < max_age_days )); then
			source "$secrets_file"
			return
		fi
	fi

	# Cache missing/stale — refresh from 1Password, but only if signed in.
	# Otherwise skip silently (fall back to a stale cache if present).
	if ! command -v op >/dev/null 2>&1 || ! op whoami >/dev/null 2>&1; then
		[[ -f "$secrets_file" ]] && source "$secrets_file"
		return
	fi

	echo "[API Keys] refreshing OPENAI_API_KEY from 1Password…"
	local openai_key="$(op read op://Personal/ChatGPT.nvim/password --no-newline)"
	print -r -- "export OPENAI_API_KEY=\"$openai_key\"" > "$secrets_file"
	chmod 600 "$secrets_file"
	source "$secrets_file"
}

_load_api_keys

####################################################################################################
# iex history + television (tvf) helper
####################################################################################################

export PATH="~/.iex-history:$PATH"

alias tvf='tv files -k "enter=\"confirm_selection\"" | xargs nvim'


# add rebar3 to the path
export PATH=/Users/zimakki/.cache/rebar3/bin:$PATH

# trying out a homebrew version of file. Its also installed on the system...
# so if things go wrong, I can always use the system version
export PATH="/opt/homebrew/opt/file-formula/bin:$PATH"

# Added by Windsurf
export PATH="/Users/zimakki/.codeium/windsurf/bin:$PATH"
# added by mix escript install
export PATH="$HOME/.mix/escripts:$PATH"
export PATH="$HOME/code/zimakki/prepx/:$PATH"

# Initialize television + Atuin shell integration (both register zle widgets)
# Guard with `-t 1`: only on a real terminal (skipped when a tool shells out to capture output)
if [[ -t 1 ]]; then
  # television: smart autocomplete on Ctrl+T
  eval "$(tv init zsh)"
  bindkey -r '^R' # Unbind tv's Ctrl+R so atuin handles history

  # Atuin: enhanced shell history (Ctrl+R)
  # (brew's atuin doesn't create ~/.atuin/bin/env; guard so it works either way)
  [ -f "$HOME/.atuin/bin/env" ] && . "$HOME/.atuin/bin/env"
  eval "$(atuin init zsh)"
fi

# pnpm
export PNPM_HOME="/Users/zimakki/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Added by Antigravity
export PATH="/Users/zimakki/.antigravity/antigravity/bin:$PATH"

# "entire" CLI completion — REMOVED: tool unidentified & no longer installed (added 2026-03).
# oh-my-zsh already runs compinit, so dropping this whole line is safe.
# autoload -Uz compinit && compinit && source <(entire completion zsh)

# Line-editor UI: autosuggestions, starship prompt, syntax-highlighting.
# Guard with `-t 1`: real terminal only; fzf-style option save/restore errors when shelled out.
export STARSHIP_LOG=error
if [[ -t 1 ]]; then
  # Predictive command suggestions from history
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

  # Starship prompt — STARSHIP_PREEXEC_READY suppresses cursor position queries
  # that leak as ";1R;6R" garbage in some terminals
  eval "$(starship init zsh)"

  # zsh-syntax-highlighting — MUST be sourced last (after all other zle widgets)
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
