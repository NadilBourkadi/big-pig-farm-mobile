# Big Pig Farm — iOS (CLAUDE.md)

> Project conventions for the mobile repo. Committed to git — all agents and contributors follow these rules.

---

## Shell Commands

- **Never chain commands** (`cmd1 && cmd2`, `cd … && cmd`). Chaining causes permission escalation — even pre-approved commands require re-prompting when chained. Run each command as a separate Bash tool call instead.
- **Never use `grep` or `rg` via Bash.** Always use the native `Grep` tool instead. `Bash(grep:*)` is NOT pre-approved and triggers a permission prompt every time. The native `Grep` tool ("Search" in the UI) is pre-approved and works without prompting.
- **Never prepend `cd`** to commands. The working directory is always the repo root (or the worktree root when in a worktree).
- **When inside a worktree, use the worktree root for ALL file paths — no exceptions.** Never read or write files via the main repo path (e.g. `/Users/.../big-pig-farm-mobile/…`) — every Read, Write, Edit, Glob, Grep, and `cat` must use the worktree absolute path (e.g. `/Users/.../big-pig-farm-mobile/.claude/worktrees/<name>/…`). This includes `.claude/settings.json`, `.claude/skills/**`, `CLAUDE.md`, and any other config file. Even if a config fix is discovered mid-task, it goes into the worktree copy so it ships with the PR. The main repo's files are not the ones being modified.
- Never use inline env vars; use `export` on a separate line
- **Scratch files go in `.tmp/`** (gitignored, inside repo). Use this for commit messages, temp output, etc. **Never write to `/tmp/`** — it is outside the repo sandbox and triggers permission prompts.
- **`*` in Read permissions only works as a trailing wildcard.** `Read(path:~/.claude/skills/**)` and `Read(path:~/.claude/skills/*/*)` both fail — neither `**` nor intermediate `*` segments match subdirectories. The only pattern that works is a trailing `*` on a concrete directory: `Read(path:/Users/nadilbourkadi/.claude/skills/code-review/*)`. Each skill subdirectory needs its own entry. Use absolute paths, not `~`.
- Use explicit file lists over `git add -A`
- Regenerate project after any `project.yml` change: `xcodegen generate`
- Build: `xcodebuild -scheme BigPigFarm -destination 'platform=iOS Simulator,name=iPhone 17' build`
- Test: **always use a per-worktree simulator** — multiple agents run in parallel and share the machine. Never target a shared simulator name like `iPhone 16e` directly. Use the pre-approved script: `bash scripts/run-tests.sh` — it creates a private simulator, runs tests, and cleans up automatically. **Never use inline `$()` substitution in Bash tool calls** — it triggers an un-bypassable security prompt regardless of `settings.json` allow-lists. The script avoids this because `$()` is inside the file, not in the tool call argument.
- Never run `xcodebuild` with `run_in_background: true` — simulators require exclusive access; background + retry causes two builds to fight over the same device.
- **Never put `#` comments inside inline multi-line strings in Bash calls.** Claude Code has a non-overridable security heuristic that blocks commands containing "quoted newline followed by `#`-prefixed line". This applies to inline Python scripts (`python3 -c "...# comment..."`), heredocs, and any multi-line string. Instead: either remove the comments, or write the script to `.tmp/` first and run `python3 .tmp/script.py`.
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

- **ALL implementation work happens in a worktree — no exceptions.** Task size is irrelevant. Running `/implement` directly in the main repo directory is forbidden; it strands the main repo on a feature branch. Use `EnterWorktree` if not already in a worktree; if already inside `.claude/worktrees/`, create a fresh branch off `origin/main` directly.
- **NEVER commit on main.** Always create a feature branch. This applies to every change without exception — code, tests, docs, CLAUDE.md itself, config files. "It's just a one-liner" and "it's only a docs change" are not exceptions.
- **Always push and open PR** when work is complete.
- **Merge with rebase** (not squash, not merge commit).
- **NO "Co-Authored-By" lines** in commits.
- **NO "Generated with Claude Code" footers** in commits or PR descriptions.
- **Atomic commits** — one logical change per commit. Each commit should be a single, self-contained logical unit.
- **Preserve logical commits.** Multiple atomic commits in a PR is expected and good. Do NOT squash logically distinct changes into one commit.
- **Clean up WIP noise before pushing** — use interactive rebase to collapse fixup/WIP commits into their logical parent. Only squash when intermediate commits have no standalone meaning.
- **Commit messages:** Write to `.tmp/commit-msg.txt` (via the Write tool), then `git commit -F .tmp/commit-msg.txt`. Never use heredocs, subshells, or `/tmp/`.
- **PR bodies:** Write to `.tmp/pr-body.md` (via the Write tool), then `gh pr create --body-file .tmp/pr-body.md`. Never pass markdown with `#` headers inline — it triggers a built-in security heuristic about hidden arguments that cannot be overridden via settings.
- **Bead descriptions:** Write to `.tmp/bead-desc.txt` (via the Write tool), then `bd update <id> --body-file .tmp/bead-desc.txt`. Never use `$()` command substitution or inline `#`-prefixed markdown headers in `--description` arguments — both trigger non-overridable Claude Code security heuristics.

