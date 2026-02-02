# git
fpath=($(brew --prefix)/share/zsh/site-functions $fpath)

export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache

# alias for git
alias gco='git checkout'
alias ga='git add ./'
alias gs='git status'
alias gc='git commit'

# claude
alias c='claude'
# nvim
alias nv='nvim'


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
export PATH="/opt/homebrew/opt/mysql@8.4/bin:$PATH"

# . "$HOME/.local/bin/env"
# export PATH="$HOME/.local/bin:$PATH"
