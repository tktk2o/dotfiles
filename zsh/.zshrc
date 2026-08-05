# fpath (completions)
fpath=("$HOME/.zsh/completions" /opt/homebrew/share/zsh/site-functions $fpath)

export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache

# PATH (consolidated)
export PATH="$HOME/.local/bin:/opt/homebrew/opt/mysql@8.4/bin:$PATH"

# history
#
# Nothing here set these before, so the effective values came from macOS's
# /etc/zshrc: SAVEHIST=1000. That silently capped ~/.zsh_history at ~1200 lines,
# which is too shallow to answer "what do I actually type" (see `analyze`) and
# loses anything more than a few days old. /etc/zshrc runs before ~/.zshrc, so
# setting them here wins.
export HISTFILE=$HOME/.zsh_history
export HISTSIZE=200000
export SAVEHIST=200000

# Record a timestamp + elapsed time per entry. Changes the on-disk format to
# `: <ts>:<elapsed>;<cmd>`, which zsh reads alongside the old plain lines and
# `analyze` already strips, so the existing file stays usable.
setopt EXTENDED_HISTORY
# Append as each command finishes rather than at shell exit: with many tmux
# panes open for days, an exit-time write loses everything from any pane that
# is killed or crashes.
setopt INC_APPEND_HISTORY_TIME
# Collapse only *consecutive* repeats, and drop the surrounding whitespace that
# would otherwise make the same command look like two.
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS
# A leading space keeps a command out of the file — the escape hatch for a
# one-off that embeds a token.
setopt HIST_IGNORE_SPACE
# `history`/`fc` calls are noise in their own output.
setopt HIST_NO_STORE
# Expand a `!` reference onto the command line for review instead of running it.
setopt HIST_VERIFY
#
# Deliberately NOT set: HIST_IGNORE_ALL_DUPS and HIST_EXPIRE_DUPS_FIRST. Both
# delete older copies of a repeated command, which is exactly the frequency
# signal `analyze` counts — they would flatten every command to one occurrence
# and make the ranking meaningless. SHARE_HISTORY is also left off on purpose:
# it would import other panes' commands into this pane's up-arrow, and the
# per-pane ordering is worth more than a merged view here (INC_APPEND_HISTORY_TIME
# already guarantees every pane's commands reach the file).

# aliases
alias c='claude --permission-mode acceptEdits' #: Claude Code を編集許可モードで起動
alias nv='nvim' #: nvim を起動
alias ghd='gh dash' #: gh dash（PR ダッシュボード）を開く

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
export PATH="$HOME/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
