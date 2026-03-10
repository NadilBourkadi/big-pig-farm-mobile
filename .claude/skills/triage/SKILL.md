---
name: triage
description: Investigate a bug or feature, create a bead, and optionally implement it immediately
argument-hint: "[optional: extra context or file paths to read on startup]"
---

# Triage — Investigate, Create Bead, Act

This skill investigates a bug or feature request by reading the live Swift codebase, creates a
self-contained bead, and either immediately implements it (if simple) or stops with the bead
created (if complex).

## Phase 1 — Startup Ingestion

Run all of the following before any user interaction:

1. Read `CLAUDE.md` — conventions, architecture, code style
2. Run `bd stats` — overview of open/closed task counts
3. Run `bd ready -n 10` — what's already queued (avoids duplicate beads)

Print a brief "Ready" summary:
- Active bead count and how many are ready to work
- Confirmation that CLAUDE.md conventions are loaded

If `$ARGUMENTS` was provided, treat each whitespace-separated token as either a file path to read
or extra context to note, and include it in the Ready summary.

## Phase 2 — Problem Input

Output this question as plain text (no tool call — the user replies via normal chat):

> "What issue would you like me to investigate? (bug, feature request, or performance problem)"

Wait for the user's reply. Accept any freeform description. This is the only user input required for the rest of the workflow.

## Phase 3 — Launch Shallow-Dive Agent

Launch `Agent(subagent_type="triage")` with a prompt that includes ALL of the following:

1. The user's problem description — verbatim, quoted
2. The current bead list from Phase 1 — so the agent doesn't create duplicates
3. This explicit constraint: **shallow dive only — maximum 8 tool calls total**
4. The required output format (copy from the agent spec below — include the entire format block
   in the prompt so the agent has it inline):

```
VERDICT: SIMPLE | COMPLEX

TITLE: <short imperative bead title>

PRIORITY: P0 | P1 | P2 | P3

ROOT_CAUSE:
<1–3 sentences: what is wrong or missing, citing specific file:line where possible>

FILES:
- BigPigFarm/Path/To/File.swift — <role in the fix>
- (up to 3 files)

SOLUTION:
<For SIMPLE: the specific change needed, concrete enough to implement without questions>
<For COMPLEX: the approach or options — what further investigation is needed>

BEAD_DESCRIPTION:
<Full multi-line description — see template below>

COMPLEXITY_RATIONALE:
<Why SIMPLE or COMPLEX. Include rough time estimate: "~10 min, single method change in FarmScene.swift">
```

The BEAD_DESCRIPTION must follow this template exactly:

```
## Problem
[What's broken or what the user wants — one paragraph]

## Root Cause / Approach
[What the investigation found. For bugs: what code is wrong and why.
For features: how the codebase currently handles the adjacent concern.]

## Files
- `BigPigFarm/Path/File.swift` — [why this file is involved]

## Solution
[Concrete description of the change. For simple: specific method/line to change.
For complex: design decision needed + options.]

## Acceptance Criteria
- [ ] [Verifiable outcome 1]
- [ ] [Verifiable outcome 2]

## Complexity
SIMPLE | COMPLEX — [time estimate, e.g. "~10 min, single file"]
```

Wait for the agent to return before proceeding.

## Phase 4 — Parse Verdict and Act

Read the structured output from the agent. The first line is always `VERDICT: SIMPLE` or
`VERDICT: COMPLEX`.

Extract these fields from the agent output:
- `TITLE` — bead title
- `PRIORITY` — P0/P1/P2/P3
- `BEAD_DESCRIPTION` — the full multi-section description

**If VERDICT: SIMPLE:**

```
bd create "<TITLE>" -t task -p <PRIORITY>
bd update <id> --description "<BEAD_DESCRIPTION>"
```

Then invoke `Skill("implement")` with the new bead ID as the argument.

**CRITICAL — NO ASKING PERMISSION:** Do NOT present the findings to the user and ask "Want me to implement this?" or "Should I proceed?". SIMPLE verdicts proceed directly and autonomously to `Skill("implement")`. The user has already consented by running `/triage`. Pausing to ask is a process violation.

**If VERDICT: COMPLEX:**

```
bd create "<TITLE>" -t task -p <PRIORITY>
bd update <id> --description "<BEAD_DESCRIPTION>"
```

Present to the user:
- Bead ID and title
- The `ROOT_CAUSE` section
- The `COMPLEXITY_RATIONALE` (including what further investigation is needed)
- The bead description (so the user can see what was captured)

Then **STOP**. Do not invoke implement. The bead is created and ready for a future session.

## Notes

- Never read `docs/specs/` during triage — those docs are stale for new work
- Never read `docs/ROADMAP.md` — not relevant for triage
- Beads created here must be fully self-contained: no references to spec docs in descriptions
- If a near-duplicate bead already exists, note the overlap to the user instead of creating a duplicate
