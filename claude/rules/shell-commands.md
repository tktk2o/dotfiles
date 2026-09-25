# Shell Commands (for Claude)

Prefer the dedicated tools over their shell equivalents: `Grep` over
`grep`/`rg`, `Glob` over `find`, `Read` over `cat`/`head`/`sed -n`.

**Why:** every permission rule — an allow-list prefix match and the auto-mode
classifier alike — is evaluated against the literal command string. Three
shapes defeat that evaluation and force a prompt that only the user can clear:

- **`cd X` followed by a relative path.** The directory the command will read
  is not statically determinable, so a `Read()` deny rule cannot be cleared
  and the call falls through to the user.
- **Pipes, `&&`, redirects.** `Bash(cmd:*)` is a prefix match, so `cmd … | jq`
  no longer matches the entry that allows `cmd …`.
- **Flags that widen scope implicitly** — `grep -A/-r` from an unknown cwd.

This bites hardest in subagents, which cannot answer a prompt: the work simply
stalls. Both failures seen so far were this — a `slack-cli … | jq` fetch and a
`cd … && grep -A 30 … | head -40`.

When Bash is genuinely required: absolute paths, one command, no pipe. Filter
with the tool's own flags (`--limit`, `-m`, `--format`) instead of `| head`.
