# Spec 01 — Project Setup

> **Status:** Complete
> **Date:** 2026-02-26
> **Depends on:** —
> **Blocks:** All other specs (02–08)

---

## Overview

This document records the decisions and implementation details for the initial project scaffolding of the Big Pig Farm iOS port. It covers the Xcode project configuration, folder structure, development tooling, and conventions.

## Decision: XcodeGen over Manual `.xcodeproj`

The Xcode `.pbxproj` format is a fragile binary plist that's hostile to programmatic editing and merging. Instead, we use **XcodeGen** — a YAML spec (`project.yml`) generates the `.xcodeproj`, which is gitignored.

**Trade-offs:**
- Pro: `project.yml` is human-readable, diffable, and merge-friendly
- Pro: Adding files doesn't require manual Xcode project editing
- Pro: AI agents can safely modify project settings
- Con: Requires `brew install xcodegen` on each dev machine
- Con: Must run `xcodegen generate` after any `project.yml` change

**Version:** XcodeGen 2.44.1 (installed via Homebrew)

## Decision: iOS 17.0 Minimum Deployment Target

iOS 17.0 is required for `@Observable` (Observation framework), which is our chosen pattern for `GameState`. This also gives us access to:
- Swift 5.9+ features (macros, parameter packs)
- SwiftUI improvements (scrollable views, `@Bindable`)
- As of February 2026, iOS 17+ covers ~95% of active devices

## Decision: Swift 6.0 with Strict Concurrency

`SWIFT_STRICT_CONCURRENCY: complete` enforces data-race safety at compile time. All value types are marked `Sendable`. `GameState` is `@unchecked Sendable` because it's an `@Observable` class mutated on the main actor.

This is a forward-looking choice — Swift 6 strict concurrency is the future of the language, and it's easier to start strict than to retrofit it later.

## Decision: SwiftLint as Post-Compile Script

SwiftLint is configured as a post-compile build phase script rather than an SPM build tool plugin. The script gracefully degrades — if `swiftlint` isn't installed, it emits a warning instead of failing the build.

This approach was chosen because:
- SPM build tool plugins require full Xcode to compile from source
- The post-compile script works with Homebrew-installed SwiftLint
- It doesn't block compilation — lint issues appear as warnings after a successful build

**Configuration** (`.swiftlint.yml`):
- Line length: 120 warning / 150 error (matches Python repo's `pyproject.toml`)
- File length: 300 warning / 500 error (matches CLAUDE.md convention)
- `force_unwrapping`, `force_cast`, `force_try`: error severity
- `todo` rule: disabled (placeholder files use `TODO:` by design)
- Identifier exceptions: `id`, `x`, `y`, `dx`, `dy`, `i`, `j`

## Decision: Swift Testing Framework (not XCTest)

The test target uses the modern Swift Testing framework (`@Test`, `#expect`, `#require`) instead of XCTest. Swift Testing provides:
- Parameterized tests (`@Test(arguments:)`)
- Better assertion messages with `#expect`
- Tags and traits for test organization
- No class inheritance requirement

## Folder Structure Rationale

The folder structure maps directly from the Python codebase layers:

| Swift Folder | Python Source | Files | Purpose |
|-------------|-------------|-------|---------|
| `Models/` | `entities/` | 7 | Data types, enums, genetics |
| `Engine/` | `game/` | 10 | State, tick loop, grid, pathfinding |
| `Simulation/` | `simulation/` | 14 | AI, breeding, needs, collision |
| `Economy/` | `economy/` | 5 | Shop, market, contracts |
| `Config/` | `data/` | 2 | Constants, name generation |
| `Scene/` | (new) | 4 | SpriteKit rendering layer |
| `Views/` | `ui/screens/` | 9 | SwiftUI screens and components |

**Key differences from Python:**
- `Scene/` is entirely new — SpriteKit replaces the Textual half-block renderer
- `Config/` consolidates `data/config.py` and `data/names.py` (sprite data moves to asset catalogs)
- `Engine/SaveManager.swift` replaces SQLite persistence with JSON + FileManager

## Placeholder File Convention

Every Swift file contains a minimal compilable stub:
1. Doc comment explaining the file's purpose
2. `Maps from:` reference to the Python source file
3. `// TODO: Implement in doc NN` referencing the relevant spec
4. Correct `import` statement for the required framework
5. Base type declaration (struct/class/enum/protocol) with correct conformances

This ensures:
- The project compiles at all times during development
- Import dependencies are validated early
- `TODO` comments create a clear implementation queue
- New contributors can navigate the codebase by reading doc comments

## Files Created

| Category | Count |
|----------|-------|
| Swift source files | 54 |
| Asset catalog JSON | 2 |
| `project.yml` | 1 |
| `.swiftlint.yml` | 1 |
| `.gitignore` | 1 |
| `CLAUDE.md` | 1 |
| `docs/CHECKLIST.md` | 1 |
| `docs/specs/01-project-setup.md` | 1 |
| **Total** | **62** |

## Build Verification

Build verification requires full Xcode.app (not just Command Line Tools). The XcodeGen project generation was verified:
- `xcodegen generate` produces `BigPigFarm.xcodeproj` without errors
- All placeholder files are syntactically valid Swift
- The project is ready for build verification once Xcode is installed

## CLAUDE.md Adaptations

The mobile repo's `CLAUDE.md` was adapted from the Python repo with these changes:
- Shell commands: `xcodegen generate`, `xcodebuild`, `swiftlint lint`
- Architecture diagram: SwiftUI + SpriteKit → Engine → Simulation → Models → Config
- XcodeGen section: explains the regeneration workflow
- Checklist mandate: `docs/CHECKLIST.md` must be updated after every task
- Code style: same principles (files <300 lines, flat structure, descriptive names)
- Git workflow: identical to Python repo (branches, rebase, atomic commits, no Co-Authored-By)

## What's Next

With the project scaffolding in place, the next steps are:
1. **Doc 02 (Data Models):** Translate all enums and structs from `entities/` to Swift
2. **Doc 03 (Sprite Pipeline):** Build the Python export tool and create sprite assets
3. Both can proceed in parallel since they only depend on Doc 01
