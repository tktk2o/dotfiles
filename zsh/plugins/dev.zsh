# tmux dev layout: claude(left) + claude(right)
#: ghq リポジトリを選び、Claude Code を左右ペインに並べた tmux ウィンドウを作る
function dev() {
  if [[ -z "$TMUX" ]]; then
    echo "dev: tmux session required"
    return 1
  fi
  local repo=$(ghq list | fzf-tmux --reverse +m)
  [[ -z "$repo" ]] && return
  local dir="$(ghq root)/$repo"
  local name=$(basename "$repo")

  # The panes run as tmux commands, where the `c` function does not exist and
  # pane 2 would race pane 1 in --name-for; names follow the same <name>/<name>-2 rule.
  tmux new-window -n "$name" -c "$dir" "claude -n ${(q)name}"
  tmux split-window -h -c "$dir" "claude -n ${(q)name}-2"
  tmux select-pane -L
}
