---
name: implement
description: Pick up the next unblocked implementation task from Beads and implement it
argument-hint: "[phase or task-id, e.g. p0, p1, or big-pig-farm-mobile-5qe]"
---

# Implement — Plan-Then-Execute Workflow

This skill uses a three-phase approach: a Plan subagent researches and designs the implementation, the main agent reviews and iterates on the plan, then the main agent executes the plan in a worktree with full user oversight.

## Phase 1 — Task Selection

**List candidates** — use `bd ready -t task` which checks dependency satisfaction and excludes in_progress/blocked/deferred beads. The `-t task` filter prevents decision and epic beads from appearing (those need human input, not implementation):

```
bd ready -t task -n 30
```

**IMPORTANT:** Never use `bd list --ready` as a substitute — it does NOT check dependency satisfaction (only filters by status). Always use `bd ready`.

If an argument was provided (`$ARGUMENTS`):
- If it looks like a bead ID (e.g. `big-pig-farm-mobile-5qe`), use that task directly — but still verify it is `○ open` via `bd show <id>` before claiming
- If it's a phase label (e.g. `p0`, `p1`, `phase-0`), add `-l <label>` to the command
- If it's a priority (e.g. `P0`, `P1`), add `-p <priority>` to the command
- If it's a feature label (e.g. `feature:icloud-sync`), add `-l <label>` to the command

Otherwise, pick the highest-priority (lowest P-number) task from the results. Skip tasks labeled "spec" or "investigation".

**Claim atomically** — use `--claim` which sets status to `in_progress` and assignee in one operation, and fails if another agent already claimed it:

```
bd show <id>                        # 1. Pre-check: verify status is open
bd update <id> --claim              # 2. Atomic claim
bd show <id>                        # 3. Post-check: verify you own it
```

If `--claim` fails or hangs (another agent claimed it between your list and claim), pick the next task from your candidate list. **Never use `bd update <id> --status in_progress` directly** — it has no race protection.

## Phase 1.5 — Check-In

Before planning, gather awareness of what other agents are doing:

```
bd comments <id>                              # Warnings from other agents on YOUR bead
bd query "status=in_progress" -n 10           # All beads currently being worked on
```

If your bead has comments (especially `[HEADS UP]` prefixed ones), read them carefully — another agent may have changed an API or discovered something that affects your approach.

If another in-progress bead shares a feature label with yours, note which files it likely touches (check its description via `bd show`). Avoid modifying the same files where possible; if overlap is unavoidable, plan to rebase carefully before pushing.

## Phase 2 — Planning (Subagent)

Launch a **Plan** subagent (via Task tool, `subagent_type=Plan`, `model: "opus"`) to research and design the implementation. Give it a detailed prompt that includes:

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

If the plan has issues, launch another Plan subagent (`subagent_type=Plan`, `model: "opus"`) with specific feedback. Use the `resume` parameter to preserve the planner's research context. Iterate until satisfied.

When the plan is approved, write the final version to `.tmp/plan-<bead-id>.md` using the Write tool.

## Phase 4 — Enter Worktree & Implement

**Detect whether you are already in a worktree** by checking if the working directory is inside `.claude/worktrees/`. A session can serve multiple sequential tasks, each on its own branch within the same worktree.

**If already inside a worktree** (the common case after `/clear` between tasks): create a fresh branch off `origin/main` directly. `EnterWorktree` cannot be called from within a worktree — it will fail.

```
git fetch origin main
git checkout -b feature/<bead-id>-<slug> origin/main
xcodegen generate
```

The `xcodegen generate` step is mandatory after switching branches — `project.yml` may have changed on main. The worktree directory name is irrelevant; only the branch matters. Verify with `git log origin/main..HEAD` (must be empty) before proceeding.

**If NOT inside a worktree** (first task in a fresh session): use `EnterWorktree` to create a new worktree, then run `xcodegen generate` inside it.

**From this point forward, your primary reference is the plan file at `.tmp/plan-<bead-id>.md`.** Read it and work through it systematically:

