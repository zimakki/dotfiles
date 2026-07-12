# Deliberate interactive command overrides.

alias ls='lsd -al --group-dirs first'
alias vi='nvim'
alias vim='nvim'
alias cdd='cd ../..'
alias cddd='cd ../../..'
alias cdddd='cd ../../../..'
alias rg='rg --json -C 2 handle | delta'
alias cat='bat'
alias git='git_with_diff'
alias tvf='tv files -k "enter=\"confirm_selection\"" | xargs nvim'
