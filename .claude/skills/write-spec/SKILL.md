---
name: write-spec
description: Pick up the next unblocked spec document task from Beads and write the specification
argument-hint: "[spec-number, e.g. 03]"
---

# Write Spec — Task Dispatcher

## Task selection

First, run `bd list -l spec --status open` to see available spec tasks.

If an argument was provided (`$ARGUMENTS`), find the spec task matching that number (e.g. "03" matches "Doc 03"). Otherwise, pick the lowest-numbered unblocked spec.

## Action

Delegate to the **spec-writer** agent with the following prompt:

> Write spec document [title from selected task]. Bead ID: [selected bead ID].

The spec-writer agent runs in an isolated worktree and handles the full workflow: claim → explore → plan → write → finalize → PR.
