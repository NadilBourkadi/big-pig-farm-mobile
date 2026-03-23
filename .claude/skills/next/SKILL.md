---
name: next
description: Show the highest-priority unblocked tasks, optionally filtered by feature label
argument-hint: "[feature-label, e.g. feature:icloud-sync]"
---

# Next — What Should I Work On?

A read-only skill that shows the highest-priority unblocked tasks. Optionally filtered by
feature label. Does NOT claim or modify any beads.

## Gather Data

### If a feature label was provided (`$ARGUMENTS`):

```bash
# Ready beads for this feature, sorted by priority
bd list -l <label> --ready --sort priority -n 5

# Open decision beads blocking progress
bd query "label=<label> AND type=decision AND status!=closed" -n 0
```

### If no argument:

```bash
# Top ready beads across all features, sorted by priority
bd ready -n 10

# Any open decision beads anywhere
bd list -t decision -s open -n 5
```

## Present Results

Show the top candidates clearly:

```
## Next Up [for <label>]

1. ○ big-pig-farm-mobile-def — Dynamic Type in HUD (P2)
2. ○ big-pig-farm-mobile-ghi — Reduce motion support (P3)
3. ○ big-pig-farm-mobile-jkl — Add haptic feedback (P3)

⚠ 1 decision blocking further work:
  ○ big-pig-farm-mobile-xyz — Choose VoiceOver strategy for SpriteKit (P1)
  → Blocks: big-pig-farm-mobile-abc, big-pig-farm-mobile-mno
  → Review the bead description and close when decided: `bd close <id>`
```

### Key rules:
- **Only show `○ open` beads.** Never suggest `◐ in_progress` beads — another agent owns them.
- **Sort by priority** (P0 first, then P1, etc.).
- **Decision beads get a separate callout** at the bottom — they're blockers, not work items.
- **Limit to 5–10 beads.** If there are more, mention the count and suggest `/status` for the full picture.

## After Presentation

This skill is **read-only**. After presenting:
- Suggest `/implement <bead-id>` to pick up a specific task
- If decision beads are blocking high-priority work, suggest resolving them first
- Never claim a bead or change its status
