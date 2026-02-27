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

## Action

Delegate to the **implementer** agent with the following prompt:

> Implement [title from selected task]. Bead ID: [selected bead ID].

The implementer agent runs in an isolated worktree and handles the full workflow: claim → explore → plan → implement → test → finalize → PR.
