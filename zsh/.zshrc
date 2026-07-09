# fpath (completions)
fpath=("/Users/takuto_kato/.zsh/completions" /opt/homebrew/share/zsh/site-functions $fpath)

export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache

# PATH (consolidated)
export PATH="$HOME/.local/bin:/Users/takuto_kato/.rd/bin:/opt/homebrew/opt/mysql@8.4/bin:$PATH"

# aliases
alias c='claude --permission-mode acceptEdits'
alias nv='nvim'

# sheldon (cached). Regenerate the source script when plugins.toml or
# any local *.zsh plugin is newer than the cache; otherwise reuse it.
_sheldon_cache="$XDG_CACHE_HOME/sheldon/source.zsh"
_sheldon_stale=
if [[ ! -r "$_sheldon_cache" ]]; then
  _sheldon_stale=1
else
  for _f in "$XDG_CONFIG_HOME/sheldon/plugins.toml" "$XDG_CONFIG_HOME/zsh/plugins"/*.zsh(N); do
    if [[ "$_f" -nt "$_sheldon_cache" ]]; then
      _sheldon_stale=1
      break
    fi
  done
fi
if [[ -n "$_sheldon_stale" ]]; then
  mkdir -p "${_sheldon_cache:h}"
  # --relock re-discovers local plugin files (e.g. newly added *.zsh)
  # without hitting the network for github-hosted plugins.
  sheldon source --relock > "$_sheldon_cache"
fi
source "$_sheldon_cache"
unset _sheldon_cache _sheldon_stale _f

# mise (deferred if possible)
if command -v mise &>/dev/null; then
  if (( $+functions[zsh-defer] )); then
    zsh-defer eval "$(mise activate zsh)"
  else
    eval "$(mise activate zsh)"
  fi
fi

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/takuto_kato/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# pnpm
export PNPM_HOME="/Users/takuto_kato/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
