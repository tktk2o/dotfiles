# fpath (completions)
fpath=("/Users/takuto_kato/.zsh/completions" /opt/homebrew/share/zsh/site-functions $fpath)

export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache

# PATH (consolidated)
export PATH="$HOME/.local/bin:/Users/takuto_kato/.rd/bin:/opt/homebrew/opt/mysql@8.4/bin:$PATH"

# aliases
alias c='claude'
alias nv='nvim'

# sheldon (cached)
_sheldon_cache="$XDG_CACHE_HOME/sheldon/source.zsh"
if [[ ! -r "$_sheldon_cache" || "$XDG_CONFIG_HOME/sheldon/plugins.toml" -nt "$_sheldon_cache" ]]; then
  mkdir -p "${_sheldon_cache:h}"
  sheldon source > "$_sheldon_cache"
fi
source "$_sheldon_cache"
unset _sheldon_cache

# mise (deferred)
zsh-defer eval "$(mise activate zsh)"
