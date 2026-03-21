# claude code pane switcher & manager

function _fcl_list() {
  tmux list-panes -a -F '#{pane_id} #{pane_pid}' \
  | while read -r pane_id pid; do
      ps -o args= -p "$pid" 2>/dev/null | command grep -q '^claude' || continue
      local raw_etime=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')
      local elapsed=""
      if [[ "$raw_etime" == *-* ]]; then
        elapsed="${raw_etime%%-*}d${${raw_etime#*-}%%:*}h"
      elif [[ "$raw_etime" == ??:??:?? ]]; then
        elapsed="${raw_etime%%:*}h${${raw_etime#*:}%%:*}m"
      else
        elapsed="${raw_etime%%:*}m"
      fi
      captured=$(tmux capture-pane -t "$pane_id" -p -S -6 2>/dev/null)
      if [[ "$captured" == *'✳'* ]]; then st="🔄"
      elif [[ "$captured" == *'⏸ plan mode'* ]]; then st="📋"
      elif [[ "$captured" == *'⏵⏵ accept edits'* ]]; then st="✏️ "
      else st="⏸ "
      fi
      project_line=$(echo "$captured" | command grep -E '^\s+\S+\s+\(' | tail -1)
      project_line="${project_line#"${project_line%%[^[:space:]]*}"}"
      project="${project_line%% *}"
      branch=""
      [[ "$project_line" =~ '\(([^)]+)\)' ]] && branch="${match[1]}"
      ctx=""
      if [[ "$project_line" =~ '([0-9]+)% context' ]]; then ctx="${match[1]}"
      elif [[ "$project_line" =~ 'ctx[^0-9]*([0-9]+)%' ]]; then ctx="${match[1]}"
      fi
      local c_purple=$'\033[38;2;189;147;249m'
      local c_green=$'\033[38;2;80;250;123m'
      local c_cyan=$'\033[38;2;139;233;253m'
      local c_yellow=$'\033[38;2;241;250;140m'
      local c_reset=$'\033[0m'
      if [[ -n "$project" ]]; then
        printf "%s\t%s ${c_purple}📁 %-35s${c_reset} ${c_green}🌿 %s${c_reset} ${c_cyan}🧠 ctx:%s%%${c_reset} ${c_yellow}⏱ %s${c_reset}\n" "$pane_id" "$st" "$project" "$branch" "$ctx" "$elapsed"
      else
        printf "%s\t%s ${c_purple}📁 %-35s${c_reset} ${c_yellow}⏱ %s${c_reset}\n" "$pane_id" "$st" "$(tmux display-message -t "$pane_id" -p '#{pane_current_path}' | xargs basename)" "$elapsed"
      fi
    done
}

function _fcl_send() {
  local prompt
  printf "prompt> "
  read -r prompt
  [[ -z "$prompt" ]] && return
  for pid in "$@"; do
    tmux send-keys -t "$pid" "$prompt" Enter
  done
  echo "Sent to $# pane(s). Press Enter to return."
  read -r
}

function _fcl_log() {
  local dir="$HOME/claude-logs"
  mkdir -p "$dir"
  for pid in "$@"; do
    local f="$dir/$(date +%Y%m%d-%H%M%S)-${pid}.log"
    tmux capture-pane -t "$pid" -p -S - > "$f"
    echo "Saved: $f"
  done
  echo "Press Enter to return."
  read -r
}

function fcl() {
  if [[ -z "$TMUX" ]]; then
    echo "fcl: tmux session required"
    return 1
  fi

  local src="$HOME/.config/zsh/plugins/fcl.zsh"
  local reload="reload(zsh -c 'source $src && _fcl_list')"

  local result
  result=$(
    _fcl_list \
    | fzf-tmux --reverse --multi --with-nth=2.. --delimiter=$'\t' --ansi \
        --header='enter:switch │ tab:select │ ctrl-s:send │ ctrl-k:compact │ ctrl-x:exit │ ctrl-l:log │ ctrl-r:refresh' \
        --preview='tmux capture-pane -t {1} -p -S -20 2>/dev/null' \
        --preview-window='right:50%:wrap' \
        --bind "ctrl-s:execute(zsh -c 'source $src && _fcl_send {+1}')" \
        --bind "ctrl-k:execute-silent(for pid in {+1}; do tmux send-keys -t \"\$pid\" /compact Enter; done)+$reload" \
        --bind "ctrl-x:execute-silent(for pid in {+1}; do tmux send-keys -t \"\$pid\" /exit Enter; done)+$reload" \
        --bind "ctrl-l:execute(zsh -c 'source $src && _fcl_log {+1}')" \
        --bind "ctrl-r:$reload"
  )
  [[ -z "$result" ]] && return

  local pane_id=$(cut -f1 <<< "$result")
  tmux switch-client -t "$pane_id" && tmux select-pane -t "$pane_id"
}
