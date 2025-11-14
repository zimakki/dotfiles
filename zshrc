#!/bin/zsh
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# make sure doom is in the path
export PATH=$PATH:$HOME/.doom_emacs.d/bin

#make the keyboard work faster
defaults write -g InitialKeyRepeat -int 10 # normal minimum is 15 (225 ms)
defaults write -g KeyRepeat -int 1         # normal minimum is 2 (30 ms)

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
eval "$(fzf --zsh)"

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

# Make sure the function is available in the shell
export -f diff_files

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


test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
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

# some secrets for live_beats elixir application
export LIVE_BEATS_GITHUB_CLIENT_ID="1aac63d3d8f1e4fb9dc6"
export LIVE_BEATS_GITHUB_CLIENT_SECRET="86473938560cbecd3e9a00ade6f9afc7f4548c48"

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

	# Check if file exists and is fresh (< 7 days old)
	if [[ -f "$secrets_file" ]]; then
		local file_age=$(( ($(date +%s) - $(stat -f %m "$secrets_file")) / 86400 ))
		echo "[API Keys] Secrets file exists (age: ${file_age} days, max: ${max_age_days} days)"
		if (( file_age < max_age_days )); then
			# File is fresh, just source it
			echo "[API Keys] Using cached keys from $secrets_file"
			source "$secrets_file"
			return
		else
			echo "[API Keys] Cache is stale, refreshing..."
		fi
	else
		echo "[API Keys] No cache file found at $secrets_file"
	fi

	# File missing or stale, fetch from 1Password
	echo "[API Keys] Fetching from 1Password..."
	local openai_key="$(op read op://Personal/ChatGPT.nvim/password --no-newline)"
	local anthropic_key="$(op read op://Personal/nvim.anthropic_api_key/password --no-newline)"

	# Write to secrets file
	cat > "$secrets_file" <<-EOF
		export OPENAI_API_KEY="$openai_key"
		export ANTHROPIC_API_KEY="$anthropic_key"
	EOF

	# Secure the file
	chmod 600 "$secrets_file"
	echo "[API Keys] Cache saved to $secrets_file"

	# Source it
	source "$secrets_file"
}

_load_api_keys

####################################################################################################
# Alex's fzf plugin for iex
####################################################################################################

export PATH="~/.iex-history:$PATH"

alias i="run_iex"
alias is="run_iex -S mix phx.server"

function run_iex() {
	local session=$(date | sha256sum | cut -c1-8)
	local current_session=${1:-$(tmux display -p '#{session_name}')}

	local command='iex'

	if [ "$#" -gt 0 ]; then
		command+=" $@"
	fi

	# Determine the current directory
	local current_dir="$(pwd)"

	if [ -n "$TMUX" ]; then
		echo "Already in a tmux session. Switching to 'iex_session'..."
		# Send 'cd' to the current directory and clear the screen
		tmux send-keys -t "$current_session" "cd ${current_dir}" C-m \; send-keys -t "$current_session" "clear" C-m
		# Then send the command
		tmux send-keys -t "$current_session" "$command" C-m
	else
		# Create a new session with the current directory and run the command
		tmux new-session -d -s "$session" -c "$current_dir"
		tmux send-keys -t "$session" "$command" C-m
		if [ -z "$TMUX" ]; then
			tmux attach -t "$session"
		fi
	fi
}
####################################################################################################
#
# Yazi - File manager
# function below is used to give yazi the ability to change the directory
####################################################################################################
function ya() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXX")"
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# add rebar3 to the path
export PATH=/Users/zimakki/.cache/rebar3/bin:$PATH

# trying out a homebrew version of file. Its also installed on the system...
# so if things go wrong, I can always use the system version
export PATH="/opt/homebrew/opt/file-formula/bin:$PATH"

# Added by Windsurf
export PATH="/Users/zimakki/.codeium/windsurf/bin:$PATH"
# added by mix escript install
export PATH="$HOME/.mix/escripts:$PATH"
export PATH="~/code/zimakki/prepx/:$PATH"
