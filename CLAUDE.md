# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

macOS dotfiles management repository using symbolic links. Configurations are organized by tool in subdirectories and linked to appropriate locations by `setup.sh`.

## Setup Commands

```bash
# Clone and setup (after Homebrew + git are installed)
mkdir -p ~/src/github.com/tktk2o && cd ~/src/github.com/tktk2o
git clone https://github.com/tktk2o/dotfiles.git && cd dotfiles
./setup.sh                          # Creates all symlinks
brew bundle --file=~/.Brewfile      # Install packages
./setup.sh --dry-run                # Preview what setup.sh would do (safe, no side effects)
```

## Architecture

### Symlink Structure

`setup.sh` creates these symlinks:

| Source (dotfiles/) | Target |
|-------------------|--------|
| `zsh/.zshrc` | `~/.zshrc` |
| `tmux/.tmux.conf` | `~/.tmux.conf` |
| `git/.gitconfig` | `~/.gitconfig` |
| `.ideavimrc` | `~/.ideavimrc` |
| `brew/.Brewfile` | `~/.Brewfile` |
| `nvim/` | `~/.config/nvim` |
| `ghostty/config` | `~/.config/ghostty/config` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `sheldon/plugins.toml` | `~/.config/sheldon/plugins.toml` |
| `karabiner/karabiner.json` | `~/.config/karabiner/karabiner.json` |
| `gh/config.yml` | `~/.config/gh/config.yml` |
| `gh-dash/config.local.yml` (untracked; seeded from `config.yml.example`) | `~/.config/gh-dash/config.yml` |
| `herdr/config.toml` | `~/.config/herdr/config.toml` |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `claude/settings.json` | `~/.claude/settings.json` |
| `claude/worktree.md` | `~/.claude/worktree.md` |
| `claude/model-policy.md` | `~/.claude/model-policy.md` |
| `claude/persona-github.md` | `~/.claude/persona-github.md` |
| `claude/rules/` | `~/.claude/rules` |

