# Model Policy (for Claude)

Keep the main thread on opus (where the user's value is: fact-checking and
hard reasoning) and fan out grunt work to subagents on cheaper models. The goal
is to preserve the subscription budget (5h / week) and avoid hitting
token/session limits on long, multi-stage tasks.

## Default model when launching a subagent

When launching a child agent with the Agent tool, **always specify both `model`
and `subagent_type` explicitly** (omitting `model` inherits the parent's opus,
which defeats the whole budget-saving point; omitting `subagent_type` silently
takes the heavyweight catch-all when `Explore` would have done). Decide by
whether the deliverable is **retrieval** or **judgment**:

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
Never drop the main thread's opus.

### The two hard rules (measured failure modes, not theory)

A 14-day log audit found **52% of Agent calls on sonnet, and 40% of those were
retrieval by their own description**. Both leaks have a mechanical fix:

1. **`Explore` is always haiku — no exceptions.** Its deliverable is a location
   by definition. If a task feels too heavy for haiku-on-Explore, the task is not
   an Explore; pick `general-purpose` and justify the model separately. Real
   offenders from the audit: `Investigate line-api endpoint`,
   `配信バッチフロー調査`, `4経路のエラーログ出力文字列を特定`.
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

### databricks-investigator

Branch on whether the child has to *design* the query:

- **haiku**: running a query whose shape is already decided — row counts, pulling
  ids, tallying a known table (`吸入クエリの行数を実測`, `3薬局のorg_id等を検出`).
- **sonnet**: choosing tables, working out JOIN/dedup/NULL handling, or deciding
  what would even answer the question.

## Delegation triggers (when to spawn a subagent)

Before choosing a model, first decide "should this even be held on the main
thread, or offloaded to a child?". The goal is not to maximize the offload rate
but to **avoid inflating the opus main thread's context (especially cache
read)**. If any of the following apply, spawn a subagent rather than doing it
directly on the main thread:

- **Exploration / investigation**: likely to read 3+ files to get the
  answer/location → hand it to an Explore-type subagent (haiku) and take back
  only the conclusion. Don't load file bodies onto the main thread.
- **Cross-cutting grep / scanning logs/diffs / surveying naming conventions**
  → offload wholesale to haiku.
- **Bulk aggregation / throwaway analysis scripts**: counting over JSONL logs,
  tallying git history, one-off python/jq to produce a statistic → haiku, take back
  only the numbers. The same audit found **3,246 Bash calls sitting on the opus
  main thread** — much of it script output that never needed to be in opus context.
- **2+ independent pieces of work** → parallel subagents (up to 3–5, choosing
  models per this policy).
- **Post-implementation review / verification** → route to a separate subagent
  (fresh context). Avoid bias by not having the author grade their own work.

Conversely, references that finish within 1–2 files, and hard reasoning itself,
should be done directly on the main opus (the delegation overhead wins otherwise).

## Context hygiene (directly cuts real opus consumption)

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
- `fallbackModel` automatically falls back to sonnet when opus is rate-limited
  (settings.json).
