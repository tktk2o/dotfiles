# Peek at what you just downloaded, without leaving the terminal.

#: Downloads の最新ファイルを nvim で開く（引数で件数、既定 1）
function nvl() {
  local n=${1:-1}
  local -a files
  # (.om[1,n]N): regular files, newest first, take n, empty if none.
  files=(~/Downloads/*(.om[1,$n]N))

  if (( ! ${#files} )); then
    echo "nvl: ~/Downloads に開けるファイルがありません" >&2
    return 1
  fi

  nvim -p -- "${files[@]}"
}
