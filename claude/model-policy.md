# Model Policy (for Claude)

Keep the main thread on opus (where the user's value is: fact-checking and
hard reasoning) and fan out grunt work to subagents on cheaper models. The goal
is to preserve the subscription budget (5h / week) and avoid hitting
token/session limits on long, multi-stage tasks.

## Default model when launching a subagent

When launching a child agent with the Agent tool, **always specify `model`
explicitly** (omitting it inherits the parent's opus, which defeats the whole
budget-saving point). Decide by whether the deliverable is **retrieval** or
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
- **opus** (`claude-opus-4-8`): only when delegating genuinely hard
  root-cause reasoning or architectural judgment to a child.

**Not "when in doubt, sonnet" but "retrieval → haiku, judgment → sonnet".**
Don't let sonnet become the safe default that sweeps up exploration.
Never drop the main thread's opus.

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
