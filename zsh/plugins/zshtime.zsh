# atusy/dotfiles の T-zsh-startuptime に倣い、defer 等の最適化を測って
# から行うための物差し。憶測で defer を増やす前に、まずここで現状値を取る。
#
# Usage:
#   zshtime          # zsh -i -c exit を既定 10 回計測し、平均/最小/最大(ms) を出す
#   zshtime 20        # 回数を指定
#   zshtime --profile # zprof の内訳（プラグイン別の重さ）を1回だけ出す
#
# --profile は .zshrc を汚さない: 一時 ZDOTDIR に zmodload zsh/zprof +
# 本体の .zshrc の source + 末尾 zprof を書いた .zshrc を生成し、そこだけで
# 起動する。~/.zshrc や ~/.zcompdump には触れない。

function _zshtime_run_once() {
  local start end
  start=$(date +%s%N)
  ZDOTDIR="$HOME" zsh -i -c exit &>/dev/null
  end=$(date +%s%N)
  echo $(( (end - start) / 1000000 ))
}

function _zshtime_profile() {
  local tmp_zdotdir
  tmp_zdotdir=$(mktemp -d)
  trap "rm -rf '$tmp_zdotdir'" EXIT INT TERM

  cat > "$tmp_zdotdir/.zshrc" <<EOF
zmodload zsh/zprof
source "$HOME/.zshrc"
zprof
EOF

  ZDOTDIR="$tmp_zdotdir" zsh -i -c exit
}

#: zsh 起動時間を複数回計測し平均/最小/最大を出す（--profile で zprof 内訳）
function zshtime() {
  if [[ "$1" == "--profile" ]]; then
    _zshtime_profile
    return
  fi

  local n=${1:-10}
  if ! [[ "$n" =~ ^[0-9]+$ ]] || (( n < 1 )); then
    echo "zshtime: 回数は 1 以上の整数で指定してください" >&2
    return 1
  fi

  local -a times
  local i
  for (( i = 1; i <= n; i++ )); do
    times+=("$(_zshtime_run_once)")
  done

  local sum=0 min=${times[1]} max=${times[1]} t
  for t in "${times[@]}"; do
    sum=$(( sum + t ))
    (( t < min )) && min=$t
    (( t > max )) && max=$t
  done
  local avg=$(( sum / n ))

  echo "zshtime: ${n}回計測 (ms)  平均=${avg}  最小=${min}  最大=${max}"
}
