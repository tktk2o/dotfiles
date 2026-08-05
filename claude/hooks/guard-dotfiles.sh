#!/bin/bash
# Claude Code PreToolUse hook: block operations that mechanically break this
# dotfiles repo, instead of relying on CLAUDE.md prose being read every time.
#
# Fires before Bash / Write / Edit / MultiEdit. Denies (or, for the softer
# case, warns but allows) a small, deliberately narrow set of operations that
# have caused real damage or drift in this repo:
#
#   1. `./setup.sh` without --dry-run/-n — create_symlink does `rm -rf
#      "$dest"` before linking, so a live run clobbers real files. Deny.
#   2. Direct writes to the individually-symlinked files under ~/.claude/ —
#      Write/Edit that replace-via-rename unlink the symlink and leave an
#      orphan real file at the target, silently dropping it out of the repo.
#      Untracked files (settings.local.json, local.md, local/, RTK.md) are
#      real files there on purpose and are excluded. Deny.
#   3. Same drift risk for the individually-symlinked files under
#      ~/.config/ that this repo owns (whole-directory symlinks like nvim/
#      are safe to edit through — only single-file symlinks are at risk).
#      Deny.
#   4. `git commit --no-verify` / `git push --force` (not
#      --force-with-lease) — CLAUDE.md warns against bypassing hooks and
#      destructive history rewrites, but these are sometimes legitimately
#      necessary (a confirmed pre-commit false positive, a solo-maintainer
#      force-push after rebase). Warn via additionalContext instead of
#      denying, so the operation still proceeds.
#
# Design constraints (this runs on EVERY Bash/Write/Edit/MultiEdit call, in
# every project — settings.json is a global, not project-local, hook):
#   - jq only; no other subprocess spawned.
#   - Silent + exit 0 when nothing matches. No output = allow.
#   - Path checks are literal-prefix, not resolved-realpath: the risk is
#     writing to the symlink's own path, not to whatever it resolves to.

input=$(cat)

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
[ -z "$tool" ] && exit 0

deny() {
    jq -cn --arg reason "$1" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
    exit 0
}

warn() {
    jq -cn --arg ctx "$1" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
    exit 0
}

case "$tool" in
Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
    cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
    [ -z "$cmd" ] && exit 0

    # --- Rule 1: ./setup.sh (or `bash setup.sh` / `sh setup.sh`) without
    # --dry-run/-n, run from inside this dotfiles repo. Scoped to `cwd`
    # containing "dotfiles" so an unrelated project's own setup.sh is not
    # caught, and to a command that actually *invokes* the script (not a
    # mention inside `echo`/a string).
    if printf '%s' "$cmd" | grep -qE '(^|[;&|]\s*)((\.\/)?setup\.sh|(bash|sh|zsh)\s+(\.\/)?setup\.sh)(\s|$)' \
        && printf '%s' "$cwd" | grep -qi 'dotfiles'; then
        if ! printf '%s' "$cmd" | grep -qE -- '(--dry-run|(^|\s)-n(\s|$))'; then
            deny "./setup.sh は create_symlink が実行前に 'rm -rf \$dest' するため、実ファイルを破壊する可能性があります（CLAUDE.md の Verifying Changes 参照）。'./setup.sh --dry-run' で確認するか、'bash -n setup.sh' で静的検証してください。"
        fi
    fi

    # --- Rule 4: git commit --no-verify / git push --force (soft warn) ---
    if printf '%s' "$cmd" | grep -qE '(^|[;&|]\s*)git\s+commit\b' \
        && printf '%s' "$cmd" | grep -qE -- '(^|\s)--no-verify(\s|$)'; then
        warn "git commit --no-verify は pre-commit のリーク検知（denylist / generic-secret スキャン）をバイパスします。確認済みの誤検知の場合のみ使い、そうでなければ ~/.config/git/denylist.txt かパターンの見直しを検討してください。"
    fi
    if printf '%s' "$cmd" | grep -qE '(^|[;&|]\s*)git\s+push\b' \
        && printf '%s' "$cmd" | grep -qE -- '(--force(\s|$)|(^|\s)-f(\s|$))' \
        && ! printf '%s' "$cmd" | grep -q -- '--force-with-lease'; then
        warn "git push --force は他者/自分の以降の push を含め履歴を書き換えます。単独メンテナのリポジトリでも '--force-with-lease' で意図しない上書きを防げるか確認してください。"
    fi
    ;;

