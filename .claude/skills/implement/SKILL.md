---
name: implement
description: Pick up the next unblocked implementation task from Beads and plan the implementation
argument-hint: "[phase or task-id, e.g. p0, p1, or big-pig-farm-mobile-5qe]"
---

# Implement — Main-Thread Workflow

## Phase 1 — Task Selection

First, run `bd ready -n 30` to see available implementation tasks.

If an argument was provided (`$ARGUMENTS`):
- If it looks like a bead ID (e.g. `big-pig-farm-mobile-5qe`), use that task directly
- If it's a phase label (e.g. `p0`, `p1`, `phase-0`), filter for tasks with that phase label
- If it's a priority (e.g. `P0`, `P1`), filter by priority level

Otherwise, pick the highest-priority (lowest P-number) unblocked implementation task. Skip tasks labeled "spec" or "investigation".

## Phase 2 — Enter Worktree

Use the **EnterWorktree** tool to create an isolated worktree. This switches the current session into the worktree while keeping everything visible to the user.

Then claim the task: `bd update <id> --status in_progress`

## Phase 3 — Implement (main thread)

All work happens here in the main conversation. The user can see and interject at any point.

1. **Explore** — Read the relevant spec in `docs/specs/`, examine the bead with `bd show <id>`, read existing source files, and study the Python source in `/Users/nadilbourkadi/Dev/big-pig-farm` as needed
2. **Plan** — Enter plan mode to design the implementation approach. Get user approval before writing code.
3. **Implement** — Write the code, following project conventions (CLAUDE.md)
4. **Test** — Write tests using Swift Testing framework (`@Test`, `#expect`). Tests are a deliverable of the task.
5. **Commit** — Make atomic commits (one logical change per commit). Do NOT push or open a PR yet.
6. **Close bead** — `bd close <id>`, then update `docs/CHECKLIST.md`

## Phase 4 — Review & Ship

1. **Sync beads** — run `bd sync` to export ephemeral state to `issues.jsonl`
2. **Run `/code-review swift`** — the pre-push quality gate
3. **Fix findings** — edit files to address review issues
4. **Re-review** — run `/code-review swift` again until clean
5. **Clean up commit history:**
   - Review `git log --oneline main..HEAD` to see all commits
   - Preserve logically distinct atomic commits — do NOT collapse everything into one
   - Only squash WIP/fixup commits into their logical parent
   - Write any commit messages with the **Write** tool to `/tmp/commit-msg.txt`, then `git commit -F /tmp/commit-msg.txt`
6. **Push and open PR** — `git push -u origin <branch>` then `gh pr create`
7. **Discard stale beads state** — run `git checkout -- .beads/issues.jsonl` in the main repo. The worktree's `bd close` updates the shared Dolt DB, which makes the main repo's `issues.jsonl` appear dirty. The PR already contains the correct version, so the local change is always redundant.

### Git commands — CRITICAL

**Never use heredocs, subshells, or complex bash constructs.** These trigger permission prompts.

Always write multi-line commit messages to a file first:
1. Use the **Write** tool to create `.tmp/commit-msg.txt`
2. Run `git commit -F .tmp/commit-msg.txt`
