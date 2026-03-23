---
name: next
description: Show the highest-priority unblocked tasks and surface pending decisions for resolution
argument-hint: "[feature-label, e.g. feature:icloud-sync]"
---

# Next — What Should I Work On?

Shows the highest-priority unblocked tasks and surfaces pending architectural decisions that
need human input. Decisions are presented with full context so the user can resolve them
directly from this skill.

## Step 1 — Gather Data

### If a feature label was provided (`$ARGUMENTS`):

```bash
# Ready implementable beads for this feature
bd ready -t task -l <label> -n 10

# Open decision beads for this feature (need human input)
# NOTE: use bd list, NOT bd query — bd query chokes on colons in label values
bd list -l <label> -t decision -n 0
```

### If no argument:

```bash
# Top ready implementable beads across all features
bd ready -t task -n 10

# Any open decision beads anywhere (bd list excludes closed by default)
bd list -t decision -n 5
```

## Step 2 — Present Pending Decisions FIRST

Decision beads block other work and need human attention. Present them **before** the task list,
with enough context for the user to decide on the spot.

For each open decision bead:
1. Run `bd show <id> --long` to get the full description
2. Check what it blocks: look for dependent beads in the output
3. Present as:

```
## ⚠ Decisions Needing Input

### 1. big-pig-farm-mobile-xyz — Choose sync conflict resolution strategy (P1)

**Context:** [extracted from bead description]

**Options:**
A. [Option from description]
B. [Option from description]

**Blocks:** big-pig-farm-mobile-abc (CloudKit sync), big-pig-farm-mobile-def (Offline mode)

→ Reply with your choice and I'll record the ADR and close this decision.
```

If the user responds with a choice:
1. Create an ADR in `docs/decisions/` using the template
2. Close the decision bead: `bd close <id>`
3. Note which implementation beads are now unblocked

## Step 3 — Present Ready Tasks and Act

After decisions, show the task list briefly, then **act based on the situation:**

**If there are pending decisions:** Present the task list and STOP. The user needs to resolve decisions first — don't start implementing while choices are outstanding.

```
## Next Up [for <label>]

1. ○ big-pig-farm-mobile-def — Dynamic Type in HUD (P2)
2. ○ big-pig-farm-mobile-ghi — Reduce motion support (P3)

⚠ Resolve the decisions above before starting implementation.
```

**If there are NO pending decisions and tasks ARE available:** Show the task list briefly, then **automatically invoke `/implement` with the highest-priority task.** Don't ask — the user ran `/next` to get work moving.

```
## Next Up [for <label>]

1. ○ big-pig-farm-mobile-def — Dynamic Type in HUD (P2)
2. ○ big-pig-farm-mobile-ghi — Reduce motion support (P3)

Starting implementation of big-pig-farm-mobile-def...
```

Then call `Skill("implement")` with the top task's bead ID as the argument.

**If no tasks are ready:** Say so clearly — there's nothing to implement.

### Key rules:
- **Decisions come first** — they unblock work and need the user's brain, not an agent's.
- **Only show `○ open` task beads.** Never suggest `◐ in_progress` beads.
- **Sort tasks by priority** (P0 first).
- **Auto-proceed to `/implement`** when no decisions are blocking. The user consented by running `/next`.
- **Limit the task list to 10.** If there are more, mention the count.
