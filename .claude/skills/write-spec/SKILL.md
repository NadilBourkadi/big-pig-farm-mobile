---
name: write-spec
description: Pick up the next unblocked spec document task from Beads and write the specification
argument-hint: "[spec-number, e.g. 03]"
---

# Write Spec — Main-Thread Workflow

## Phase 1 — Task Selection

First, run `bd list -l spec --status open` to see available spec tasks.

If an argument was provided (`$ARGUMENTS`), find the spec task matching that number (e.g. "03" matches "Doc 03"). Otherwise, pick the lowest-numbered unblocked spec.

## Phase 2 — Enter Worktree

Use the **EnterWorktree** tool to create an isolated worktree. This switches the current session into the worktree while keeping everything visible to the user.

Then claim the task: `bd update <id> --status in_progress`

## Phase 3 — Write Spec (main thread)

All work happens here in the main conversation. The user can see and interject at any point.

1. **Explore** — Read the ROADMAP at `docs/ROADMAP.md`, examine the bead with `bd show <id>`, read any dependent specs in `docs/specs/`, and study the Python source in `/Users/nadilbourkadi/Dev/big-pig-farm` as needed
2. **Plan** — Enter plan mode to outline the spec structure. Get user approval before writing.
3. **Write** — Write the spec document, following the format and conventions of existing specs
4. **Commit** — Make atomic commits (one logical change per commit). Do NOT push or open a PR yet.
5. **Close bead** — `bd close <id>`, then update `docs/CHECKLIST.md`

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
