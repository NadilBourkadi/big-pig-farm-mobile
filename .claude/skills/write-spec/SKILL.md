---
name: write-spec
description: Pick up the next unblocked spec document task from Beads and write the specification
argument-hint: "[spec-number, e.g. 03]"
---

# Write Spec — Plan-Then-Execute Workflow

This skill uses a three-phase approach: a Plan subagent researches and designs the spec structure, the main agent reviews and iterates on the plan, then the main agent writes the spec in a worktree with full user oversight.

## Phase 1 — Task Selection

First, run `bd list -l spec --status open` to see available spec tasks.

If an argument was provided (`$ARGUMENTS`), find the spec task matching that number (e.g. "03" matches "Doc 03"). Otherwise, pick the lowest-numbered unblocked spec.

Claim the task: `bd update <id> --status in_progress`

## Phase 2 — Planning (Subagent)

Launch a **Plan** subagent (via Task tool, `subagent_type=Plan`, `model: "opus"`) to research and design the spec structure. Give it a detailed prompt that includes:

- The bead ID, title, and spec number
- Instructions to read:
  - `docs/ROADMAP.md` for architectural decisions and rationale
  - Bead details via `bd show <id>`
  - Dependent specs in `docs/specs/` (check bead dependencies)
  - Existing specs (01 and 02) as format/structure/level-of-detail reference
  - `docs/CHECKLIST.md` for scope
  - The Python source at `/Users/nadilbourkadi/Dev/big-pig-farm` (relevant modules only)
- Instructions to produce a detailed plan covering:
  - **Spec outline** — section headings and what each section covers
  - **Key types** — Swift type signatures for all structs, enums, and protocols
  - **Python source mapping** — which Python files/classes map to which spec sections
  - **ROADMAP decisions** — which architectural decisions apply and how they constrain the spec
  - **Implementation tasks** — beads to create or update after the spec is written
  - **Open questions** — anything that needs a "Decision needed" section

The subagent returns the plan as text — it cannot write files.

## Phase 3 — Plan Review (Main Agent)

Review the plan returned by the subagent. Check for:

1. **Completeness** — does the outline cover everything the spec needs?
2. **Correctness** — do the type signatures align with ROADMAP decisions?
3. **Scope** — does it match the CHECKLIST.md tasks this spec should cover?
4. **Quality bar** — is it detailed enough that an agent could implement from it without clarifying questions?

If the plan has issues, launch another Plan subagent (`subagent_type=Plan`, `model: "opus"`) with specific feedback. Use the `resume` parameter to preserve the planner's research context. Iterate until satisfied.

When the plan is approved, write the final version to `.tmp/plan-<bead-id>.md` using the Write tool.

## Phase 4 — Enter Worktree & Write Spec

Use **EnterWorktree** to create an isolated worktree.

**From this point forward, your primary reference is the plan file at `.tmp/plan-<bead-id>.md`.** Read it and work through it systematically:

1. **Write** — create the spec at `docs/specs/NN-<name>.md` following the plan's outline and the established format of existing specs
2. **Commit** — make atomic commits. Do NOT push yet.
3. **Update backlog** — create/update beads as the spec reveals work. Use `bd create "title" -t task -p <priority> -l <phase-label>`. Add dependency links with `bd dep add <blocked-id> <blocker-id>`.
4. **Close bead** — `bd close <id>`, then update `docs/CHECKLIST.md`

## Phase 5 — Review & Ship

Write a brief summary to `.tmp/summary-<bead-id>.md` capturing: what was written, beads created/updated, and any deviations from the plan. **From this point forward, work from the committed spec and this summary file.**

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
7. **Discard stale beads state** — `git checkout -- .beads/issues.jsonl` in the main repo

### Git commands — CRITICAL

**Never use heredocs, subshells, or complex bash constructs.** These trigger permission prompts.

Always write multi-line commit messages to a file first:
1. Use the **Write** tool to create `.tmp/commit-msg.txt`
2. Run `git commit -F .tmp/commit-msg.txt`