Write | Edit | MultiEdit)
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    [ -z "$file" ] && exit 0

    home="${HOME:-/Users/$(whoami)}"

    # --- Rule 2: individually-symlinked files under ~/.claude/ ---
    # (whole-directory symlinks — hooks/, skills/ — are NOT here: writing
    # through them lands inside the repo directly, no drift risk.)
    case "$file" in
    "$home/.claude/CLAUDE.md")
        deny "~/.claude/CLAUDE.md は dotfiles/claude/CLAUDE.md への symlink です。この経路への書き込みは symlink を上書き（drift）させる恐れがあります。dotfiles/claude/CLAUDE.md を直接編集してください。"
        ;;
    "$home/.claude/settings.json")
        deny "~/.claude/settings.json は dotfiles/claude/settings.json への symlink です。dotfiles/claude/settings.json を直接編集してください。"
        ;;
    "$home/.claude/statusline-command.sh")
        deny "~/.claude/statusline-command.sh は dotfiles/claude/statusline-command.sh への symlink です。dotfiles/claude/statusline-command.sh を直接編集してください。"
        ;;
    "$home/.claude/worktree.md")
        deny "~/.claude/worktree.md は dotfiles/claude/worktree.md への symlink です。dotfiles/claude/worktree.md を直接編集してください。"
        ;;
    "$home/.claude/model-policy.md")
        deny "~/.claude/model-policy.md は dotfiles/claude/model-policy.md への symlink です。dotfiles/claude/model-policy.md を直接編集してください。"
        ;;
    "$home/.claude/persona-github.md")
        deny "~/.claude/persona-github.md は dotfiles/claude/persona-github.md への symlink です。dotfiles/claude/persona-github.md を直接編集してください。"
        ;;
    "$home/.config/ghostty/config")
        deny "~/.config/ghostty/config は dotfiles/ghostty/config への symlink です。dotfiles/ghostty/config を直接編集してください。"
        ;;
    "$home/.config/starship.toml")
        deny "~/.config/starship.toml は dotfiles/starship/starship.toml への symlink です。dotfiles/starship/starship.toml を直接編集してください。"
        ;;
    "$home/.config/sheldon/plugins.toml")
        deny "~/.config/sheldon/plugins.toml は dotfiles/sheldon/plugins.toml への symlink です。dotfiles/sheldon/plugins.toml を直接編集してください。"
        ;;
    "$home/.config/mise/config.toml")
        deny "~/.config/mise/config.toml は dotfiles/mise/config.toml への symlink です。dotfiles/mise/config.toml を直接編集してください。"
        ;;
    "$home/.config/karabiner/karabiner.json")
        deny "~/.config/karabiner/karabiner.json は dotfiles/karabiner/karabiner.json への symlink です。dotfiles/karabiner/karabiner.json を直接編集してください。"
        ;;
    "$home/.config/gh/config.yml")
        deny "~/.config/gh/config.yml は dotfiles/gh/config.yml への symlink です。dotfiles/gh/config.yml を直接編集してください。"
        ;;
    "$home/.config/gh-dash/config.yml")
        deny "~/.config/gh-dash/config.yml は dotfiles/gh-dash/config.local.yml（untracked）への symlink です。dotfiles/gh-dash/config.local.yml を直接編集してください。"
        ;;
    "$home/.config/herdr/config.toml")
        deny "~/.config/herdr/config.toml は dotfiles/herdr/config.toml への symlink です。dotfiles/herdr/config.toml を直接編集してください。"
        ;;
    esac
    ;;
esac

exit 0
