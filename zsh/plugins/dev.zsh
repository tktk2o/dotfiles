# tmux dev layout: claude(left) + claude(right)
function dev() {
  if [[ -z "$TMUX" ]]; then
    echo "dev: tmux session required"
    return 1
  fi
  local repo=$(ghq list | fzf-tmux --reverse +m)
  [[ -z "$repo" ]] && return
  local dir="$(ghq root)/$repo"
  local name=$(basename "$repo")

  local claude_cmd="claude --permission-mode acceptEdits"
  tmux new-window -n "$name" -c "$dir" "$claude_cmd"
  tmux split-window -h -c "$dir" "$claude_cmd"
  tmux select-pane -L
}
