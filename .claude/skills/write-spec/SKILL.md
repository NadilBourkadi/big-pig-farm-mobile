---
name: write-spec
description: Pick up the next unblocked spec document task from Beads and write the specification
argument-hint: "[spec-number, e.g. 03]"
---

# Write Spec — Task Dispatcher

## Task selection

First, run `bd list -l spec --status open` to see available spec tasks.

If an argument was provided (`$ARGUMENTS`), find the spec task matching that number (e.g. "03" matches "Doc 03"). Otherwise, pick the lowest-numbered unblocked spec.

## Phase 1 — Write (sub-agent)

Delegate to the **spec-writer** agent with the following prompt:

> Write spec document [title from selected task]. Bead ID: [selected bead ID].

The spec-writer agent runs in an isolated worktree and handles: claim → explore → plan → write → commit. It does **not** push or open a PR.

## Phase 2 — Review & Ship (main conversation)

After the agent returns:

1. **Switch to the worktree** — `cd` into the worktree path returned by the agent
2. **Run `/code-review swift`** — the pre-push quality gate
3. **Fix findings** — edit files in the worktree to address review issues
4. **Re-review** — run `/code-review swift` again until clean
5. **Squash to clean history** — `git reset --soft main && git add <files> && git commit`
6. **Push and open PR** — `git push -u origin <branch> && gh pr create`
7. **Return to main working directory**
