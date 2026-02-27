---
name: implement
description: Pick up the next unblocked implementation task from Beads and plan the implementation
argument-hint: "[phase or task-id, e.g. p0, p1, or big-pig-farm-mobile-5qe]"
---

# Implement — Task Dispatcher

## Task selection

First, run `bd ready -n 30` to see available implementation tasks.

If an argument was provided (`$ARGUMENTS`):
- If it looks like a bead ID (e.g. `big-pig-farm-mobile-5qe`), use that task directly
- If it's a phase label (e.g. `p0`, `p1`, `phase-0`), filter for tasks with that phase label
- If it's a priority (e.g. `P0`, `P1`), filter by priority level

Otherwise, pick the highest-priority (lowest P-number) unblocked implementation task. Skip tasks labeled "spec" or "investigation".

## Phase 1 — Implement (sub-agent)

Delegate to the **implementer** agent with the following prompt:

> Implement [title from selected task]. Bead ID: [selected bead ID].

The implementer agent runs in an isolated worktree and handles: claim → explore → plan → implement → test → commit. It does **not** push or open a PR.

## Phase 2 — Review & Ship (main conversation)

After the agent returns:

1. **Switch to the worktree** — `cd` into the worktree path returned by the agent
2. **Sync beads** — run `bd sync` to export ephemeral state to `issues.jsonl`
3. **Run `/code-review swift`** — the pre-push quality gate
4. **Fix findings** — edit files in the worktree to address review issues
5. **Re-review** — run `/code-review swift` again until clean
6. **Clean up commit history:**
   - Review `git log --oneline main..HEAD` to see all commits
   - Preserve logically distinct atomic commits — do NOT collapse everything into one
   - Only squash WIP/fixup commits into their logical parent
   - If the agent produced a single messy commit, `git reset --soft main` and re-commit with clean, selective `git add` (never `git add -A`)
   - If the agent produced multiple clean atomic commits, leave them as-is
   - Write any commit messages with the **Write** tool to `/tmp/commit-msg.txt`, then `git commit -F /tmp/commit-msg.txt`
7. **Push and open PR** — `git push -u origin <branch>` then `gh pr create`
8. **Return to main working directory**
9. **Discard stale beads state** — run `git checkout -- .beads/issues.jsonl` in the main repo before pulling. The worktree agent's `bd close` updates the shared Dolt DB, which makes the main repo's `issues.jsonl` appear dirty. The PR already contains the correct version, so the local change is always redundant.

### Git commands — CRITICAL

**Never use heredocs, subshells, or complex bash constructs.** These trigger permission prompts.

Always write multi-line commit messages to a file first:
1. Use the **Write** tool to create `/tmp/commit-msg.txt`
2. Run `git commit -F /tmp/commit-msg.txt`
