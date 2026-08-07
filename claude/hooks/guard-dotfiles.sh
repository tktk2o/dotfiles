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
#      Also catches the same call hidden behind `cd .../dotfiles && ./setup.sh`
#      — cwd alone can't be trusted to reflect that once the command chains
#      a `cd` into a dotfiles checkout before invoking the script.
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
#   5. Bash equivalents of rule 2/3's Write/Edit drift risk — a shell
#      redirect (`>`/`>>`), `tee`, or `sed -i` targeting the same protected
#      symlink paths unlinks the symlink exactly like a Write/Edit would, but
#      the earlier rules only ever inspected `tool_input.file_path`, which a
#      Bash tool call never sets. Deny, same path list as rule 2/3.
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

    home="${HOME:-/Users/$(whoami)}"

    # --- Rule 1: ./setup.sh (or `bash setup.sh` / `sh setup.sh`) without
    # --dry-run/-n, run from inside this dotfiles repo. Scoped to `cwd`
    # containing "dotfiles" so an unrelated project's own setup.sh is not
    # caught, and to a command that actually *invokes* the script (not a
    # mention inside `echo`/a string).
    # The dry-run flag must be tested against setup.sh's OWN arguments, not the
    # whole command line: `./setup.sh; echo -n done` contains `-n` and would
    # otherwise be waved through, which is a false negative on the dangerous
    # side. `sed` extracts the invocation up to the next separator and the flag
    # check runs on that segment alone.
    # The trailing class must accept a separator, not just whitespace/end:
    # `./setup.sh; echo x` put a `;` immediately after the script name and
    # slipped past a `(\s|$)` anchor entirely.
    # `cwd` alone misses the common bypass of `cd .../dotfiles && ./setup.sh`
    # run from an unrelated starting directory, so also treat a `cd` segment
    # that targets a dotfiles path anywhere earlier in the command as scoping
    # the call, without depending on `cwd` at all.
    if printf '%s' "$cmd" | grep -qE '(^|[;&|]\s*)((\.\/)?setup\.sh|(bash|sh|zsh)\s+(\.\/)?setup\.sh)([[:space:];&|)]|$)' \
        && { printf '%s' "$cwd" | grep -qi 'dotfiles' \
             || printf '%s' "$cmd" | grep -qiE '(^|[;&|]\s*)cd\s+[^;&|]*dotfiles'; }; then
        segment=$(printf '%s' "$cmd" | sed -E 's/.*((^|[;&|])[[:space:]]*)((\.\/)?setup\.sh|(bash|sh|zsh)[[:space:]]+(\.\/)?setup\.sh)/\3/' | sed -E 's/[;&|].*//')
        if ! printf '%s' "$segment" | grep -qE -- '(--dry-run|(^|[[:space:]])-n([[:space:]]|$))'; then
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

    # --- Rule 5: shell redirect / tee / sed -i onto the protected symlink
    # paths (same list as rule 2/3, and the same literal-path matching style
    # — no realpath resolution). A Write/Edit tool call never reaches this
    # branch when the same drift is done via `echo x > ~/.zshrc`, `cmd | tee
    # ~/.claude/settings.json`, or `sed -i '' ... ~/.gitconfig`, so those need
    # their own check here rather than relying on rule 2/3's file_path check.
    protected_paths=(
        "$home/.zshrc"
        "$home/.tmux.conf"
        "$home/.gitconfig"
        "$home/.gitignore_global"
        "$home/.Brewfile"
        "$home/.local/bin/twr"
        "$home/.claude/CLAUDE.md"
        "$home/.claude/settings.json"
        "$home/.claude/statusline-command.sh"
        "$home/.claude/worktree.md"
        "$home/.claude/model-policy.md"
        "$home/.claude/persona-github.md"
        "$home/.config/ghostty/config"
        "$home/.config/starship.toml"
        "$home/.config/sheldon/plugins.toml"
        "$home/.config/mise/config.toml"
        "$home/.config/karabiner/karabiner.json"
        "$home/.config/gh/config.yml"
        "$home/.config/gh-dash/config.yml"
        "$home/.config/herdr/config.toml"
    )
    for p in "${protected_paths[@]}"; do
        # A Bash command's raw text still has "~/..." unexpanded (bash itself
        # expands "~" at execution time, after this hook already inspected
        # it), so both the absolute-path and "~"-shorthand forms need to be
        # checked — matching only $home would miss the common `> ~/.zshrc`
        # form entirely.
        tilde_p="~${p#"$home"}"
        esc=$(printf '%s' "$p" | sed -E 's/[.[\*^$/]/\\&/g')
        esc_tilde=$(printf '%s' "$tilde_p" | sed -E 's/[.[\*^$/]/\\&/g')
        alt="($esc|$esc_tilde)"
        # Redirect: the path must sit right after > / >> (optionally quoted),
        # so `echo "> $p" | mail` (the path merely mentioned) is not caught.
        if printf '%s' "$cmd" | grep -qE ">{1,2}[[:space:]]*[\"']?$alt([\"']|[[:space:];&|]|\$)"; then
            deny "Bash によるリダイレクトが dotfiles の symlink 対象 ($p) に書き込もうとしています。dotfiles リポジトリ内の実体ファイルを直接編集してください。"
        fi
        # tee / sed -i: looser — the path just needs to co-occur with the
        # command name, since tee/sed take the path as a plain argument that
        # can appear anywhere after the flags.
        if printf '%s' "$cmd" | grep -qE '\btee\b' && printf '%s' "$cmd" | grep -qE -- "$alt"; then
            deny "Bash の tee が dotfiles の symlink 対象 ($p) に書き込もうとしています。dotfiles リポジトリ内の実体ファイルを直接編集してください。"
        fi
        if printf '%s' "$cmd" | grep -qE '\bsed\b.*-i' && printf '%s' "$cmd" | grep -qE -- "$alt"; then
            deny "Bash の sed -i が dotfiles の symlink 対象 ($p) を書き換えようとしています。dotfiles リポジトリ内の実体ファイルを直接編集してください。"
        fi
    done
    ;;

