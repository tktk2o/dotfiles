# Worktree Policy (for Claude)

## When to use

Use a worktree only in the following cases. Plain checkout is enough for
everyday branch work.

- PoC / verification work (uncertain whether it will be merged)
- Work depending on an unmerged upstream PR
- Work that needs multiple branches touched in parallel
- Work that needs build artifacts / dependency files isolated

## Placement convention

Put worktrees inside the main repo at `.worktrees/{branch-alias}/`.

- Keeps `ghq list` clean (only the main repo is under ghq management)
- Related work is physically co-located with the main repo
- Deleting the main repo also removes the worktrees (cleanup is simple)

Put `*` in `.worktrees/.gitignore` to ignore everything under it. This keeps
the main repo's `git status` free of leakage.

## Standard procedure

### Create

```bash
# run inside the main repo
git fetch origin

# create .worktrees/ + place .gitignore if missing (first time only)
[ -d .worktrees ] || { mkdir .worktrees && echo '*' > .worktrees/.gitignore; }

# create the worktree
git worktree add -b {branch-name} \
  .worktrees/{branch-alias} \
  origin/{base-branch}

cd .worktrees/{branch-alias}
```

### List / confirm current location

```bash
git worktree list
pwd  # always confirm whether you're in the main repo or a worktree
```

If the statusline ends with `⎇`, you're inside a worktree.

### Remove

```bash
# run from the main repo
git worktree remove .worktrees/{branch-alias}
git branch -D {branch-name}

# only if already pushed
git push origin --delete {branch-name}
```

## Branch naming

- PoC: `poc/{feature-name}`
- Experiment / investigation: `experiment/{topic}` or `spike/{topic}`
- Upstream-dependent: `wip/{feature-name}`

The worktree directory name `{branch-alias}` replaces slashes in the branch
name with hyphens (e.g. `poc/foo` → `poc-foo`).

## Tracking upstream (rebase / cherry-pick approach)

Don't merge; re-apply the PoC commit range onto the new upstream.

1. Record the PoC commit range (base hash + commit count)
2. On upstream update:
   - `git fetch origin`
   - recreate the integration branch from the new upstream
   - re-apply the recorded range with `cherry-pick`
3. Resolve conflicts manually

## Operational notes for Claude

- Before creating a worktree, check that `.worktrees/.gitignore` exists; create
  it if missing
- Recreate `.venv` / `node_modules` per worktree
- The same branch cannot be checked out in multiple worktrees at once (git
  constraint)
- Before working, confirm via `pwd` and the statusline whether you're in the
  main repo or a worktree
- `wta` / `wtj` zsh functions are defined for interactive user use, but in the
  Bash tool don't use them — call plain `git worktree` directly (the functions
  may not be loaded in a non-interactive shell)
