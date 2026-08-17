# Model Policy (for Claude)

Keep the main thread on **opus (Opus 5)** — where the user's value is:
fact-checking and hard reasoning — and fan out grunt work to subagents on
cheaper models. The goal is to preserve the subscription budget (5h / week)
and avoid hitting token/session limits on long, multi-stage tasks.

## fable (Fable 5) — the top rung, not the default

Fable 5 is available on this plan but is **not** the main-thread default.
It costs 2× Opus 5 ($10/$50 vs $5/$25 per MTok), draws from a capped share
of the subscription quota (Max plans limit Fable to ~50% of usage), and runs
thinking always-on with turns that can take many minutes — used on routine
work it is just slower and more expensive, directly against this policy's
budget goal. Anthropic's own framing: Opus 5 is the daily driver; Fable 5 is
for the most ambitious, multi-day autonomous work.

Use fable **only** when one of these holds, via a manual `/model` switch on
the main thread:

- Hours-to-days scale autonomous runs (overnight agentic work with the full
  spec given up front)
- A root-cause investigation that survived 2+ opus attempts — this extends
  the existing "/clear and restart" rule: if a fresh-context opus restart
  also fails, escalate once to fable
- Genuinely frontier-hard architectural judgment

**Never specify `model: fable` on a subagent.** The delegation ladder tops
out at opus ("genuinely hard root-cause reasoning"); anything above that
belongs on the main thread, deliberately.

**Escalate only after `/clear`, never mid-conversation.** Prompt caching is
scoped per model, so a `/model` switch partway through a session invalidates the
whole conversation's cache (tools + system + messages) and rewrites the entire
prefix — at fable's 2× Opus input rate. The "2+ opus attempts" rule already
implies a fresh-context restart; do the `/clear` first, then `/model fable`.
Subagents on cheaper models cost nothing here — a child runs its own prefix in
its own context, so the opus main thread's cache is untouched. That asymmetry is
why this policy fans out to subagents instead of switching the main thread's
model. (`fallbackModel` on rate-limit takes the same cache hit, but stalling on
a rate limit is worse — leave it.)

Operational caveats: Fable's safety classifiers can refuse benign
security-adjacent work (`stop_reason: refusal`) — if a root-cause /
log-forensics session gets refused, drop back to opus rather than rephrasing
around it. Don't use fable for interactive back-and-forth; give it the whole
task and walk away.

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

### Per-agent overrides live with the agent, not here

An agent whose model choice needs a rule of its own puts that rule in its own
`description` frontmatter (`~/.claude/agents/*.md`) — the description is always
in the parent's context, so it is visible at exactly the moment the parent picks
a model, and a company-local agent's rule stays out of this public repo. This
file stays general: retrieval → haiku, judgment → sonnet.

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
