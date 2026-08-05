# The return trip for nvim-open: Finder -> terminal.
#
# nvim-open covers Finder -> editor; this covers the direction you hit when a
# download or a Finder dig-around turns into shell work. Reads the frontmost
# Finder window rather than the selection, so it works with nothing selected.

#: Finder の最前面ウィンドウのパスへ cd する
function cdf() {
  local target
  # `POSIX path of` yields a trailing-slash absolute path. A Finder with no
  # open window raises an AppleScript error rather than returning empty, so
  # stderr is kept and surfaced only when the path comes back unusable.
  target=$(osascript -e '
    tell application "Finder"
      if (count of windows) is 0 then return ""
      return POSIX path of (target of front window as alias)
    end tell
  ' 2>/dev/null)

  if [[ -z "$target" ]]; then
    echo "cdf: Finder に開いているウィンドウがありません" >&2
    return 1
  fi
  if [[ ! -d "$target" ]]; then
    echo "cdf: ディレクトリとして開けません: $target" >&2
    return 1
  fi

  cd -- "$target"
}
