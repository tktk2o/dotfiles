export LANG=ja_JP.UTF-8

# git
fpath=($(brew --prefix)/share/zsh/site-functions $fpath)

autoload -Uz compinit && compinit

setopt auto_cd

setopt complete_in_word

export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache

# alias
alias ls='ls -G'
alias la='ls -A'

alias g='git'
alias gco='git checkout'
alias ga='git add ./'
alias gb='git branch'
alias gs='git status'
alias gc='git commit'

alias v='nvim'

# init
eval "$(starship init zsh)"

# Added by serverless binary installer
export PATH="$HOME/.serverless/bin:$PATH"

# tabtab source for packages
# uninstall by removing these lines
[[ -f ~/.config/tabtab/__tabtab.zsh ]] && . ~/.config/tabtab/__tabtab.zsh || true