> `~/.claude/CLAUDE.md` is a symlink to `claude/CLAUDE.md`, which holds the
> `@~/.claude/RTK.md` / `@worktree.md` / `@model-policy.md` / `@~/.claude/local.md`
> imports. **Relative `@` imports resolve against the symlink's realpath
> (`dotfiles/claude/`), not `~/.claude/`** — so the two untracked files, which live
> only in `~/.claude/`, must be imported by absolute `@~/…` path. Bare `@RTK.md` /
> `@local.md` silently resolved to nothing (no error, no warning: the personal
> instructions were simply never in context), which is why they are spelled out in
> full. `@worktree.md` / `@model-policy.md` sit next to `claude/CLAUDE.md` in this
> repo, so their relative form is correct.
>
> Neither untracked file is checked into dotfiles (`rtk init -g` installs the
> former; see the table below for the latter).
>
> Symptom to watch for: `~/.claude/RTK.md` or `~/.claude/local.md` content missing
> from a session's loaded instructions. Verify with `claude` → `/memory`, or by
> checking that a string unique to each file appears in the session context.
>
> There is no user-level `~/.claude/CLAUDE.local.md` mechanism in Claude Code —
> `CLAUDE.local.md` is *project*-scoped only. Importing an untracked file from
> `~/.claude/` is the documented way to keep personal instructions out of a
> tracked CLAUDE.md ([memory docs](https://code.claude.com/docs/en/memory.md)).

### Deciding where a new Claude instruction goes

`claude/rules/config-maintenance.md` is the judgment-call reference for
"settings.json hook vs. global CLAUDE.md import vs. project CLAUDE.md vs.
skill vs. on-demand `*.md`" — read it before adding a new instruction anywhere
in `~/.claude/` or this repo's `claude/` tree. It also carries a standing audit
of the four files `claude/CLAUDE.md` currently imports (including a
recommendation on `worktree.md`) and the `wc -l` one-liner used to measure the
always-on context cost.

### Posting personas (GitHub is tracked, Slack is not)

`gh pr review` / `gh pr comment` の本文は `claude/persona-github.md` の文体で書く
（`pr-review` skill が参照）。**この 1 枚だけが追跡されている**のは、GitHub 側の
ルールが「`。` を打たない」「1〜2 行」「指摘は shields.io の `ask` / `imo` / `nits` /
`memo` バッジ」「`--request-changes` を使わない」といった**媒体の書き方**に閉じていて、
社名・同僚・社内システム名を一切必要としないため。例文はすべて一般化してある。

Slack 側のペルソナは `~/.claude/local/slack.md` の末尾に置いたまま**追跡しない** —
宛先メンションの ID、ワークスペース名、同僚の呼称という「誰に向けて書くか」が
文体と不可分で、一般化すると意味が残らない。**両者は別物なので流用しない**
（Slack の `:man-bowing:` 記法を GitHub に持ち込んで表示が壊れた事故がある）。

### Local-only (untracked) files — recreate per machine

These hold machine- or company-specific data that must **not** be committed to
this public repo. They are intentionally untracked; a fresh clone will not have
them. After `./setup.sh` on a new machine, recreate each one:

| File | Purpose | How to recreate |
|------|---------|-----------------|
| `gh-dash/config.local.yml` | Live gh-dash config; holds company repo/org names in `prSections`. Symlinked to `~/.config/gh-dash/config.yml`. | `setup.sh` auto-seeds it from `gh-dash/config.yml.example`; then add company-specific sections (per-repo/org `prSections`). Ignored via `gh-dash/.gitignore`. |
| `~/.config/git/denylist.txt` | Company-specific terms for the pre-commit leak scanner (one case-insensitive `grep -E` regex per line). | Recreate manually — the terms are themselves sensitive, so they are never committed. Until it exists, the hook runs generic-secret checks only. See *Pre-commit Leak Scanning* below. |
| `~/.claude/RTK.md` | rtk global instructions imported by `claude/CLAUDE.md` (as `@~/.claude/RTK.md`). | Installed by `rtk init -g` (not part of this repo). |
| `~/.claude/local.md` + `~/.claude/local/*.md` | Machine-local Claude instructions. `local.md` is a **thin hub** imported via `@~/.claude/local.md` (a few lines per topic, always in context); the detail sits in `local/*.md` (e.g. `local/slack.md`: use `slack-cli` over the Slack MCP, the `all` / `ext` profiles, the Slack writing persona) and is **not** imported, so it is read on demand and costs nothing in unrelated sessions. Add topics as new `local/<topic>.md` + one hub line. | Recreate manually — contents name internal workspaces/colleagues, so they stay out of this public repo. Missing on a fresh machine: the `@~/.claude/local.md` import simply resolves to nothing. |
| `~/.claude/settings.local.json` | Machine-local Claude settings: extra `permissions`, `deny` rules (Slack MCP is blocked here), enabled company plugins/marketplaces. | Recreate manually; Claude Code also writes to it as permissions are granted. Not symlinked — `claude/settings.json` is the tracked half. |

### Neovim (LazyVim)

Located in `nvim/`, using LazyVim framework:
- `lua/config/options.lua` - Editor settings (2-space tabs)
- `lua/config/keymaps.lua` - Custom keybindings
- `lua/plugins/` - Plugin configurations

### PR Review Workflow

GitHub PR review integrates gh-dash with Neovim:

```bash
gh dash  # Start dashboard (aliased to `ghd` in zsh/.zshrc)
# Keybindings: d=diff (gh pr diff | hunk patch), R=AI review (`claude --permission-mode auto /review` + diff split), o=browser, m=merge, a=approve, y/Y=copy PR number/URL
```

Neovim leader keys: `<leader>gdo` / `<leader>gdc` / `<leader>gdh` (diffview.nvim, for local diffs)

### Theme

Dracula color scheme across all tools (tmux, starship, Ghostty, Neovim).

## Key Tools

- **Shell**: zsh + sheldon (plugin manager) + starship (prompt)
- **Terminal**: Ghostty
- **Multiplexer**: tmux (prefix: Ctrl+B) + TPM plugins (tmux-resurrect / tmux-continuum for session persistence across reboots — auto-save every 15 min, but auto-restore is **off** (`@continuum-restore 'off'`), so restoring is manual: `prefix + Ctrl-r` for the whole snapshot, `prefix + W` / `twr` for a single window. A restore brings back layout + cwd, and relaunches Claude Code panes with their saved command verbatim so `claude --resume <id>` panes return to their exact session; other programs are not relaunched)
- **Editor**: Neovim with LazyVim, diffview.nvim
- **Diff review**: hunk (review-first TUI — `hunk diff`, `git difftool`, and gh-dash `d`/`R`). delta stays the plain `git diff` pager (`core.pager`).
- **Project navigation**: ghq + fzf (`fgh` function in .zshrc)
- **Past-window restore**: `twr` (`tmux/scripts/tmux-window-restore.sh`, symlinked to `~/.local/bin/twr`; `prefix + W` opens it in a popup)
- **Past-session search**: `csr` (`claude/csr/`, a Go binary built into `~/.local/bin/csr`; `prefix + F` opens it in a popup)
- **Command cheatsheet**: `keys` (`tools/cheatsheet/`, built into `~/.local/bin/keys`; `prefix + g` reads the generated `docs/cheatsheet.md` in a popup)

### Restoring a past window (`twr`)

`twr` lists windows captured across the full tmux-resurrect snapshot **history** (`~/.local/share/tmux/resurrect/tmux_resurrect_*.txt`, not just `last`), de-duplicated by name+cwd (newest kept), and reconstructs the chosen one into the current session via an fzf picker.

- **Reconstruction, not revival**: recreates the window name + layout + each pane's cwd; other programs come back as a plain shell (matches the resurrect scope in `.tmux.conf`).
- **Per-pane claude session**: a pane whose saved command pins a session (`--resume <id>` / `--session-id`) is replayed verbatim (exact session). An id-less claude pane relaunches as `claude --continue` when it is the only claude pane in its cwd, or `claude --resume` (interactive picker) when several id-less claude panes share a cwd — so distinct conversations are not collapsed onto the cwd's most-recent one. (resurrect snapshots only carry a session id when it was in the process args, so id-less panes cannot be mapped to their exact past conversation automatically.)
- **Modes**: `twr` (picker, inside tmux), `twr --list` (print candidates, no tmux/fzf needed). Env: `TMUX_RESURRECT_DIR` (snapshot dir override, used by tests), `TWR_TARGET` (restore into a specific session).
- **New-machine dependency**: relies on the `~/.local/bin/twr` symlink created by `setup.sh` and on tmux-resurrect snapshots existing.

### Searching past Claude sessions (`csr`)

`claude --resume` only lists the *current* project's sessions, so a session whose project you have forgotten is unreachable. `csr` searches **your own prompts** across every log under `~/.claude/projects` (all projects), and resumes the pick in a new tmux window at that session's cwd.

- **Modes**: `csr [query]` (fzf picker; the query pre-fills the filter), `csr --here` (current directory's project only), `csr --list` (TSV, no fzf/tmux needed). Env: `CLAUDE_PROJECTS_DIR`, `CSR_CACHE_DIR`.
- **Why Go, not shell**: the shell+jq version took **8.3s** over ~270MB of logs, and `rg` alone needs 90ms just to read them — a full re-scan per invocation can never be interactive. `csr` keeps a size+mtime-keyed index in `~/.cache/csr/` and re-parses only changed logs: **0.76s cold, 0.02–0.03s warm**.
- **Cache is pure derived data**: deleting `~/.cache/csr/` costs one slow run. A corrupt or unwritable cache silently falls back to a full parse.
- **What counts as a prompt**: `type == "user"` entries minus tool results, `isMeta` entries, and the harness-injected blocks (`<system-reminder>`, `<command-name>`, `<bash-input>`, `<bash-stdout>`, …). On this machine that filters 77,762 user entries down to ~1,885 real prompts.
- **Project name comes from the entry's `cwd` field**, never from the `~/.claude/projects/` directory name — that encoding maps both `/` and `.` to `-` and cannot be reversed.
- **`prefix + F`, not `S`**: tmux's own session picker is lowercase `s`, so `S` would read as a second session list; `C` is taken by `customize-mode`.
- **New-machine dependency**: needs `go` (in `.Brewfile`) — `setup.sh` → `setup_csr` builds the binary, and skips with a warning when go is missing. Nothing is symlinked, so re-run `./setup.sh` (or `cd claude/csr && go build -o ~/.local/bin/csr .`) after editing the source.

### Opening files from Finder / a download (`nvim-open`)

Double-clicking a text-ish file in Finder, or opening one a browser just downloaded, lands it in a **new tmux window** named after the file, in the session you last used.

- **Why Swift, not Go**: macOS hands files only to `.app` bundles, and only as an Apple Event (`kAEOpenDocuments`). A bundled binary that just reads `argv` was measured receiving **`argc=0`** — Go cannot take the event without a cgo/Cocoa event loop. `macos/nvim-open/main.swift` is one binary in two roles: the executable inside `~/Applications/Open in Neovim.app`, and a CLI on `PATH`.
- **Homebrew prefixes**: apps launched by LaunchServices get a minimal `PATH`, so `nvim-open` resolves executables from both `/opt/homebrew/bin` (Apple Silicon) and `/usr/local/bin` (Intel), plus `~/.local/bin` and system paths. Do not hardcode one Homebrew architecture.
- **Why not an AppleScript applet**: that was the first implementation. Its `do shell script` hop measured **154ms ± 62**; the Swift binary starts in **4.5ms ± 0.7**.
- **Peek profile**: opened files use `NVIM_APPNAME=peek` → `nvim-peek/` (symlinked to `~/.config/peek`), a plugin-free config that starts in **30ms** against **~150ms** for LazyVim. `:Full` (or `<leader>f`) respawns the window with the full config when a peek turns into work. `nvim-open --full` skips the peek profile from the start.
- **Registering extensions** is offered by `setup.sh` after the app is built, but requires an explicit `y` because it changes system-wide defaults; `--no-file-handlers` suppresses the prompt. It can also be run later with `macos/scripts/register-file-handlers.sh` (`--list` to inspect, `--revert` to hand them back to TextEdit). The extension list lives in that script — extensions, not UTIs, since claiming `public.plain-text` would drag in far more than intended. `html` / `htm` / `svg` are deliberately excluded: you want those rendered, so they stay with the browser. Binary formats (pdf, images, archives, office documents) are left alone too; Quick Look is faster for those.
- **`nvl`** opens the newest file in `~/Downloads` (`nvl 3` for the newest three) — no macOS integration involved, and usually the quickest way to check a download.
- **New-machine dependencies**: `swiftc` (Xcode Command Line Tools — `setup.sh` skips the build with a warning when missing) and `duti` (in `.Brewfile`). The `.app` is a build product; nothing is symlinked into `~/Applications`.

### Command inventory (`keys` / `docs/cheatsheet.md`)

`docs/cheatsheet.md` lists everything this repo lets you type. It is **generated** — do not edit it by hand.

- **Source of truth is the configs themselves.** `tools/cheatsheet` walks `zsh/`, `tmux/.tmux.conf`, `nvim/lua/plugins/*.lua`, `gh/config.yml`, `gh-dash/config.yml.example`, `claude/skills/*/SKILL.md`, `karabiner/karabiner.json` and the `~/.local/bin` lines of `setup.sh`.
- **Descriptions come from a `#:` annotation** next to each definition — trailing it, or on the line above:
  ```
  alias gs='git status' #: working tree の状態を見る
  #: 過去のウィンドウを復元する（twr, popup）
  bind W display-popup ...
  ```
  The marker is `#:`, **not** `##`: `.tmux.conf` already uses `##` for section labels and banner rules, which would otherwise be swallowed as descriptions. In `.tmux.conf` put the annotation on the line **above** the bind — command lines there carry `#{...}` format strings, so trailing comments are risky.
- **Neovim, gh aliases, skills and Karabiner need no annotation**: `desc = "..."`, the alias body, the SKILL.md frontmatter `description:` and the Karabiner rule `description` are already human-written.
- **Modes**: `keys` (fzf browser; Enter prints the entry and its definition site, executes nothing), `keys <query>`, `keys --doc` (regenerates, then pages the document through glow → less → cat; bound to tmux `prefix + g`), `keys --list`, `keys --generate` (rewrites the doc), `keys --check` (fails when the doc is stale **or** a definition lacks `#:`). Env: `DOTFILES_DIR`.
- **Drift guard**: the pre-commit hook runs `keys --check` when a parsed source is staged and **warns** (does not block) — an undocumented alias is untidy, not dangerous.
- Internal shell helpers named `_foo` are skipped, so they never need annotating.
- Built by `setup.sh` → `setup_keys` (needs `go`, same as `csr`).

### Measuring zsh startup time (`zshtime`)

atusy/dotfiles justifies deferring `compinit` with a measured startup-time
script; this repo already does most of the same optimizations (`zsh-defer` for
`zsh-autosuggestions` / `zsh-syntax-highlighting` / `zsh-completions` / local
plugins, cached `sheldon source`, cached `starship init` / `zoxide init`,
deferred `mise activate`) but had no measurement tool of its own. `zshtime`
(`zsh/plugins/zshtime.zsh`) fills that gap — **measure before optimizing**,
not the reverse.

- **Modes**: `zshtime [n]` runs `zsh -i -c exit` `n` times (default 10) and
  prints average/min/max in ms — a single run has too much variance to act
  on. `zshtime --profile` runs once with `zmodload zsh/zprof` wrapped around
  the real `.zshrc` (via a throwaway `ZDOTDIR`, so `~/.zshrc` and
  `~/.zcompdump` are never touched) and prints the `zprof` breakdown.
- **Measured on this machine**: 10 runs → **avg 96ms, min 66ms, max 203ms** —
  well under the ~200ms threshold that would justify further deferral, so
  **no optimization was made**. `--profile` shows `compinit`/`compdef` as the
  dominant relative cost (zprof's own per-call instrumentation inflates the
  absolute numbers, especially with `compdef`'s ~820 calls, so its ms figures
  read much higher than the real wall-clock average — only the ranking is
  meaningful). `compinit` must stay ahead of `fzf-tab` per the comment in
  `sheldon/plugins.toml`, so deferring it like atusy does would risk breaking
  `fzf-tab` and was intentionally not attempted here.
- **Known gap, out of scope for this measurement**: `zsh/.zshrc` sets no
  `HISTSIZE` / `SAVEHIST` / `HISTFILE` / history `setopt`s. The effective
  values (`echo $HISTSIZE $SAVEHIST` in an interactive shell) come from
  outside this repo, and `~/.zsh_history` has only ~1200 lines — shallow
  compared to other dotfiles setups. Left unfixed pending a decision on
  desired history size.

### Sleep prevention is Claude Code's job, not this repo's

**Do not add `caffeinate` to any entry point that starts `claude`.** Claude Code
already spawns `caffeinate -i -t 300` itself and respawns it as the 300s timer
expires, so the Mac stays awake for the whole session. Measured on 2.1.222: the
`caffeinate` process's parent is the `claude` process, and every active session had
one. This was tried in this repo (wrapping the `c` alias, `dev`, gh-dash `R`, `twr`
and `csr`) and reverted as redundant.

- **There is no way to turn it off** — no `settings.json` key, no env var.
  [anthropics/claude-code#21432](https://github.com/anthropics/claude-code/issues/21432)
  is an open request for a `disableCaffeinate` setting, which is the evidence that
  none exists. `killall caffeinate` does not stick: it is respawned, and the binary
  logs "Restarting sleep inhibitor to maintain prevention"
  ([#64522](https://github.com/anthropics/claude-code/issues/64522)).
- **A wrapper is worse than nothing here**: `caffeinate -i claude` holds the
  assertion for as long as the process lives, so a pane left open for days never lets
  the machine sleep. The built-in inhibitor was not observed on long-idle panes.
- Related known bug: caffeinate processes leaking by the thousand
  ([#28046](https://github.com/anthropics/claude-code/issues/28046), closed as not
  planned). If the Mac refuses to sleep, count them with `pgrep -x caffeinate`
  before suspecting anything in this repo.

Two measurement traps, both hit while investigating this:

- **`caffeinate -i cmd` does not nest cmd underneath it.** It execs *itself* into
  cmd and forks a child to hold the assertion, so the parent keeps the pid and
  `ps -o args=` reads `cmd`, never `caffeinate …`. Process-tree reasoning that
  assumes the opposite is wrong (this is also why `fcl`'s `^claude` match and
  `pgrep -P <pane_pid> -x claude` are correct as written).
- **Use `pgrep -x caffeinate`, not `pgrep -f`.** `-f` matches the watcher script's
  own command line and reports phantom processes that look like a steady assertion.

## Adding New Configurations

1. Create subdirectory: `mkdir toolname/`
2. Add config file(s) to the subdirectory
3. Add symlink command to `setup.sh` — always via the `create_symlink` helper, never a raw `ln -s`
4. If installable via Homebrew, add to `brew/.Brewfile`
5. If it adds something you type (alias, function, key binding, executable), annotate it with `#:` and run `keys --generate`

Shell scripts are **bash** (`#!/bin/bash`) with `set -e`. `setup.sh` is idempotent and supports `./setup.sh --no-brew`, `./setup.sh --no-file-handlers`, and `./setup.sh --dry-run` (or `-n`).

## Verifying Changes

- **`./setup.sh --dry-run` is safe to run anytime**, including on this machine with
  real dotfiles already in place. It performs no side effects — no `mkdir`/`rm`/`ln`,
  no installs, no interactive prompts — and instead prints what each step would do.
  `create_symlink`'s dry-run path distinguishes three states for each `dest`: already
  a correct symlink (no-op), a symlink pointing elsewhere (would relink), and a real
  file/directory (a loud `WOULD DELETE` warning — this is exactly what `rm -rf "$dest"`
  would destroy in a real run, and the reason `--dry-run` exists).
- **Still never run plain `./setup.sh` (without `--dry-run`) to "test" a change on
  this machine** — `create_symlink` does `rm -rf "$dest"` before linking, clobbering
  real files at target paths. `--dry-run` covers the "does this even do what I
  expect" question; it does not make the real run safe to fire off casually.
- Validate shell edits statically too:
  - `bash -n setup.sh` (syntax check; run after every edit)
  - `shellcheck setup.sh` if installed (`brew install shellcheck`)
- To confirm a symlink line resolves, check the source path exists and inspect the target with `ls -la`, or just read the `--dry-run` output for that line.

## Commit Conventions

Single-maintainer personal repo — commit directly to `main`, no feature branches or PRs for routine changes. Use worktrees only for the cases in `claude/worktree.md` (PoC / upstream-dependent / parallel work).

## Never commit this — what must stay out of this repo

This is a **public** repo. The categories below must never be committed, in any
file (including CLAUDE.md, comments, commit messages and example configs). This
list is intentionally category-level: writing down the actual names/values would
itself be the leak. When a config needs one of these, keep the config untracked
and record it in *Local-only (untracked) files* above instead.

| Category | Examples of what this covers | Where it lives instead |
|----------|------------------------------|------------------------|
| Credentials & tokens | API keys, OAuth/bot/user tokens (`xox*`), private keys, `.netrc`, session cookies | outside the repo entirely (keychain / tool-managed credential files) |
| Employer identity & internal naming | company/product names, internal repo, org and team names, service and system codenames, internal URLs and hostnames | untracked local config (`gh-dash/config.local.yml`, `~/.claude/local/*.md`) |
| People | colleague names, nicknames/handles, Slack user IDs, email addresses other than the git author identity | `~/.claude/local/*.md` |
| Internal channels & workspaces | Slack channel names/IDs, workspace or profile names, mailing lists | `~/.claude/local/*.md` |
| Internal ticket / doc references | issue keys, Jira/Confluence/Drive URLs, dashboard and monitor links | `~/.claude/local/*.md` |
| Business data | customer/pharmacy/store names, query results, log excerpts, trace IDs, metric values from production | `~/docs/` (not git-managed at all) |
| Machine-specific paths worth hiding | anything embedding an internal mount, VPN host or company account | untracked local config |

The list of *terms* that trip the scanner is `~/.config/git/denylist.txt` — local
and untracked, for the same reason this table has no concrete names.

Absolute local paths under `$HOME` and this machine's username are fine (they are
already all over `setup.sh`), as is the git author identity in `git/.gitconfig`.

### Pre-commit Leak Scanning

A `pre-commit` hook enforces the above. Two layers:

- **Generic secrets**: patterns baked into `git/hooks/pre-commit` (AWS/GitHub/Slack/Google keys, private-key blocks). Safe to keep tracked.
- **Company-specific terms**: loaded at runtime from a **local, untracked** file `~/.config/git/denylist.txt` (one `grep -E`, case-insensitive regex per line). This file is deliberately *not* tracked — the terms are themselves sensitive, so committing the denylist would defeat its purpose.

The hook is scoped to this repo only via repo-local `core.hooksPath` (set by `setup.sh` → `setup_git_hooks`), so it never false-positives on work repos that legitimately contain company names.

**New-machine migration**: after `./setup.sh`, recreate `~/.config/git/denylist.txt` manually (it is not in the repo). Until it exists, the hook runs generic-secret checks only and prints a warning. Bypass a verified false positive with `git commit --no-verify`.

## RTK (Bash-output token filter for Claude Code)

`rtk` (installed via `brew/.Brewfile`) compacts Bash tool output before it reaches the model. It is wired through the `PreToolUse` hook in `claude/settings.json` as the command `rtk hook claude` — no custom shim script is used (earlier versions of this repo had a `claude/hooks/rtk-rewrite.sh` wrapper; that has been removed).

### Layout

- **Binary**: `brew "rtk"` in `brew/.Brewfile`
- **Hook registration**: `claude/settings.json` → `hooks.PreToolUse[].hooks[].command = "rtk hook claude"`
- **Project filters**: `.rtk/filters.toml` (committed, currently just the stub template)

### New-machine migration

After `./setup.sh` + `brew bundle`, project filters must be trusted once per machine (rtk refuses to apply untrusted project filters for security):

```bash
cd ~/src/github.com/tktk2o/dotfiles && rtk trust
```

`setup.sh` prints this reminder when filters are not yet trusted; it cannot run the command automatically because `rtk trust` is interactive by design.

### Health check (for future Claude sessions)

If any of these fail, rtk is misconfigured:

```bash
command -v rtk                                  # binary is on PATH
rtk trust --list | grep dotfiles/.rtk           # this repo's filters are trusted
ls -la ~/.claude/settings.json                  # symlink to dotfiles/claude/settings.json
grep 'rtk hook claude' ~/.claude/settings.json  # correct hook command is wired
```

Symptom of forgotten `rtk trust`: every Bash tool result starts with `[rtk] WARNING: untrusted project filters (.rtk/filters.toml)`. That noise also corrupts downstream parsing of tool output.

RTK moves fast; if the commands or CLI surface above have changed, prefer `rtk --help` / `rtk trust --help` over blindly trusting this doc.