1. **Implement** — write Swift code following the plan's file order and type signatures. Follow all CLAUDE.md conventions.
2. **Test** — write tests as specified in the plan. Use Swift Testing framework (`@Test`, `#expect`, `#require`). Tests are a mandatory deliverable. **Run tests via `/test` (the Skill tool), NEVER via `swift test` or `xcodebuild test` directly** — the `/test` skill runs in a subagent to preserve context.
3. **Commit** — make atomic commits (one logical change per commit). Do NOT push yet.
4. **Update backlog** — create beads for any bugs, tech debt, or follow-ups discovered during implementation. Use `bd create "title" -t task -p <priority> -l <phase-label>`. Add dependency links with `bd dep add <blocked-id> <blocker-id>`.
5. **Broadcast changes** — if you change a public API (protocol, function signature, type rename) or discover something that affects another bead, notify affected beads:
   ```
   bd comments add <other-bead-id> "[HEADS UP from <my-bead-id>] Renamed FacilityManager.refill() → replenish(). Update your callsites."
   ```
6. **Surface architectural decisions** — if you encounter a design choice during implementation, do NOT silently pick one and move on. Two mechanisms, use whichever fits:

   **Inline (same conversation):** Pause, present the options and trade-offs to the user, wait for their answer, then record an ADR in `docs/decisions/` and continue.

   **Decision bead (cross-agent or user is busy):** Create a decision bead with full context:
   ```
   bd create "DECISION: <question>" -t decision -p P1
   ```
   Include in the description: the context, the options with trade-offs, and what it blocks. The user will see this when they run `/next`, which surfaces pending decisions with enough detail to resolve them on the spot. Add it as a blocker for dependent beads:
   ```
   bd dep add <blocked-bead> <decision-bead>
   ```

   **When to use which:** Inline if the user is actively in this conversation and the decision is small enough to resolve quickly. Decision bead if the user is busy, the decision needs thought, or it affects other agents' work.

   Examples of decisions that must be surfaced: choosing between two data structures, deciding an API shape that other code will depend on, picking a persistence strategy, trade-offs between performance and simplicity. When in doubt, ask.
7. **Close bead and update checklist** — from the **worktree directory** (not the main repo):
   - `bd close <id>` — updates the Dolt DB (local-only, **not** git-tracked; `.beads/` is gitignored)
   - Edit `docs/CHECKLIST.md` in the worktree (use the worktree absolute path, not the main repo path)
   - Commit only the checklist: `git add docs/CHECKLIST.md`
   - **Do NOT stage `.beads/issues.jsonl`** — it does not exist in worktrees and is gitignored in the main repo.
   - **These changes belong in the feature PR.** A follow-up housekeeping PR means they were committed in the wrong place. If you catch yourself about to commit them in the main repo working tree, stop — you are in the wrong directory.

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
6. **Sync with main before pushing** — always do this, even if the branch was just created:
   - `git fetch origin main`
   - `git log HEAD..origin/main --oneline` — if any commits appear, rebase: `git rebase origin/main`
   - Resolve any conflicts, then confirm `git log origin/main..HEAD` shows only your commits
7. **Push and open PR** — `git push -u origin <branch>` (use `--force-with-lease` if rebased) then `gh pr create`
8. **Present PR URL and summary to the user. STOP and wait for explicit approval.** Do NOT merge until the user says to proceed (e.g. "go ahead", "merge it", "lgtm", "approved"). The PR must stay open until the user has reviewed it.
9. **Merge (after user approval)** — `gh pr merge <number> --rebase`. We do the merge ourselves after approval; the user should not need to run any git commands.
10. **Sync main repo** — `git -C /Users/nadilbourkadi/Dev/big-pig-farm-mobile pull origin main`. This keeps the main repo's local main branch up to date.
11. **Ready for next task.** Tell the user: "Task complete. Run `/clear` to reset context, then `/implement` for the next task." **Do NOT tell the user to close the session.** The worktree is reusable — `/clear` resets conversation context while keeping the worktree directory. The next `/implement` will detect it's in a worktree and create a fresh branch off `origin/main`.

### Git commands — CRITICAL

**Never use heredocs, subshells, or complex bash constructs.** These trigger permission prompts.

Always write multi-line commit messages to a file first:
1. Use the **Write** tool to create `.tmp/commit-msg.txt`
2. Run `git commit -F .tmp/commit-msg.txt`
