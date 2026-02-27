---
name: implement
description: Pick up the next unblocked implementation task from Beads and implement it
argument-hint: "[phase or task-id, e.g. p0, p1, or big-pig-farm-mobile-5qe]"
---

# Implement — Plan-Then-Execute Workflow

This skill uses a three-phase approach: a Plan subagent researches and designs the implementation, the main agent reviews and iterates on the plan, then the main agent executes the plan in a worktree with full user oversight.

## Phase 1 — Task Selection

First, run `bd ready -n 30` to see available implementation tasks.

If an argument was provided (`$ARGUMENTS`):
- If it looks like a bead ID (e.g. `big-pig-farm-mobile-5qe`), use that task directly
- If it's a phase label (e.g. `p0`, `p1`, `phase-0`), filter for tasks with that phase label
- If it's a priority (e.g. `P0`, `P1`), filter by priority level

Otherwise, pick the highest-priority (lowest P-number) unblocked implementation task. Skip tasks labeled "spec" or "investigation".

Claim the task: `bd update <id> --status in_progress`

## Phase 2 — Planning (Subagent)

Launch a **Plan** subagent (via Task tool, `subagent_type=Plan`) to research and design the implementation. Give it a detailed prompt that includes:

- The bead ID, title, and any description from `bd show <id>`
- Instructions to read:
  - The relevant spec in `docs/specs/`
  - `CLAUDE.md` for project conventions
  - Existing Swift stubs in `BigPigFarm/` for this task
  - The Python source at `/Users/nadilbourkadi/Dev/big-pig-farm` (relevant modules only)
  - `docs/specs/02-data-models.md` for type definitions
- Instructions to produce a detailed implementation plan covering:
  - **Files to create/modify** — full paths and purpose of each
  - **Swift type signatures** — key structs, enums, protocols, function signatures
  - **Implementation order** — which file to write first, dependencies between files
  - **Key logic** — algorithms, state machines, formulas being ported from Python (include specifics, not just "port the logic")
  - **Test strategy** — what to test, edge cases, test file location
  - **Architectural notes** — which layer each file belongs to, dependency rule compliance
  - **Checklist items** — which `docs/CHECKLIST.md` items this task closes

The subagent returns the plan as text — it cannot write files.

## Phase 3 — Plan Review (Main Agent)

Review the plan returned by the subagent. Check for:

1. **Completeness** — does it cover everything in the bead and relevant spec sections?
2. **Correctness** — do the type signatures and logic match the spec and Python source?
3. **Architecture** — does it follow the dependency rule (lower layers never import higher)?
4. **Conventions** — CLAUDE.md compliance (naming, file size limits, struct vs class, Sendable)?
5. **Tests** — is the test strategy thorough (edge cases, state transitions, boundaries)?

If the plan has issues, launch another Plan subagent with specific feedback. Use the `resume` parameter to preserve the planner's research context. Iterate until satisfied.

When the plan is approved, write the final version to `.tmp/plan-<bead-id>.md` using the Write tool.

## Phase 4 — Enter Worktree & Implement

Use **EnterWorktree** to create an isolated worktree.

**From this point forward, your primary reference is the plan file at `.tmp/plan-<bead-id>.md`.** Read it and work through it systematically:

1. **Implement** — write Swift code following the plan's file order and type signatures. Follow all CLAUDE.md conventions.
2. **Test** — write tests as specified in the plan. Use Swift Testing framework (`@Test`, `#expect`, `#require`). Tests are a mandatory deliverable.
3. **Commit** — make atomic commits (one logical change per commit). Do NOT push yet.
4. **Update backlog** — create beads for any bugs, tech debt, or follow-ups discovered during implementation. Use `bd create "title" -t task -p <priority> -l <phase-label>`. Add dependency links with `bd dep add <blocked-id> <blocker-id>`.
5. **Close bead** — `bd close <id>`, then update `docs/CHECKLIST.md`

## Phase 5 — Review & Ship

Write a brief implementation summary to `.tmp/summary-<bead-id>.md` capturing: what was built, any deviations from the plan, and new beads created. **From this point forward, work from the committed code and this summary file.**

1. **Sync beads** — run `bd sync`
2. **Run `/code-review swift`** — the pre-push quality gate
3. **Fix findings** — address review issues
4. **Re-review** — `/code-review swift` again until clean
5. **Clean up commit history:**
   - Review `git log --oneline main..HEAD`
   - Preserve logically distinct atomic commits — do NOT collapse everything into one
   - Only squash WIP/fixup commits into their logical parent
   - Write messages with the **Write** tool to `.tmp/commit-msg.txt`, then `git commit -F .tmp/commit-msg.txt`
6. **Push and open PR** — `git push -u origin <branch>` then `gh pr create`

### Git commands — CRITICAL

**Never use heredocs, subshells, or complex bash constructs.** These trigger permission prompts.

Always write multi-line commit messages to a file first:
1. Use the **Write** tool to create `.tmp/commit-msg.txt`
2. Run `git commit -F .tmp/commit-msg.txt`
