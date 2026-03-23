---
name: status
description: Show the status of a feature workstream — beads grouped by status, blocking decisions, progress
argument-hint: "<feature-label or epic-id, e.g. feature:icloud-sync or big-pig-farm-mobile-abc>"
---

# Status — Feature Workstream Overview

Shows the current state of a multi-bead feature: what's done, what's in progress, what's blocked,
and what decisions need human input.

## Input

`$ARGUMENTS` is either:
- A **feature label** (e.g., `feature:icloud-sync`) — filter by label
- An **epic bead ID** (e.g., `big-pig-farm-mobile-abc`) — show children of that epic
- **Empty** — show all epics and their high-level status

## Gather Data

Run these commands to collect the information (adapt based on input type):

### If a feature label was provided:

```bash
# All beads with this label (tree view)
bd list -l <label> --pretty -n 0

# Decision beads that are still open (blocking work)
bd query "label=<label> AND type=decision AND status!=closed" -n 0

# Counts for progress summary
bd query "label=<label> AND status=closed" -a -n 0
bd query "label=<label> AND status!=closed" -n 0
```

### If an epic ID was provided:

```bash
# Children of this epic (tree view)
bd children <epic-id> --pretty

# Decision children still open
bd query "parent=<epic-id> AND type=decision AND status!=closed" -n 0

# Counts
bd query "parent=<epic-id> AND status=closed" -a -n 0
bd query "parent=<epic-id> AND status!=closed" -n 0
```

### If no argument:

```bash
# All epics
bd list -t epic -n 0
```

For each epic, show a one-line summary with child count and progress.

## Present Results

Format the output as a clear summary. Group beads by status:

```
## Feature: <label or epic title>

### Progress: X/Y complete (Z%)

### ⚠ Decisions Pending
  ○ big-pig-farm-mobile-xyz — Choose sync conflict strategy (P1)
    → This blocks: big-pig-farm-mobile-abc, big-pig-farm-mobile-def
    → Resolve: review the bead description, make a decision, close with `bd close <id>`

### ◐ In Progress
  ◐ big-pig-farm-mobile-abc — CloudKit container setup (P2)

### ○ Ready to Work
  ○ big-pig-farm-mobile-def — Implement sync engine (P2)
  ○ big-pig-farm-mobile-ghi — Add sync UI indicator (P3)

### ✓ Completed
  ✓ big-pig-farm-mobile-jkl — Define data model for sync metadata
```

### Key rules:
- **Decision beads get top billing.** They block other work and need human attention.
- **In-progress beads show which agent has them** (if assignee is set).
- **Ready beads are sorted by priority** (P0 first).
- For each pending decision, show which beads it blocks (check dependencies).

## After Presentation

This skill is **read-only** — it never modifies bead state. After presenting:
- If there are pending decisions, suggest the user review them
- If everything is unblocked, suggest `/next <label>` or `/implement <bead-id>`
- If all beads are complete, congratulate and suggest closing the epic
