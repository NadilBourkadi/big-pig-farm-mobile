# Big Pig Farm — iOS (CLAUDE.md)

> Project conventions for the mobile repo. Committed to git — all agents and contributors follow these rules.

---

## Shell Commands

- **Never chain commands** (`cmd1 && cmd2`, `cd … && cmd`). Chaining causes permission escalation — even pre-approved commands require re-prompting when chained. Run each command as a separate Bash tool call instead.
- **Never use `grep` or `rg` via Bash.** Always use the native `Grep` tool instead. `Bash(grep:*)` is NOT pre-approved and triggers a permission prompt every time. The native `Grep` tool ("Search" in the UI) is pre-approved and works without prompting.
- **Never prepend `cd`** to commands. The working directory is always the repo root (or the worktree root when in a worktree).
- **When inside a worktree, use the worktree root for ALL file paths.** Never read or write files via the main repo path (e.g. `/Users/.../big-pig-farm-mobile/…`) — every Read, Write, Edit, Glob, Grep, and `cat` must use the worktree absolute path (e.g. `/Users/.../big-pig-farm-mobile/.claude/worktrees/<name>/…`). The main repo's files are not the ones being modified.
- Never use inline env vars; use `export` on a separate line
- **Scratch files go in `.tmp/`** (gitignored, inside repo). Use this for commit messages, temp output, etc. **Never write to `/tmp/`** — it is outside the repo sandbox and triggers permission prompts.
- Use explicit file lists over `git add -A`
- Regenerate project after any `project.yml` change: `xcodegen generate`
- Build: `xcodebuild -scheme BigPigFarm -destination 'platform=iOS Simulator,name=iPhone 17' build`
- Test: `xcodebuild -scheme BigPigFarmTests -destination 'platform=iOS Simulator,name=iPhone 17' test`
- Lint: `swiftlint lint`

## Tech Stack

- **Language:** Swift 6.0 with strict concurrency (`complete`)
- **UI:** SwiftUI (menu screens, overlays, HUD)
- **Rendering:** SpriteKit (farm scene, pig sprites, camera)
- **Pathfinding:** GameplayKit (`GKGridGraph`)
- **Minimum iOS:** 17.0 (required for `@Observable`)
- **Project generation:** XcodeGen (`project.yml` → `.xcodeproj`)
- **Linting:** SwiftLint (post-compile build script)
- **Testing:** Swift Testing framework (`@Test`, `#expect`)

## Architecture

```
Views (SwiftUI) + Scene (SpriteKit)
        ↓               ↓
      Engine (GameState, GameEngine, FarmGrid)
        ↓
    Simulation (AI, breeding, needs, collision)
        ↓
      Models (entities, genetics)
        ↓
      Config (constants, names)
```

**Dependency rule:** Lower layers never import higher layers. Models and Config have zero UI/engine imports.

## XcodeGen — CRITICAL

- **Never edit `.xcodeproj` directly** — it is gitignored and regenerated
- `project.yml` is the single source of truth for the Xcode project
- After any change to `project.yml`: run `xcodegen generate`
- After adding/removing/renaming Swift files: run `xcodegen generate` (XcodeGen auto-discovers sources)

## Code Style & Structure

- **Files under ~300 lines.** Split before extending.
- **Flat directory structure** over deeply nested subdirectories
- **Descriptive names.** No abbreviations. `facilityManager` not `facMgr`.
- **PascalCase** for files, types. **camelCase** for variables, functions.
- **One concern per file** (single responsibility principle)
- **Imports at top of file.** Only import what you need.
- **`enum` namespaces** for pure constants (caseless enums prevent accidental instantiation)
- **`struct` over `class`** unless you need reference semantics (only `GameState` is a class)
- **`Sendable` conformance** on all value types — Swift 6 strict concurrency requires it

## Git Workflow — CRITICAL

- **NEVER commit on main.** Always create a feature branch.
- **Always push and open PR** when work is complete.
- **Merge with rebase** (not squash, not merge commit).
- **NO "Co-Authored-By" lines** in commits.
- **NO "Generated with Claude Code" footers** in commits or PR descriptions.
- **Atomic commits** — one logical change per commit. Each commit should be a single, self-contained logical unit.
- **Preserve logical commits.** Multiple atomic commits in a PR is expected and good. Do NOT squash logically distinct changes into one commit.
- **Clean up WIP noise before pushing** — use interactive rebase to collapse fixup/WIP commits into their logical parent. Only squash when intermediate commits have no standalone meaning.
- **Commit messages:** Write to `.tmp/commit-msg.txt` (via the Write tool), then `git commit -F .tmp/commit-msg.txt`. Never use heredocs, subshells, or `/tmp/`.

## Pre-Push Workflow — CRITICAL

