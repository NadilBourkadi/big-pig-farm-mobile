---
name: implement
description: Pick up the next unblocked implementation task from Beads and plan the implementation
argument-hint: "[phase or task-id, e.g. p0, p1, or big-pig-farm-mobile-5qe]"
---

# Implement — Task Dispatcher

## Task selection

First, run `bd ready -n 30` to see available implementation tasks.

If an argument was provided (`$ARGUMENTS`):
- If it looks like a bead ID (e.g. `big-pig-farm-mobile-5qe`), use that task directly
- If it's a phase label (e.g. `p0`, `p1`, `phase-0`), filter for tasks with that phase label
- If it's a priority (e.g. `P0`, `P1`), filter by priority level

Otherwise, pick the highest-priority (lowest P-number) unblocked implementation task. Skip tasks labeled "spec" or "investigation".

## Phase 1 — Implement (sub-agent)

Delegate to the **implementer** agent with the following prompt:

> Implement [title from selected task]. Bead ID: [selected bead ID].

The implementer agent runs in an isolated worktree and handles: claim → explore → plan → implement → test → commit. It does **not** push or open a PR.

## Phase 2 — Review & Ship (main conversation)

After the agent returns:

1. **Switch to the worktree** — `cd` into the worktree path returned by the agent
2. **Run `/code-review swift`** — the pre-push quality gate
3. **Fix findings** — edit files in the worktree to address review issues
4. **Re-review** — run `/code-review swift` again until clean
5. **Squash to clean history** — `git reset --soft main && git add <files> && git commit`
6. **Push and open PR** — `git push -u origin <branch> && gh pr create`
7. **Return to main working directory**
