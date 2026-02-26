---
name: implement
description: Pick up the next unblocked implementation task from Beads and plan the implementation
argument-hint: "[phase or task-id, e.g. p0, p1, or big-pig-farm-mobile-5qe]"
---

# Implement Task

You are implementing a task for the Big Pig Farm iOS port.

## Available implementation tasks

These tasks are currently unblocked and ready:

```
!`bd ready -n 30 2>&1`
```

## Task selection

If an argument was provided (`$ARGUMENTS`):
- If it looks like a bead ID (e.g. `big-pig-farm-mobile-5qe`), use that task directly
- If it's a phase label (e.g. `p0`, `p1`, `phase-0`), filter for tasks with that phase label
- If it's a priority (e.g. `P0`, `P1`), filter by priority level

Otherwise, pick the highest-priority (lowest P-number) unblocked implementation task. Skip tasks labeled "spec" or "investigation".

**Claim the task immediately:**
```bash
bd update <id> --status in_progress
```

**Read full task details:**
```bash
bd show <id>
```

## Context sources

You MUST read these before implementing:

1. **The relevant spec document** — find it in `docs/specs/`. The spec is the implementation contract. If the spec is wrong, update the spec first.

2. **CLAUDE.md** — contains code style, architecture rules, and conventions that must be followed.

3. **Source Python codebase** — the original implementation at `/Users/nadilbourkadi/Dev/big-pig-farm`. Use subagents to find and analyze the specific Python modules being ported.

4. **Existing Swift stubs** — check `BigPigFarm/` for any stub files that already exist for this task. The project scaffolding created empty files that need to be filled in.

5. **Doc 02 Data Models spec** — `docs/specs/02-data-models.md` defines all types. Reference it for struct/enum definitions.

## Workflow

1. **Explore** — read the spec, find the Python source, check existing Swift stubs. Use subagents for parallel exploration.
2. **Enter plan mode** — design the implementation approach. Map Python code to Swift, identify all files to create/modify, note any dependencies. Present for approval before coding.
3. **Implement** — write the Swift code following CLAUDE.md conventions:
   - `struct` over `class` (except `GameState`)
   - `Sendable` conformance on all value types
   - Files under ~300 lines
   - Descriptive names, no abbreviations
4. **Test** — write tests in `BigPigFarmTests/` using Swift Testing (`@Test`, `#expect`)
5. **Finalize:**
   - Update `docs/CHECKLIST.md` — check off the completed task
   - Close the bead: `bd close <id>`
   - Commit on a feature branch (never on main)
   - Push and open a PR