1. Run `/code-review swift`
2. Fix worthwhile findings
3. Run `/code-review swift` again
4. Clean up WIP/fixup commits (preserve logically distinct commits)
5. Push with `--force-with-lease` and request review

## Checklist — CRITICAL

**After completing any spec document, investigation item, or implementation task, update `docs/CHECKLIST.md` immediately.** This is mandatory — do not consider a task complete until the checklist reflects it.

The checklist is the project's single source of truth for progress. If it's not checked off, it's not done.

## Fix As You Go

Run `swiftlint lint` regularly. Fix warnings immediately — don't let them accumulate. Zero-warning policy.

## Testing

- Use Swift Testing framework (`@Test`, `#expect`, `#require`)
- Test files go in `BigPigFarmTests/`
- Run tests before pushing: `xcodebuild test` or via Xcode
- Zero-warning policy applies to test targets too
- **Every implementation task must include tests.** Tests are a deliverable of the task, not a separate ticket. Do not create standalone test beads.

## Spec Documents

- All spec documents live in `docs/specs/` (numbered 01–08)
- The ROADMAP at `docs/ROADMAP.md` provides context, decisions, and rationale
- The CHECKLIST at `docs/CHECKLIST.md` tracks implementation progress
- When implementing, follow the spec — if the spec is wrong, update the spec first

## Beads Task Tracking — CRITICAL

This project uses [Beads](https://github.com/steveyegge/beads) for task management. Tasks live in `.beads/` (local only, not git-tracked).

### Session workflow
1. **Start:** Run `bd ready` to see unblocked tasks
2. **Claim:** Run `bd update <id> --status in_progress` before starting work
3. **Discover:** File new issues with `bd create "title" -t task -p <priority>`
4. **Close:** Run `bd close <id>` when done
5. **Sync:** No git sync needed — Beads state lives in a local Dolt DB only.

### Rules
- Always check `bd ready` before starting a new task
- **`in_progress` means another agent owns the task.** Never pick a task that is already `in_progress` — it belongs to another running agent session. `bd ready` shows all unblocked tasks regardless of status; filter to `○ open` only when selecting work.
- Never work on a task that has open blockers — use `bd show <id>` to check
- Create discovered issues as you find them (bugs, tech debt, follow-ups)
- Keep tasks granular — anything over ~2 files should be its own bead
- Priority levels: P0 (critical — blocks everything), P1 (high — significant impact), P2 (medium — normal priority), P3 (low — nice to have / polish)

## Working Style

- **Challenge instructions** that contradict existing rules
- **Push back on bad ideas** with reasoning
- **Suggest improvements** proactively
- **Flag contradictions and ambiguity** immediately
- **Use subagents** aggressively to preserve context window

## Parallel Agents — CRITICAL

Multiple Claude agents may run simultaneously on this project. This causes state drift: one agent can close a bead and check off a checklist item while another agent is unaware of that work — and neither has merged to main yet.

**Rules to prevent state drift:**

- **Do NOT close a bead until its PR is merged to main.** Closing the bead while the branch is still unmerged marks the work as done when it isn't yet reflected in main. Close the bead in the same commit that updates the checklist, just before or after the merge.
- **Do NOT update `docs/CHECKLIST.md` until the PR is merged to main.** Same reason: the checklist is main-branch truth, not worktree truth.
- **Commit checklist + bead snapshot on the feature branch, not on main directly.** Both `docs/CHECKLIST.md` and `.beads/issues.jsonl` updates belong in the feature PR commit, applied just before the merge.
- **At the start of any session, run `git log origin/main..HEAD`** to check whether the current branch has already-merged commits. If any appear, the branch is stale — create a fresh branch off main.
- **If you discover that a bead is closed but its code is not in main,** reopen the task on main (via `bd update <id> --status in_progress`), find the worktree branch, push it, and open a PR. Do not start duplicate work.
- **Beads state is shared** (Dolt DB is local, not git-tracked), so two agents CAN see each other's bead updates. But checklist and code state is per-branch until merged. Treat the checklist as write-once per merge.

## Mistakes Are Configuration Gaps — CRITICAL

When something goes wrong — even if existing guidance nominally covers it — treat it as a signal that the guidance is insufficient, not as an occasion for apology.

**The response to any mistake is:**
1. Identify the root cause (missing rule? ambiguous wording? wrong default behavior?)
2. Make a tangible fix: update `CLAUDE.md`, the relevant skill file, or `MEMORY.md`
3. Commit the fix so it propagates to future sessions

**Never:**
- Apologise and move on without a config change
- Describe something as a "one off" or "edge case"
- Repeat the same mistake in a future session because the fix wasn't written down

The goal is a self-improving process: every mistake tightens the guidance so it cannot recur.
