# Model Policy (for Claude)

Keep the main thread on **fable (Fable 5.1)**, since 2026-09-11, and fan out
grunt work to subagents on cheaper models. The goal is to preserve the
subscription budget (5h / week) and avoid token/session limits on long,
multi-stage tasks. The switch is conditional: revert to opus if the Max-plan
fable cap (~50% of usage) starts binding, or the delegation share below
regresses toward opus's.

## fable — the main-thread default (since 2026-09-11)

Fable 5.1 costs 2× Opus 5 ($10/$50 vs $5/$25 per MTok), draws from a capped
share of the subscription quota (Max plans limit Fable to ~50% of usage), and
runs thinking always-on with turns that can take many minutes. Those facts
didn't change; what changed is the measured delegation effect. A 21-day log
audit (2026-09-11), main thread only:

| | fable (n=5, last week) | opus (n=37) |
|---|---|---|
| median assistant turns / session | 112 | 47 |
| Edit/Write/MultiEdit run on main thread (vs. subagents) | 1.9% | 89.6% |
| median Agent calls / session | 4 | 1 |
| median cache-read tokens / session | 13.1M | 2.6M |

The "implement → sonnet child" trigger below is the trigger opus was already
supposed to follow (see "Measured: implementation delegation collapsed") and
routinely didn't (94% main-thread edits). Fable does (98% delegated);
redo-keyword prompts and refusals were both zero across both models. Caveat:
n=5 over one week, and per-session cache read runs ~5× opus's (turns are
2.4× longer, so ~2× per turn) at fable's 2× rate — the budget guard now
rests entirely on delegation happening, not on the model being cheap per
token.

**Never specify `model: fable` on a subagent.** The main thread already *is*
fable; a fable child buys nothing and doubles the cost. Worth repeating: the
prior opus main thread launched `model: fable` children 5 times, which this
policy forbids. The child ladder is unchanged, topping out at opus
("genuinely hard root-cause reasoning"). Because the default is now fable,
**omitting `model` on an Agent call inherits fable** — a policy violation,
not just waste — so `model` is mandatory on every Agent call, no exceptions.

**Switch models only after `/clear`, never mid-conversation.** A `/model`
switch partway through a session invalidates the whole cache (tools + system
+ messages) at fable's 2× input rate — now symmetric: dropping from fable to
opus mid-session pays the same cache-rewrite cost as escalating did before.
`/clear` first, then `/model opus` (or `/model fable` to return).

Operational caveats: fable's safety classifiers flag benign security-adjacent
work. Claude Code then **re-runs the request on opus automatically** and the
session stays on opus (`switchModelsOnFlag`, default on); watch for the notice
in the transcript and run `/model fable` to come back once that task is done.
Don't rephrase around a flag. It can fire on the very first request, on
CLAUDE.md content alone — `claude --safe-mode` isolates that. A stuck
investigation is still `/clear` and restart with the learnings baked in, not
a model switch.

### Advisor: a second opinion, not an escalation

`advisorModel: fable` in `claude/settings.json` is unchanged. With the main
thread itself on fable, the advisor is the same model in a fresh context — a
second opinion, not an escalation path. It still earns its keep: an opus
session (after a refusal-driven drop) still gets fable judgment at decision
points without switching the whole session.

- **`/advisor` does not invalidate the prompt cache** (unlike `/model`), so
  it is safe to toggle mid-session — the advisor's own read is never cached.
- **Subagents inherit it.** A haiku child consulting the fable advisor is
  intended; running a child *on* fable stays banned.

Tokens bill at fable's rate against the subscription limit; `/advisor opus`
/ `off` is the dial to turn before the main model if budget gets tight. Ask
explicitly for a consult ("advisor に相談してから進めて"); there is no
setting to cap or force calls.

## Default model when launching a subagent

When launching a child agent with the Agent tool, **always specify both
`model` and `subagent_type` explicitly** (omitting `model` inherits the
parent's fable, a budget hit and a policy violation; omitting
`subagent_type` silently takes the heavyweight catch-all when `Explore`
would have done). Decide by whether the deliverable is **retrieval** or
**judgment**:

- **haiku** (`claude-haiku-4-5`) — *default*: work whose deliverable is a
  "conclusion / location / list". Searching, exploring, collecting files,
  grepping logs/diffs, surveying naming conventions, classification, summarizing.
  **Even code investigation is haiku when the job is "where is it / how does it
  work" location** (e.g. "find the trigger for X", "confirm the path for Y",
  "locate the relevant function").
- **sonnet** (`claude-sonnet-5`): work whose deliverable involves
  "judgment / change / evaluation". Routine implementation, refactoring,
  per-PR parallel review, medium reasoning that weighs multiple hypotheses.
- **opus** (`claude-opus-5`): only when delegating genuinely hard
  root-cause reasoning or architectural judgment to a child.

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
read)** — now doubly true at fable's per-token rate. If any of the following
apply, spawn a subagent rather than doing it directly on the main thread:

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

**Follow-up (2026-09-11): this is what justified the fable switch.** Opus
never fixed the collapse above; fable's edit share on the same measurement
is 1.9% (see the table in "fable — the main-thread default"), no rule change
in between. Re-measure mid-October 2026; revert if fable's share climbs
back toward opus's.

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

## Notes

- The more parallel subagents you stand up, the more budget you burn. 3–5
  parallel is the everyday sweet spot.
- `fallbackModel` automatically falls back to sonnet when the main model is rate-limited
  (settings.json).