## Pre-Push Workflow — CRITICAL

1. Run `/code-review swift`
2. Fix worthwhile findings
3. Run `/code-review swift` again
4. Clean up WIP/fixup commits (preserve logically distinct commits)
5. **Push immediately** — `git push -u origin <branch>` (use `--force-with-lease` if rebased). Do NOT pause to ask for permission. Pushing is automatic after a clean review.
6. **Open the PR** — `gh pr create`. Present the PR URL and a brief summary to the user.
7. **STOP and wait for explicit merge approval.** Do not merge until the user says to proceed (e.g. "go ahead", "merge it", "lgtm", "approved"). The rule: **push is automatic; merge is gated.**

## Checklist — CRITICAL

**After completing any spec document, investigation item, or implementation task, update `docs/CHECKLIST.md` immediately.** This is mandatory — do not consider a task complete until the checklist reflects it.

The checklist is the project's single source of truth for progress. If it's not checked off, it's not done.

## Fix As You Go

Run `swiftlint lint` regularly. Fix warnings immediately — don't let them accumulate. Zero-warning policy.

## Debugging — Visual Issues

For camera, layout, and rendering bugs that are hard to diagnose from code alone, take a simulator screenshot and read it directly in the conversation. This gives immediate visual evidence of what the user is seeing.

```bash
# 1. Find the booted simulator UDID
xcrun simctl list devices booted

# 2. Capture a screenshot (use .tmp/ to stay in the repo sandbox)
xcrun simctl io <UDID> screenshot /absolute/path/to/.tmp/sim-screenshot.png

# 3. Read the file in the conversation — Claude Code can view PNG images
# Use the Read tool on the .tmp/sim-screenshot.png path
```

- This technique is especially useful for camera/HUD positioning bugs, biome rendering issues, and any visual artifact that's easier to see than describe.
- Always use `.tmp/` for the screenshot output path — `/tmp/` is outside the repo sandbox and triggers permission prompts.
- `xcrun simctl list devices booted` shows the UDID of whichever simulator is currently running the app.
- **User-taken screenshots** (via Cmd+S in Simulator.app) are saved to `~/Desktop/` with the pattern `Simulator Screenshot - <device> - <date>.png`. When the user says "look at my screenshot" or "the latest screenshot", check `~/Desktop/Simulator Screenshot*.png` (use `find` with `-mmin` to get recent ones, since glob may miss filenames with spaces).

## Debugging — Structured Debug Log

The app includes a structured debug logging system (`DebugLogger`) that records simulation events to a SQLite database. Active in Debug and Internal (TestFlight) builds only — stripped from Release.

**Where to find the database:**

- **iCloud sync (preferred — works without the app running):**
  ```bash
  sqlite3 "/Users/nadilbourkadi/Library/Mobile Documents/iCloud~com~nadilbourkadi~bigpigfarm/Documents/debug.sqlite"
  ```
  Syncs from the device every ~30 seconds (on auto-save) and on every app background transition.

- **Simulator (direct file access):**
  ```bash
  CONTAINER=$(xcrun simctl get_app_container booted com.nadilbourkadi.bigpigfarm data)
  sqlite3 "$CONTAINER/Documents/debug.sqlite"
  ```

- **HTTP server (live queries, app must be in foreground):**
  ```bash
  curl "http://<DEVICE_IP>:8361/events?category=breeding&limit=20"
  curl "http://<DEVICE_IP>:8361/categories"
  ```

**Useful queries:**

```sql
-- Recent breeding events
SELECT message, pig_name, game_day FROM debug_events WHERE category='breeding' ORDER BY id DESC LIMIT 20;

-- Behavior transitions for a specific pig
SELECT message, payload FROM debug_events WHERE category='behavior' AND pig_name='Butterscotch' ORDER BY id DESC LIMIT 20;

-- Warning-level events (critical needs, cancelled pregnancies)
SELECT message, pig_name, category FROM debug_events WHERE level >= 2 ORDER BY id DESC LIMIT 20;

-- Event counts by category
SELECT category, COUNT(*) as cnt FROM debug_events GROUP BY category ORDER BY cnt DESC;

-- Events for a specific pig by UUID
SELECT * FROM debug_events WHERE pig_id='<UUID>' ORDER BY id DESC LIMIT 30;

-- Genetics: what genotypes are being born?
SELECT json_extract(payload, '$.genotype') as geno, json_extract(payload, '$.color') as color, pig_name
  FROM debug_events WHERE message LIKE 'Born:%' ORDER BY id DESC LIMIT 20;

-- Genetics: are dilution carriers breeding?
SELECT message, json_extract(payload, '$.maleGenotype') as male_geno, json_extract(payload, '$.femaleGenotype') as female_geno
  FROM debug_events WHERE category='breeding' AND payload LIKE '%d%' ORDER BY id DESC LIMIT 20;

-- Genetics: births in a specific biome
SELECT pig_name, json_extract(payload, '$.color'), json_extract(payload, '$.genotype')
  FROM debug_events WHERE message LIKE 'Born:%' AND json_extract(payload, '$.biome')='alpine' ORDER BY id DESC LIMIT 20;
```

