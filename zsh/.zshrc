# OPENSPEC:START
# OpenSpec shell completions configuration
fpath=("/Users/takuto_kato/.zsh/completions" $fpath)
# OPENSPEC:END

# git
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)

export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache

# claude
alias c='claude'
# nvim
alias nv='nvim'

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
