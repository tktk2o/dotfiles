# ghq + fzf: fuzzy find and cd to ghq-managed repos
#: ghq 管理下のリポジトリをファジー検索して cd する
function fgh() {
  declare -r REPO_NAME="$(ghq list | fzf-tmux --reverse +m)"
  [[ -n "${REPO_NAME}" ]] && cd "$(ghq root)/${REPO_NAME}"
}
