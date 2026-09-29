# Model Policy (for Claude)

Keep the main thread on **Opus 5.5** (`claude-opus-5-5`), since 2026-09-24,
and fan out grunt work to subagents on cheaper models — preserving the
subscription budget (5h / week) and avoiding token/session limits on long,
multi-stage tasks. Fable held this role from 2026-09-11 for its measured
delegation discipline; opus 5.5 trades that for cheaper tokens, no known
Max-plan usage cap, and better agentic benchmarks (below). The switch is
conditional: **revert to fable** if a re-measure (due ~2026-10-08) shows the
delegation share relapsing toward opus 5's.

## opus 5.5 — the main-thread default (since 2026-09-24)

Opus 5.5 costs $4/$20 per MTok (cache read $0.20) against Fable 5.1's
$10/$50 (cache read $0.25) — cheaper outright, not relatively. Max plans cap
Fable at ~50% of usage; no equivalent cap on Opus 5.5 is confirmed (no
official Anthropic statement seen). Anthropic's own agentic benchmarks favor
it too: Terminal-Bench 4.0 66.4% vs 55.8%, OSWorld 2.0 (strict) 48.7% vs
41.7%, AutomationBench 40.0% vs 31.4% (GDPval-AA roughly tied, 1846 vs 1853).
Thinking stays always-on, same as Fable; effort defaults to `medium` (Opus 5
was `high`), so the main thread pins `high` via
`modelSettings["claude-opus-5-5"].effortLevel` in `claude/settings.json`.

None of that is why Fable held this slot, though: a 21-day audit (2026-09-11)
found Fable's main-thread edit/write share at 1.9% against opus 5's 89.6%
(full table dropped 2026-09-24 as it ages; see git history). **Whether opus
5.5 relapses toward opus 5's share or holds Fable's is unmeasured** — that
is the entire risk of this switch, and the reason for the revert condition
above.

**Never specify `model: fable` on a subagent.** Fable now costs *more* than
the main thread's own opus 5.5 ($10/$50 vs $4/$20) and buys nothing. The
child ladder is otherwise unchanged, topping out at the `opus` alias — same
tier as the main thread, for genuinely hard root-cause reasoning needing a
fresh context. **Omitting `model` on an Agent call inherits the main
thread's Opus 5.5** — a policy violation, not just waste — so `model` is
mandatory on every Agent call, no exceptions.

**Switch models only after `/clear`, never mid-conversation.** A `/model`
switch partway through a session invalidates the whole cache (tools + system
+ messages) at the new model's input rate — switching up to fable mid-session
pays a real cache-rewrite penalty on top of fable's own higher rate.
`/clear` first, then `/model fable` (or `/model opus` to return).

Operational caveats: Opus 5.5 still carries safety classifiers (cyber, plus
bio / reasoning_extraction) that can flag benign security- or
biology-adjacent work. `switchModelsOnFlag` was measured re-running flagged
fable requests on opus; how it resolves a flag on opus 5.5 itself is
unmeasured, so watch the transcript rather than assume — and don't rephrase
around it. A flag can
fire on the first request, on CLAUDE.md content alone (`claude --safe-mode`
isolates that); a stuck investigation is still `/clear` and restart, not a
model switch.

### Advisor: an escalation again, not a second opinion

`advisorModel: fable` in `claude/settings.json` is unchanged. With the main
thread back on opus 5.5, a consult is an escalation again — Fable costs more
per token, so `/advisor` borrows a pricier model's judgment at one decision
point without switching the whole session.

- **`/advisor` does not invalidate the prompt cache** (unlike `/model`), so
  it is safe to toggle mid-session — the advisor's own read is never cached.
- **Subagents inherit it.** A haiku child consulting the fable advisor is
  intended; running a child *on* fable stays banned.

Tokens bill at fable's (higher) rate against the subscription limit;
`/advisor off` (or `/advisor opus` to fall back to the main thread's own
model) is the dial to turn if budget gets tight. Ask explicitly for a
consult ("advisor に相談してから進めて"); there is no setting to cap or
force calls.

## Default model when launching a subagent

When launching a child agent with the Agent tool, **always specify both
`model` and `subagent_type` explicitly** (omitting `model` inherits the
parent's opus 5.5, a budget hit and a policy violation; omitting
`subagent_type` silently takes the heavyweight catch-all when `Explore`
would have done). Decide by whether the deliverable is **retrieval** or
**judgment**:

- **haiku** (`claude-haiku-4-5`) — *default*: work whose deliverable is a
  "conclusion / location / list". Searching, exploring, collecting files,
  grepping logs/diffs, surveying naming conventions, classification, summarizing.
  **Even code investigation is haiku when the job is "where is it / how does it
  work" location** (e.g. "find the trigger for X", "confirm the path for Y",
  "locate the relevant function").
- **sonnet** (`claude-sonnet-5-5` — alias verified 2026-09-29, same $2/$10 as
  Sonnet 5): "judgment / change / evaluation" deliverables. Routine implementation,
  refactoring, per-PR parallel review, medium reasoning weighing multiple hypotheses.
- **opus** (the `opus` alias — same tier as the main thread): only when
  delegating genuinely hard root-cause reasoning or architectural judgment
  to a child that needs a fresh context.

**Not "when in doubt, sonnet" but "retrieval → haiku, judgment → sonnet".**
Don't let sonnet become the safe default that sweeps up exploration.
Never do delegable work on the main thread.

### The two hard rules (measured failure modes, not theory)

A 14-day log audit found **52% of Agent calls on sonnet, and 40% of those were
retrieval by their own description**. Both leaks have a mechanical fix:

1. **`Explore` is always haiku — no exceptions.** Its deliverable is a location
   by definition. If a task feels too heavy for haiku-on-Explore, the task is
   not an Explore; pick `general-purpose` and justify the model separately.
   Real offenders: `Investigate line-api endpoint`, `配信バッチフロー調査`,
   `4経路のエラーログ出力文字列を特定`.
2. **The description decides the model.** If the task can be written with any of
   these words, it is haiku:

   > 調査 / 収集 / 確認 / 特定 / 列挙 / 突合 / 集計 / 実測 / 検出 / 棚卸 / 探索 /
   > 経緯整理 / Investigate / Collect / Verify / Survey / Find / Check / Extract /
   > Summarize / Inventory / Scan / archaeology

   Counting whether a PR has unit tests (`〜PR の UT 調査`), reconstructing an
   incident timeline from Slack, and `Git archaeology on …` are all haiku work no
   matter how important the surrounding task is.

### Splitting review work

- **Someone else's PR** (the `pr-review` skill): sonnet. Unchanged — that is
  judgment on code you did not write.
- **Your own freshly split subtask** (one file / tens of lines, `Review Task N`
  and its `Re-review …` after a fix): haiku running a checklist. Escalate to
  sonnet **only when haiku flags something** and the call is whether the flag is
  real. The audit had 14 such calls on sonnet.

### Per-agent overrides live with the agent, not here

An agent whose model choice needs a rule of its own puts that rule in its own
`description` frontmatter (`~/.claude/agents/*.md`) — the description is always
in the parent's context, so it is visible at exactly the moment the parent picks
a model, and a company-local agent's rule stays out of this public repo. This
file stays general: retrieval → haiku, judgment → sonnet.

## Delegation triggers (when to spawn a subagent)

Before choosing a model, first decide "should this even be held on the main
thread, or offloaded to a child?". The goal is not to maximize the offload rate
but to **avoid inflating the main thread's context (especially cache
read)**. If any of the following apply, spawn a subagent rather than doing
it directly on the main thread:

- **Exploration / investigation**: likely to read 3+ files to get the
  answer/location → hand it to an Explore-type subagent (haiku) and take back
  only the conclusion. Don't load file bodies onto the main thread.
- **Cross-cutting grep / scanning logs/diffs / surveying naming conventions**
  → offload wholesale to haiku.
- **Bulk aggregation / throwaway analysis scripts**: counting over JSONL logs,
  tallying git history, one-off python/jq to produce a statistic → haiku, take back
  only the numbers. The same audit found **3,246 Bash calls sitting on the
  main thread** — much of it script output that never needed to be there.
  This is now enforced mechanically by `claude/hooks/scan-budget.sh` (default
  threshold 12, nudge only, never deny). Separately: fact-checking against web
  documentation is sonnet, not haiku — a haiku child returned two unverifiable
  claims on 2026-09-11 and the main thread had to re-read the primary sources
  itself.
