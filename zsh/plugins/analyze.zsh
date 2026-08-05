# What do I actually type? — the input side of `keys`.
#
# `keys` lists what this repo *offers*; this lists what you *use*. The gap in
# both directions is the interesting part:
#   - a raw command high in the ranking wants an alias
#   - an alias absent from `--unused` output is dead weight worth deleting
#
# Reads $HISTFILE (falling back to ~/.zsh_history) rather than the in-memory
# history, so it reflects every shell, not just this one. The file may hold
# invalid UTF-8 (zsh escapes metafied bytes), so every read goes through
# `iconv -c` to drop the offending bytes instead of aborting the pipeline.

#: 履歴から使用頻度の高いコマンドを集計する（--unused で未使用の定義を列挙）
function analyze() {
  local histfile=${HISTFILE:-$HOME/.zsh_history}
  if [[ ! -r "$histfile" ]]; then
    echo "analyze: 履歴ファイルが読めません: $histfile" >&2
    return 1
  fi

  if [[ "$1" == "--unused" || "$1" == "-u" ]]; then
    _analyze_unused "$histfile"
    return
  fi

  local n=${1:-15}
  if [[ ! "$n" =~ '^[0-9]+$' ]]; then
    echo "analyze: 使い方: analyze [件数] | analyze --unused" >&2
    return 1
  fi

  local total
  total=$(_analyze_commands "$histfile" | wc -l | tr -d ' ')
  echo "$histfile  ($total commands)"
  echo ""
  _analyze_commands "$histfile" \
    | sort | uniq -c | sort -rn | head -n "$n" \
    | awk -v total="$total" '{
        pct = total > 0 ? $1 * 100 / total : 0
        printf "  %5d  %5.1f%%  %s\n", $1, pct, $2
      }'
}

# One bare command name per line.
#
# Strips the extended-history prefix (`: <ts>:<elapsed>;`) whether or not
# EXTENDED_HISTORY is on, splits pipelines and `&&`/`;` chains so the second
# half of `git add . && git commit` is counted too, then drops leading
# environment assignments (FOO=bar cmd) and the wrappers that would otherwise
# dominate the ranking over the command they wrap.
#
# `&&` is rewritten to `|` before the split rather than to `\n`: BSD sed emits a
# literal `n` for `\n` in a replacement, so the newline has to come from `tr`.
#
# The peeling loop drops whole fields with awk's own field splitting instead of
# `sub(/^[^ ]+ */, "")` — that pattern is anchored at the start of the line and
# silently matches nothing when the history entry is indented, leaving $0
# unchanged and spinning the loop forever.
function _analyze_commands() {
  iconv -c -f UTF-8 -t UTF-8 "$1" \
    | sed -E -e 's/^: [0-9]+:[0-9]*;//' -e 's/&&/|/g' \
    | tr '|;' '\n\n' \
    | awk '
        function _shift_field() {
          for (i = 1; i < NF; i++) $i = $(i + 1)
          NF--
        }
        {
          while (NF > 0 && ($1 ~ /^[A-Za-z_][A-Za-z0-9_]*=/ ||
                            $1 == "sudo" || $1 == "command" || $1 == "time" ||
                            $1 == "caffeinate" || $1 == "noglob")) {
            _shift_field()
            # a wrapper flag (caffeinate -i) is not the command either
            while (NF > 0 && $1 ~ /^-/) _shift_field()
          }
          if (NF > 0) print $1
        }
      '
}

# Commands this repo defines that never appear in history. `keys --list` is the
# source of truth for "what is defined", so a definition without a `#:`
# annotation is invisible here too — which is the same drift the pre-commit
# hook already warns about.
function _analyze_unused() {
  if ! command -v keys > /dev/null 2>&1; then
    echo "analyze: keys が必要です（./setup.sh の setup_keys でビルドされます）" >&2
    return 1
  fi

  local -a used defined unused
  used=("${(f)$(_analyze_commands "$1" | sort -u)}")
  # `keys --list` columns: <type> <name> <description>  (location)
  defined=("${(f)$(keys --list | awk '$1 == "shell" { print $2 }' | sort -u)}")

  for cmd in $defined; do
    (( ${used[(Ie)$cmd]} )) || unused+=("$cmd")
  done

  if (( ! ${#unused} )); then
    echo "未使用の定義はありません（${#defined} 件すべて履歴にあります）"
    return 0
  fi

  echo "履歴に現れない定義 ${#unused}/${#defined} 件:"
  echo ""
  local cmd
  for cmd in $unused; do
    keys --list | awk -v c="$cmd" '$1 == "shell" && $2 == c { $1=""; print "  " $0 }'
  done
}
