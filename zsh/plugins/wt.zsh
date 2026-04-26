# Git worktree helpers (interactive use)
#
# wta - add a git worktree under .worktrees/
#
# Usage: wta <branch-name> [base-ref]
#   <branch-name>   New branch name (e.g. poc/foo-bar)
#   [base-ref]      Base ref to branch from (default: origin/main)
#
# Behavior:
#   - Must be run from a main repo (not from inside a worktree).
#   - Creates .worktrees/ with .gitignore (* pattern) on first use.
#   - Worktree alias = branch name with / replaced by -.
#   - cd's into the new worktree on success.
function wta() {
  local branch="$1"
  local base="${2:-origin/main}"
  if [[ -z "$branch" ]]; then
    echo "Usage: wta <branch-name> [base-ref]" >&2
    return 1
  fi
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "wta: not in a git repository" >&2
    return 1
  }
  local git_dir
  git_dir=$(git rev-parse --git-dir 2>/dev/null)
  case "$git_dir" in
    */worktrees/*)
      echo "wta: already inside a worktree. cd to main repo first." >&2
      return 1
      ;;
  esac
  local branch_alias="${branch//\//-}"
  local target="$repo_root/.worktrees/$branch_alias"
  if [[ ! -d "$repo_root/.worktrees" ]]; then
    mkdir "$repo_root/.worktrees"
    echo '*' > "$repo_root/.worktrees/.gitignore"
  fi
  git fetch origin || return $?
  git worktree add -b "$branch" "$target" "$base" || return $?
  cd "$target"
}

# wtj - jump to a git worktree via fzf
#
# Usage: wtj
#   Lists worktrees in the current repo (main + all worktrees) and
#   cd's to the selected one.
function wtj() {
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "wtj: not in a git repository" >&2
    return 1
  fi
  local selected
  selected=$(git worktree list | fzf-tmux --reverse +m)
  [[ -z "$selected" ]] && return
  local target=$(awk '{print $1}' <<< "$selected")
  cd "$target"
}
