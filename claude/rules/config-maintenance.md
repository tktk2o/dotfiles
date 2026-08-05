# Config Maintenance (for Claude)

Every line imported into a CLAUDE.md is paid for in **every session, on every
project, forever** — it is the highest-cost place to put anything. The goal of
this doc is to keep that cost visible and to give a mechanical answer to
"where does this new instruction go", instead of defaulting to "append to
CLAUDE.md" because that is the file already open.

## Placement decision

Ask, in order:

1. **Would Claude cause real damage by not following this, and can a machine
   enforce it instead of prose?** → `claude/settings.json` (`permissions` /
   `hooks`). Prose is advisory; a denied tool call or a hook is not. Example
   already in this repo: the RTK `PreToolUse` hook and the `permissions.allow`
   list — neither is duplicated as a CLAUDE.md instruction, because the
   mechanism already guarantees it.
2. **Is it needed in literally every session, on every project, regardless of
   topic?** → global `~/.claude/CLAUDE.md` import (`claude/CLAUDE.md` in this
   repo). This is the most expensive tier — see *Current imports* below before
   adding here. Ask explicitly: "if I removed this, would a session on an
   unrelated topic (e.g. a Python data script) break or misbehave?" If the
   answer is no, it does not belong here.
3. **Is it needed in every session of *this project*, but not other
   projects?** → project `CLAUDE.md` (`dotfiles/CLAUDE.md`). Still always-on,
   but scoped — a session in another repo never pays for it.
4. **Does it only matter when a specific, recognizable task comes up** (PR
   review, calendar lookup, root-cause investigation)? → `claude/skills/*/SKILL.md`.
   The `description:` frontmatter is the trigger; Claude Code loads the body
   only when it matches, so the cost is zero in unrelated sessions. This repo
   already does this correctly for `pr-review` / `root-cause` / `calendar`.
5. **Does it only matter when a specific *topic* comes up, but doesn't need a
   trigger-matching skill wrapper** (a policy doc, a persona, reference
   material)? → an on-demand `*.md` that is **referenced by path in a hub**,
   not imported. `~/.claude/local.md` already does this: it is a few lines per
   topic, always imported, but each topic just says "read
   `~/.claude/local/<topic>.md` before doing X" — the detail file itself is
   never `@`-imported, so it costs nothing until the topic is actually in play.
6. **Is it self-evident from the repo or git history** (what a function does,
   why a past commit happened)? → don't write it down at all. Claude can read
   the code or `git log`; a CLAUDE.md sentence restating it just rots the next
   time the code changes without the doc following.

The recurring trap is skipping straight to step 2 because CLAUDE.md is the
file already in front of you. Steps 1, 4 and 5 are cheaper and more precise
whenever the instruction is mechanical, task-shaped, or topic-shaped rather
than universal.

## Current imports: audit

`claude/CLAUDE.md` (symlinked to `~/.claude/CLAUDE.md`) imports four files,
unconditionally, into **every** session on this machine:

| File | Lines | Scope of actual relevance | Verdict |
|------|-------|---------------------------|---------|
| `~/.claude/RTK.md` | 29 | Every session (rtk rewrites every Bash call) | Keep. Genuinely universal — step 2 is correctly satisfied. |
| `claude/worktree.md` | 94 | Only sessions that create or manage a git worktree | **Reconsider.** See below. |
| `claude/model-policy.md` | 111 | Only sessions that spawn a subagent via the Agent tool | Borderline; see below. |
| `~/.claude/local.md` | 31 | Every session (it is itself the thin hub, not the detail) | Keep as-is — this is the pattern step 5 is modeled on. |

**`worktree.md` (94 lines): recommend converting to on-demand read, not a
skill.** The condition for even opening a worktree is narrow and explicit
(PoC / unmerged-upstream-dependent / parallel-branch / isolated-build-deps —
`worktree.md`'s own "When to use" section), and most sessions on this machine
never hit any of those four cases. A `SKILL.md` wrapper is not a good fit
either: nothing in a typical prompt reliably names "worktree" as a trigger
word the way "PR review" or "calendar" do, so a skill's `description:`
matching would be no more reliable than Claude simply knowing to check a
referenced file. The cheapest fix mirrors the `local.md` pattern already used
here: add one line to `claude/CLAUDE.md`'s **project** counterpart or to a
thin hub — "before creating a git worktree, read `claude/worktree.md`" — and
drop the `@` import. This is a **recommendation only**; the import line itself
is left untouched per this task's scope.

**`model-policy.md` (111 lines): keep imported, weaker case for moving.**
Unlike worktree creation, "should I spawn a subagent, and on what model" is a
judgment call Claude has to make silently and continuously — there is no
lexical trigger to hang a skill or a "read this first" pointer on, because the
decision point is Claude's own next tool call, not a phrase the user typed.
An on-demand file only helps when something in the conversation prompts
Claude to go read it; a model-selection policy needs to be already in mind
*before* that trigger exists. This argues for leaving it imported despite the
line count, but it is the file most worth trimming if it grows further (e.g.
the `databricks-investigator` subsection is one specific caller's rule bolted
onto a general policy — a candidate to hoist into that skill's own doc if this
file needs to shrink again).

## Detecting bloat

Measure the actual always-on cost rather than guessing:

```bash
# global imports pulled into every session on this machine
wc -l ~/.claude/RTK.md claude/worktree.md claude/model-policy.md ~/.claude/local.md
```

Measured on this machine (2026-08-05): `29 + 94 + 111 + 31 = 265` lines of
global always-on context, plus this project's own `CLAUDE.md` (303 lines,
project-scoped — only paid for in `dotfiles` sessions) and `claude/CLAUDE.md`
itself (4 lines, just the import list).

- `/memory` inside a session shows the resolved, fully-expanded set of
  instructions actually loaded — use it to confirm an edit here took effect,
  or that an untracked file (`~/.claude/RTK.md`, `~/.claude/local.md`) is
  present at all (see the symptom note already in `dotfiles/CLAUDE.md`).
- `/context` shows the token budget consumed by the current session,
  including these system-prompt-level imports, as a share of the context
  window — the number to watch if a new import is suspected of pushing
  ordinary sessions closer to compaction.
- `claude/skills/*/SKILL.md` and on-demand `local/*.md` files intentionally do
  **not** show up in the above `wc -l` line — that is the point of putting
  them there instead of behind an `@` import.

## What not to write here

- Anything the repo's own code or `git log` already answers unambiguously —
  restating it invites drift the next time the code changes.
- Anything scoped to a single conversation (a one-off decision, a debugging
  detour) — that belongs in the session, not a persistent file.
- Anything naming a company, colleague, internal system, or other content
  covered by *Never commit this* in `dotfiles/CLAUDE.md` — route it to
  `~/.claude/local/*.md` instead, and never quote that file's contents back
  into a tracked doc.
