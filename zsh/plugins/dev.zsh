# tmux dev layout: claude(right) + nvim(top-left) + terminal(bottom-left)
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
  tmux split-window -v -c "$dir"
  tmux select-pane -t 0
}
