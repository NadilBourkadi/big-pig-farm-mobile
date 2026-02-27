# Big Pig Farm — iOS (CLAUDE.md)

> Project conventions for the mobile repo. Committed to git — all agents and contributors follow these rules.

---

## Shell Commands

- The working directory is always the repo root — never prepend `cd` to commands
- Never use inline env vars; use `export` on a separate line
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
- **Atomic commits** — one logical change per commit. Each commit should be a single, self-contained logical unit.
- **Preserve logical commits.** Multiple atomic commits in a PR is expected and good. Do NOT squash logically distinct changes into one commit.
- **Clean up WIP noise before pushing** — use interactive rebase to collapse fixup/WIP commits into their logical parent. Only squash when intermediate commits have no standalone meaning.

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

This project uses [Beads](https://github.com/steveyegge/beads) for task management. Tasks live in `.beads/` and are committed to git.

### Session workflow
1. **Start:** Run `bd ready` to see unblocked tasks
2. **Claim:** Run `bd update <id> --status in_progress` before starting work
3. **Discover:** File new issues with `bd create "title" -t task -p <priority>`
4. **Close:** Run `bd close <id>` when done
5. **Sync:** Commit `.beads/` changes with your code changes

### Rules
- Always check `bd ready` before starting a new task
- Never work on a task that has open blockers — use `bd show <id>` to check
- Create discovered issues as you find them (bugs, tech debt, follow-ups)
- Keep tasks granular — anything over ~2 files should be its own bead
- The `.beads/` directory is committed to git — include it in PRs
- Priority levels: P0 (foundation), P1 (core features), P2 (UI/scene), P3 (polish/investigation)

## Working Style

- **Challenge instructions** that contradict existing rules
- **Push back on bad ideas** with reasoning
- **Suggest improvements** proactively
- **Flag contradictions and ambiguity** immediately
- **Use subagents** aggressively to preserve context window