Write | Edit | MultiEdit)
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    [ -z "$file" ] && exit 0

    home="${HOME:-/Users/$(whoami)}"

    # --- Rule 2: individually-symlinked files under ~/.claude/ and ~/ ---
    # (whole-directory symlinks — hooks/, skills/, rules/, nvim/, zsh/plugins/ —
    # are NOT here: writing through them lands inside the repo directly, no
    # drift risk.)
    case "$file" in
    "$home/.zshrc")
        deny "~/.zshrc は dotfiles/zsh/.zshrc への symlink です。dotfiles/zsh/.zshrc を直接編集してください。"
        ;;
    "$home/.tmux.conf")
        deny "~/.tmux.conf は dotfiles/tmux/.tmux.conf への symlink です。dotfiles/tmux/.tmux.conf を直接編集してください。"
        ;;
    "$home/.gitconfig")
        deny "~/.gitconfig は dotfiles/git/.gitconfig への symlink です。dotfiles/git/.gitconfig を直接編集してください。"
        ;;
    "$home/.gitignore_global")
        deny "~/.gitignore_global は dotfiles/git/.gitignore_global への symlink です。dotfiles/git/.gitignore_global を直接編集してください。"
        ;;
    "$home/.Brewfile")
        deny "~/.Brewfile は dotfiles/brew/.Brewfile への symlink です。dotfiles/brew/.Brewfile を直接編集してください。"
        ;;
    "$home/.local/bin/twr")
        deny "~/.local/bin/twr は dotfiles/tmux/scripts/tmux-window-restore.sh への symlink です。dotfiles/tmux/scripts/tmux-window-restore.sh を直接編集してください。"
        ;;
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
