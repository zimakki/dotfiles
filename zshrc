#!/bin/zsh
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH


# make sure doom is in the path
export PATH=$PATH:$HOME/.doom_emacs.d/bin

#make the keyboard work faster
defaults write -g InitialKeyRepeat -int 10 # normal minimum is 15 (225 ms)
defaults write -g KeyRepeat -int 1 # normal minimum is 2 (30 ms)


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

# function for listing and checking out branches
function gci() {
    git checkout $(git branch --all | fzf | sed 's/remotes\/origin\///' )
}


[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

##############################################################################
# alias's
##############################################################################
## Changing "ls" to "exa"
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


# asdf
# Get the machine hardware name
machine_hw_name=$(uname -m)

# Check if it's an Apple Silicon M1 Mac
if [ "$machine_hw_name" = "arm64" ]; then
    echo "This is an Apple Silicon M1 Mac."
    # Add your M1 specific commands here
    . /opt/homebrew/opt/asdf/libexec/asdf.sh
elif [ "$machine_hw_name" = "x86_64" ]; then
    echo "This is an Intel Mac. Setting up Intel specific commands for asdf."
    # Add your Intel specific commands here
    . /usr/local/opt/asdf/libexec/asdf.sh
else
    echo "Unknown architecture: $machine_hw_name"
    # Handle other architectures or unknown cases
fi
###################################

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
export PATH="/usr/local/opt/curl/bin:$PATH"

# curl
# For compilers to find curl you may need to set:
export LDFLAGS="-L/usr/local/opt/curl/lib"
export CPPFLAGS="-I/usr/local/opt/curl/include"
export PATH="/usr/local/sbin:$PATH"


#Add zoxide to your shell
# zoxide is used to jump around directories. Example: `z mia` will jump to the directory that has mia in it
eval "$(zoxide init zsh)"

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

delete_nvim_cache ()
{
  echo "deleting ~/.local/share/nvim"
  rm -rf ~/.local/share/nvim 
  echo "deleting ~/.local/state/nvim"
  rm -rf ~/.local/state/nvim
  echo "deleting ~/.cache/nvim"
  rm -rf ~/.cache/nvim 
}

# for the chatgpt.nvim plugin - it needs an api key for open_ai
OPENAI_API_KEY="$(op read op://Personal/ChatGPT.nvim/password --no-newline)"
export OPENAI_API_KEY=$OPENAI_API_KEY
echo "-------------------------------------"
echo "OPENAI_API_KEY=$OPENAI_API_KEY"
echo "OPENAI_API_KEY='$OPENAI_API_KEY'"
echo 'OPENAI_API_KEY="$OPENAI_API_KEY"'
echo "-------------------------------------"


# add rebar3 to the path
export PATH=/Users/zimakki/.cache/rebar3/bin:$PATH
