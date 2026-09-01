# Coding Style (for Claude)

Language-agnostic preferences that apply whenever Claude writes, refactors, or
reviews code. Project conventions (a repo's own CLAUDE.md, its linter config,
the surrounding file's idiom) win over this file — this is the default to reach
for when nothing more specific says otherwise.

## Separate pure logic from side effects

Prefer a **referentially transparent** core with side effects pushed to the
boundary. Concretely, when a function both computes something and performs I/O,
split it in two:

- a pure function that takes inputs and returns the data to be acted on
- a thin impure function that performs the effect on that data

The payoff is not aesthetic. The pure half is testable without mocks, a
database, a clock, or a transaction; the impure half becomes small enough to
review by eye.

## Inject non-deterministic values as arguments

The current time, UUIDs, random values, and environment lookups are inputs, not
ambient facts. Pass them in rather than calling for them inside the function.

This is what makes the split above actually pure, and it removes a class of bug
by construction: two values that must agree (e.g. a timestamp persisted to a row
and the same timestamp handed to a downstream consumer) cannot drift if both
read the same argument. Tests that exist only to catch such drift can then be
deleted rather than written.

## Make illegal combinations unrepresentable

When a computation produces several values whose consistency matters, return
them as one immutable value (a frozen dataclass, a record, a readonly struct)
rather than a loose tuple that callers reassemble. Encode "this field is only
meaningful when that field is set" in the type where the language allows it,
instead of restating the condition at every call site.

## Prefer expressions over mutation

Build values rather than mutating accumulators, and avoid reassigning a
parameter. Comprehensions, `map`/`filter`, and returning a new collection are
preferred over appending to a list declared several lines earlier — but not at
the cost of legibility: a deeply nested comprehension is worse than a plain
loop, and a loop that stays local and obvious is fine.

## Where effects belong

Group effects at a single, named boundary rather than scattering them through a
computation. If a runtime concept defines that boundary (a transaction, a
request lifecycle, a batch tick), let one function own it and name it for what
it does, so the reason the boundary exists lives in one place.

## Comments carry why, not what

Don't restate in a comment what the code says — it duplicates the code and
becomes a lie the moment the code changes without it. Write **why**, and
prefer **why not**: the option rejected, the constraint forcing this shape, the
approach that was tried and failed. That is the only information the code
cannot hold. When a comment exists only to explain a name, fix the name.
