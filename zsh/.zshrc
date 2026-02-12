# OPENSPEC:START
# OpenSpec shell completions configuration
fpath=("/Users/takuto_kato/.zsh/completions" $fpath)
autoload -Uz compinit
compinit
# OPENSPEC:END

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
function fgh() {
  declare -r REPO_NAME="$(ghq list >/dev/null | fzf-tmux --reverse +m)"
  [[ -n "${REPO_NAME}" ]] && cd "$(ghq root)/${REPO_NAME}"
}

# tmux dev layout: nvim(left) + claude(right)
function dev() {
  if [[ -z "$TMUX" ]]; then
    echo "dev: tmux session required"
    return 1
  fi
  local repo=$(ghq list | fzf-tmux --reverse +m)
  [[ -z "$repo" ]] && return
  local dir="$(ghq root)/$repo"
  local name=$(basename "$repo")

  tmux new-window -n "$name" -c "$dir" "nvim"
  tmux split-window -h -c "$dir" "claude"
  tmux select-pane -t 0
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
export PATH="$HOME/.local/bin:$PATH"
