---
name: write-spec
description: Pick up the next unblocked spec document task from Beads and write the specification
argument-hint: "[spec-number, e.g. 03]"
---

# Write Spec Document

You are writing a specification document for the Big Pig Farm iOS port.

## Available spec tasks

These spec tasks are currently unblocked and ready:

```
!`bd list -l spec --status open 2>&1`
```

## Task selection

If an argument was provided (`$ARGUMENTS`), find the spec task matching that number (e.g. "03" matches "Doc 03"). Otherwise, pick the lowest-numbered unblocked spec.

**Claim the task immediately:**
```bash
bd update <id> --status in_progress
```

## Context sources

You MUST read all of these before writing:

1. **Existing specs as templates** — read both for format, structure, and level of detail:
   - `docs/specs/01-project-setup.md`
   - `docs/specs/02-data-models.md`

2. **ROADMAP for architectural decisions** — `docs/ROADMAP.md` contains technology choices, architectural mappings, and rationale that the spec must align with.

3. **Source Python codebase** — the original implementation lives at `/Users/nadilbourkadi/Dev/big-pig-farm`. Analyze the relevant Python modules to understand what needs to be specified. Use subagents to explore the source code in parallel.

4. **CHECKLIST for scope** — `docs/CHECKLIST.md` lists the implementation tasks this spec must cover.

## Workflow

1. **Explore** — read the context sources above. Use subagents aggressively to analyze the Python source in parallel with reading the existing specs.
2. **Enter plan mode** — design the spec structure and outline. Present the outline for approval before writing.
3. **Write the spec** — create the file at `docs/specs/NN-<name>.md` following the established format.
4. **Finalize:**
   - Update `docs/CHECKLIST.md` — check off the spec document
   - Close the bead: `bd close <id>`
   - Commit on a feature branch (never on main)
   - Push and open a PR

## Quality bar

- The spec must be detailed enough that an agent can implement from it without asking clarifying questions
- Include Swift type signatures, not just prose descriptions
- Reference specific Python source files/classes being ported
- Call out architectural decisions from the ROADMAP
- Flag any open questions as "Decision needed" sections