**Categories:** `behavior`, `breeding`, `birth`, `needs`, `culling`, `economy`, `simulation`, `facility`
**Levels:** 0 = verbose, 1 = info, 2 = warning

**Offline catch-up events — CRITICAL context for debug log analysis:**

`OfflineProgressRunner` fast-forwards game state when the app reopens after being backgrounded. It processes births, breeding, culling, and economy but **intentionally skips behavior AI, spatial grid, and collision**. This means:

- Offline events have `game_day=0` (setGameDay is not called during catch-up)
- Zero `behavior` and `facility` events during offline periods
- Many births/breeding/culling/economy events clustered at the same timestamp
- The absence of behavior events does NOT indicate a logging bug

**How to identify offline catch-up events:** Look for a cluster of birth/breeding/economy events all sharing the same `datetime(timestamp, 'unixepoch', 'localtime')` value. Compare against surrounding behavior events — a gap in behavior events bracketed by timestamped clusters is the offline catch-up.

```sql
-- Detect offline catch-up boundaries: clusters of events at identical timestamps
SELECT datetime(timestamp, 'unixepoch', 'localtime') as ts, COUNT(*) as cnt,
       GROUP_CONCAT(DISTINCT category) as cats
  FROM debug_events GROUP BY ts HAVING cnt > 10 ORDER BY id DESC LIMIT 5;

-- Find the last LIVE behavior event before a suspected offline gap
SELECT id, datetime(timestamp, 'unixepoch', 'localtime'), message, game_day
  FROM debug_events WHERE category='behavior' ORDER BY id DESC LIMIT 1;
```

**When investigating post-offline bugs:** Always check events AFTER the offline cluster. Pigs are reset to `.idle` with random positions after catch-up (`resetBehaviorStates` + `repositionPigs`). Issues observed after reopening may stem from the post-offline state (depleted facilities, overcrowded areas) rather than a code bug.

When investigating simulation bugs (stuck AI, breeding issues, unexpected deaths), **query the debug log first** before reading source code. The structured events often pinpoint the issue directly.

**Extending the debug log:** If a query reveals that the information needed to diagnose an issue is missing from the log, **extend the instrumentation immediately** — add the missing payload fields to the relevant `DebugLogger.shared.log()` call in the simulation code. Common gaps: genotype/phenotype data on births, facility state on consumption events, grid positions on movement. Treat missing debug data the same as a missing test — fix it as part of the investigation, not as a separate task.

## Testing

- Use Swift Testing framework (`@Test`, `#expect`, `#require`)
- **Two test targets:**
  - `BigPigFarmCoreTests/` — logic tests (59 files, ~1,076 tests). Run via `swift test` on macOS, no simulator needed. ~4 seconds.
  - `BigPigFarmTests/` — scene + app tests (20 files). Run via `xcodebuild test` on iOS Simulator. Requires SpriteKit/UIKit/SwiftUI.
- **New logic tests go in `BigPigFarmCoreTests/`** with `@testable import BigPigFarmCore` — unless they reference app-only types (Views, Scene, HapticManager, etc.), in which case they go in `BigPigFarmTests/` with `@testable import BigPigFarm`.
- **Run tests before pushing:** `bash scripts/run-tests.sh` (defaults to `--fast`, logic tests only). Use `--all` for both logic and scene tests.
- **`/test` skill** runs tests in a subagent to keep context clean. Use `/test` (fast), `/test --full` (scene), or `/test --all` (both).
- Zero-warning policy applies to test targets too
- **Every implementation task must include tests.** Tests are a deliverable of the task, not a separate ticket. Do not create standalone test beads.
- **Package.swift** at repo root defines `BigPigFarmCore` — a parallel SPM build of the 54 platform-agnostic source files. It coexists with the Xcode project; the two don't interact.

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
- **`in_progress` is an absolute blocker — no exceptions, no judgment calls.** If a task shows `◐ in_progress` or `IN_PROGRESS`, another agent is actively working on it right now. Do NOT pick it up, do NOT rationalize it as "probably orphaned" or "likely abandoned". The only person who can reassign an in-progress task is the user via explicit instruction (e.g. "take over xtr"). `bd ready` shows all unblocked tasks regardless of status; **always filter to `○ open` only** when selecting work.
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
- **At the start of any task (not just any session), run `git fetch origin main` then `git log origin/main..HEAD`** to check whether the current branch has already-merged commits. If any appear, the branch is stale — create a fresh branch off `origin/main` within the current worktree (`git checkout -b feature/<id>-<slug> origin/main`). A new session is NOT required.
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
