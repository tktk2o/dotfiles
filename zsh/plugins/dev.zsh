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

  # caffeinate -i: a long agent run should not be cut short by idle sleep.
  # It exits with claude, so nothing has to release the assertion.
  local claude_cmd="caffeinate -i claude --permission-mode acceptEdits"
  tmux new-window -n "$name" -c "$dir" "$claude_cmd"
  tmux split-window -h -c "$dir" "$claude_cmd"
  tmux select-pane -L
}
