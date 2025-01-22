# git
fpath=($(brew --prefix)/share/zsh/site-functions $fpath)

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
alias gr='git reset --hard HEAD'
alias gpum='git pull upstream main'
alias gpom='git push origin main'

# alias for development
alias dev='export ENV=dev'
alias prod='export ENV=prod'
alias stg='export ENV=stg'
alias demo='export ENV=demo'
alias test='export ENV=test'

# ghq + fzf
$ fgh() {
  declare -r REPO_NAME="$(ghq list >/dev/null | fzf-tmux --reverse +m)"
  [[ -n "${REPO_NAME}" ]] && cd "$(ghq root)/${REPO_NAME}"
}

# mise
eval "$(mise activate zsh)"

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/takuto_kato/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# sheldon
eval "$(sheldon source)"