- **Routine implementation** → sonnet, once the approach is decided. The trigger
  is mechanical: **more than one file, or more than ~3 edits, or a task you would
  describe as "implement / add / rewrite / migrate / refactor"** → hand the decided
  approach to a sonnet child and take back a diff summary. Deciding *what* to build
  stays on the main thread; typing it out does not.
- **2+ independent pieces of work** → parallel subagents (up to 3–5, choosing
  models per this policy).
- **Post-implementation review / verification** → route to a separate subagent
  (fresh context). Avoid bias by not having the author grade their own work.

Conversely, **a single file and no more than ~3 edits**, and hard reasoning
itself, should be done directly on the main thread (the delegation overhead
wins otherwise). This is a size limit, not a difficulty limit — "this part
needs judgment" is not a reason to keep a ten-file change on the main thread;
put the judgment in the child's instructions instead.

### Decide before the first tool call — the window is one shot

**Decide whether to delegate *before* the first investigative tool call** (`Read`
/ `Grep` / `Glob` / a grep-ish `Bash` / a log search) **and before the first
`Edit` / `Write` / `MultiEdit`**. After one read the file body is already in the
main thread's context and its cache-read cost is paid every turn, so handing it
to a child then pays twice. "Let me look once and then decide" is banned — that
look *is* the missed decision. The same applies to the first edit: once you have
started editing, the whole file is in context and the session reliably continues
to completion on the main thread — the measured shape below is not many small
direct edits but long main-thread sessions that never delegated. The 3,246
main-thread Bash calls above are this failure mode, not a missing trigger. If a
trigger applies and you read or edit anyway, **say in one line why** first.

### Measured: implementation delegation collapsed (2026-09-04)

The one place both hard rules above held and the *trigger* did not. Editing tool
calls (`Edit`/`Write`/`MultiEdit`), main thread vs subagent:

| | all-time | last 14 days |
|---|---|---|
| main-thread opus | 1,180 | 1,118 |
| subagent (sonnet 704/50 + haiku 35/11) | 739 | 61 |
| **main-thread share** | **60%** | **94%** |

This is a regression, not a standing habit: sonnet children did 704 edits
all-time but only 50 in the last two weeks. **59% of the main-thread editing
sessions ran 11+ edits** — far outside the "1–2 files" escape hatch invoked to
justify them, which is why that hatch is now a hard ~3-edit limit. Sonnet
children handled 4+ edits in 58 of 70 cases, so the threshold is not
aspirational.

By contrast `model` was specified on **all 263** Agent calls and every `Explore`
ran on haiku — the model-*selection* rules work. Prose that merely records a
number does not: main-thread `Bash` measured 3,153, essentially unchanged from
the 3,246 written above.

**Follow-up: this is what justified the fable switch (2026-09-11), then the
opus 5.5 switch (2026-09-24).** Opus 5 never fixed the collapse above;
fable's edit share on the same measurement was 1.9% (see "opus 5.5 — the
main-thread default"). Opus 5.5 replaced fable for pricing and benchmarks,
not delegation — that risk is still open. Re-measure ~2026-10-08; revert to
fable if the main-thread edit share climbs back toward opus 5's.

### What the child must hand back

Ask for **conclusion + evidence as `file:line`**, and forbid raw logs / whole
file bodies — a child that returns a wall of text puts the same tokens on the
main thread with extra latency. Then open only the few lines that decide the
conclusion; re-reading the child's whole range defeats the delegation. So
"I need to verify the primary source myself" is not a reason to skip it: the
child finds, the main thread confirms and decides.

## Context hygiene (directly cuts real main-thread consumption)

- `/clear` when moving to an unrelated task. Dragging a long single session is
  the biggest driver of bloated cache read.
- If two fixes on the same problem don't resolve it, don't grind — `/clear` and
  restart with a fresh prompt that bakes in the learnings; it's faster.
- The above are user actions, but Claude should also proactively propose
  delegating to a subagent when it's about to start broad exploration on the
  main thread.
- `claude/hooks/context-guard.sh` surfaces the token count at each prompt once
  it passes 200k, so `/clear` becomes a measured call, not a feeling.

## Notes

- The more parallel subagents you stand up, the more budget you burn. 3–5
  parallel is the everyday sweet spot.
- `fallbackModel` automatically falls back to sonnet when the main model is rate-limited
  (settings.json).
