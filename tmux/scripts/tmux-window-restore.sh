#!/bin/bash
# tmux-window-restore (twr) — list past tmux windows captured in tmux-resurrect
# snapshots and restore a chosen one into the current session.
#
# Data source: ALL tmux-resurrect snapshot files (full history, not just `last`):
#   ${TMUX_RESURRECT_DIR:-~/.local/share/tmux/resurrect}/tmux_resurrect_*.txt
# Windows are de-duplicated by name+cwd, keeping the most recent snapshot.
#
# A chosen window is reconstructed as: new-window with the saved name + layout,
# each pane cd'd to its saved cwd, and claude panes relaunched as
# `claude --continue` (other programs are left as a plain shell, matching the
# resurrect scope in .tmux.conf). This is reconstruction, not process revival.
#
# Usage:
#   twr              interactive picker (fzf); run inside tmux
#   twr --list       print candidates without fzf (scriptable; no tmux needed)
#   prefix + W       picker in a tmux popup (bound in .tmux.conf)
#
# Env:
#   TMUX_RESURRECT_DIR   override snapshot dir (used by tests)
#   TWR_TARGET           restore into this session/target instead of current

set -euo pipefail

RESURRECT_DIR="${TMUX_RESURRECT_DIR:-$HOME/.local/share/tmux/resurrect}"
US=$'\037' # unit separator: between a pane's cwd and command
RS=$'\036' # record separator: between panes of a window

# ---- fzf preview mode (internal) -------------------------------------------
if [ "${1:-}" = "--__preview" ]; then
    line="${2:-}"
    name="$(printf '%s' "$line" | cut -f2)"
    packed="$(printf '%s' "$line" | cut -f4)"
    printf 'window: %s\n\n' "$name"
    i=0
    IFS="$RS" read -r -a _panes <<< "$packed"
    for seg in "${_panes[@]}"; do
        i=$((i + 1))
        printf '  pane %d\n    cwd: %s\n    cmd: %s\n' "$i" "${seg%%"$US"*}" "${seg#*"$US"}"
    done
    exit 0
fi

# ---- discover snapshots ----------------------------------------------------
shopt -s nullglob
snaps=("$RESURRECT_DIR"/tmux_resurrect_*.txt)
shopt -u nullglob
if [ "${#snaps[@]}" -eq 0 ]; then
    echo "twr: no resurrect snapshots in $RESURRECT_DIR" >&2
    exit 1
fi
IFS=$'\n' snaps=($(printf '%s\n' "${snaps[@]}" | sort -r)); unset IFS # newest first

# ---- build the candidate list ----------------------------------------------
# Emits, per unique window (newest kept): DISPLAY \t name \t layout \t packedpanes
build_list() {
    awk -F'\t' -v US="$US" -v RS2="$RS" '
    FNR==1 {
        m = split(FILENAME, a, "_"); tok = a[m]; sub(/\.txt$/, "", tok)
        tstr = substr(tok,1,4)"-"substr(tok,5,2)"-"substr(tok,7,2)" "substr(tok,10,2)":"substr(tok,12,2)
        delete pc; delete pcwd; delete pcmd
    }
    $1 == "pane" {
        wi = $3
        cwd = $8; sub(/^:/, "", cwd); gsub(/\\ /, " ", cwd)
        cmd = $11; sub(/^:/, "", cmd)
        pc[wi]++
        pcwd[wi, pc[wi]] = cwd
        pcmd[wi, pc[wi]] = cmd
    }
    $1 == "window" {
        wi = $3; name = $4; sub(/^:/, "", name); layout = $7
        cnt = (wi in pc) ? pc[wi] : 0
        if (cnt == 0) next
        cwd1 = pcwd[wi, 1]
        key = name US cwd1
        if (key in seen) next
        seen[key] = 1
        packed = ""; cl = 0
        for (i = 1; i <= cnt; i++) {
            seg = pcwd[wi, i] US pcmd[wi, i]
            packed = (i == 1) ? seg : packed RS2 seg
            if (index(pcmd[wi, i], "claude") > 0) cl = 1
        }
        short = cwd1; sub(/.*\//, "", short)
        extra = (cnt > 1) ? (" +" (cnt - 1) "p") : ""
        tag = cl ? " [claude]" : ""
        disp = sprintf("%s  %-18s  %s%s%s", tstr, name, short, extra, tag)
        printf "%s\t%s\t%s\t%s\n", disp, name, layout, packed
    }
    ' "${snaps[@]}"
}

# ---- reconstruct a window from a picked "DISPLAY\tname\tlayout\tpacked" line -
reconstruct() {
    local line="$1"
    local name layout packed
    name="$(printf '%s' "$line" | cut -f2)"
    layout="$(printf '%s' "$line" | cut -f3)"
    packed="$(printf '%s' "$line" | cut -f4)"
    [ -n "$packed" ] || { echo "twr: empty selection" >&2; return 1; }

    local -a pane_ids=() pane_cmds=() segs=() target_args=()
    [ -n "${TWR_TARGET:-}" ] && target_args=(-t "$TWR_TARGET")
    local first=1 anchor="" pid cwd cmd seg

    IFS="$RS" read -r -a segs <<< "$packed"
    for seg in "${segs[@]}"; do
        cwd="${seg%%"$US"*}"
        cmd="${seg#*"$US"}"
        [ -d "$cwd" ] || cwd="$HOME" # fall back if the dir is gone
        if [ "$first" -eq 1 ]; then
            pid="$(tmux new-window "${target_args[@]}" -P -F '#{pane_id}' -n "$name" -c "$cwd")"
            first=0
        else
            pid="$(tmux split-window -P -F '#{pane_id}' -t "$anchor" -c "$cwd")"
        fi
        anchor="$pid"
        pane_ids+=("$pid")
        pane_cmds+=("$cmd")
    done

    tmux select-layout -t "${pane_ids[0]}" "$layout" 2>/dev/null || true

    local i
    for i in "${!pane_ids[@]}"; do
        case "${pane_cmds[$i]}" in
            *claude*) tmux send-keys -t "${pane_ids[$i]}" "claude --continue" C-m ;;
        esac
    done

    tmux select-window -t "${pane_ids[0]}" 2>/dev/null || true
    tmux display-message "twr: restored window '$name' (${#pane_ids[@]} pane(s))" 2>/dev/null || true
}

# ---- modes -----------------------------------------------------------------
case "${1:-}" in
    --list)
        build_list | cut -f1
        exit 0
        ;;
    --__raw) # internal: raw candidate lines (tests)
        build_list
        exit 0
        ;;
    --__restore) # internal: reconstruct without fzf (tests)
        reconstruct "${2:-}"
        exit 0
        ;;
esac

if [ -z "${TMUX:-}" ]; then
    echo "twr: must be run inside tmux (or use --list)." >&2
    exit 1
fi

self="$(command -v twr || echo "$0")"
sel="$(build_list | fzf \
    --delimiter=$'\t' --with-nth=1 \
    --prompt='restore window > ' \
    --header='past tmux windows (resurrect history) — Enter restores into this session' \
    --preview="$self --__preview {}" \
    --preview-window=right,50%,wrap)" || exit 0
[ -n "$sel" ] || exit 0
reconstruct "$sel"
