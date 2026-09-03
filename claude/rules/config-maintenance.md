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

### `~/.claude/rules/` is a real mechanism — and it is not free

`~/.claude/rules/*.md` is loaded by Claude Code automatically, for **every
project on the machine**, at the same priority as `CLAUDE.md`
([memory docs](https://code.claude.com/docs/en/memory.md), *User-level rules*).
No `@` import and no `settings.json` key is involved. `<project>/.claude/rules/`
works the same way for one project, and project rules are loaded *after* user
rules, so they win on conflict.

**A file in `rules/` with no frontmatter is always-on.** This was misread here
for a month: `coding-style.md` and this file were both described as costing
nothing until the topic came up, while in fact both were in every session's
context — 197 lines believed to be free. A pointer in `CLAUDE.md` telling
Claude to *read* a file that lives in `rules/` is therefore **redundant**, not
a lazy-loading trick.

What makes the tier cheap is `paths:` frontmatter, which turns the file into a
lazily-loaded rule:

```yaml
---
paths:
  - "src/**/*.{ts,tsx}"
---
```

Docs state these "trigger when Claude **reads** files matching the pattern",
and that they reload after compaction as matching files are read. Whether
`Write` on a not-yet-existing file fires them is undocumented, so it was
measured with a sentinel rule (`paths: ["**/*.pathsprobe"]`, a unique string in
the body, `/memory` as the oracle):

- **Gating works** — in a session that touched no matching file, the sentinel
  was absent. So `paths` genuinely keeps a rule out of context.
- **`Write` on a new matching file does NOT load the rule** (measured
  2026-09-04). Creating `new.pathsprobe` from scratch left the sentinel absent.
- Firing on `Read` of an existing matching file was **not** verified.

The consequence: **do not gate a rule whose job is to shape code Claude is
about to write.** The moment it is needed most — a new source file — is exactly
when it does not load, and the failure is silent. `coding-style.md` therefore
stays always-on; 61 lines is the price of the rule actually being present. Gate
only where the trigger file is certain to be read first, and even then weigh it
against the fact that a rule that fails to load leaves no trace anywhere.
Trimming a rule's content is the safer lever than gating it.

`claudeMdExcludes` can drop a specific rule file by glob; there is no key that
disables the mechanism wholesale.

## Current imports: audit

`claude/CLAUDE.md` (symlinked to `~/.claude/CLAUDE.md`) imports four files,
unconditionally, into **every** session on this machine:

| File | Lines | Scope of actual relevance | Verdict |
|------|-------|---------------------------|---------|
| `~/.claude/RTK.md` | 29 | Every session (rtk rewrites every Bash call) | Keep. Genuinely universal — step 2 is correctly satisfied. |
| `claude/worktree.md` | 94 | Only sessions that create or manage a git worktree | **Reconsider.** See below. |
| `claude/model-policy.md` | 224 | Only sessions that spawn a subagent via the Agent tool | Borderline and now the largest import; see below. |
| `~/.claude/local.md` | 31 | Every session (it is itself the thin hub, not the detail) | Keep as-is — this is the pattern step 5 is modeled on. |

Plus two files that are **not** in that import list but are loaded anyway, via
the `~/.claude/rules/` mechanism described above:

| File | Lines | Scope of actual relevance | Verdict |
|------|-------|---------------------------|---------|
| `claude/rules/coding-style.md` | 61 | Only sessions that write or review code | **Keep always-on.** `paths` was measured not to fire on new-file `Write` (above), which is precisely when a coding rule is needed — gating it would silently drop it. 61 lines is the price of it being there. |
| `claude/rules/config-maintenance.md` | 201 | Only sessions that edit a config/instruction file | Keep always-on for now, but it is the **largest always-on entry while being the least universally relevant** — its own worst offender. Gating waits on `Read`-firing being verified; until then, trim content rather than gate. |

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

**`model-policy.md` (224 lines): keep imported, weaker case for moving.**
Unlike worktree creation, "should I spawn a subagent, and on what model" is a
judgment call Claude has to make silently and continuously — there is no
lexical trigger to hang a skill or a "read this first" pointer on, because the
decision point is Claude's own next tool call, not a phrase the user typed.
An on-demand file only helps when something in the conversation prompts
Claude to go read it; a model-selection policy needs to be already in mind
*before* that trigger exists. This argues for leaving it imported despite the
line count, but it is the file most worth trimming if it grows further.

The `databricks-investigator` subsection — one specific caller's rule bolted onto
a general policy — has since been hoisted out, into that agent's own
`description` frontmatter in `~/.claude/agents/` (untracked, company-local). That
is the pattern for any future per-agent model rule: the description is always in
the parent's context, so it is loaded exactly where the model choice is made,
without adding a line to this repo's always-on set. `model-policy.md` keeps only
the general retrieval → haiku / judgment → sonnet rule.

## Detecting bloat

Measure the actual always-on cost rather than guessing:

```bash
# everything pulled into every session on this machine:
# the @ imports, claude/CLAUDE.md itself, and the auto-loaded rules/ files
wc -l ~/.claude/RTK.md claude/worktree.md claude/model-policy.md \
      ~/.claude/local.md claude/CLAUDE.md claude/rules/*.md
```

**The `rules/*.md` glob is the part that was missing** — without it this
measurement under-reports by ~200 lines, which is exactly how the two rules
files went a month believed to be free.

Measured on this machine (2026-09-04): **647 lines** of global always-on
context (`29 + 94 + 224 + 31 + 7 + 61 + 201`), plus this project's own
`CLAUDE.md` (408 lines, project-scoped — only paid for in `dotfiles` sessions).
`tests/claude_rules_test.sh` recomputes that figure from disk and fails when it
drifts, so keep the bolded number on one line and in that exact form.

Up from a **claimed** 265 on 2026-08-05 — but that figure was already wrong,
since it omitted `rules/`. The real growth since then is `model-policy.md`
(111 → 224): the audit above named it the file most worth trimming if it grew,
and it has since roughly doubled. Its measured-evidence sections are what earn
their keep; the prose around them is the trimming target next time. **Before
adding to it, check whether the addition is a rule (belongs there) or a
measurement (could be a dated one-liner instead of a table).**

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
