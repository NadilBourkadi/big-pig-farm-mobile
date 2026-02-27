# Big Pig Farm — iOS

An iOS port of [Big Pig Farm](https://github.com/NadilBourkadi/big-pig-farm), a guinea pig farm simulation game. Players manage a farm where pigs autonomously eat, sleep, play, breed, and socialize — featuring Mendelian genetics, an economy with contracts, and multi-biome farm expansion.

**Tech stack:** Swift 6 + SpriteKit (farm rendering) + SwiftUI (menus/HUD)

## Project Structure

```
BigPigFarm/
├── Models/       # Entities, genetics, enums
├── Config/       # Constants, name generation
├── Engine/       # GameState, GameEngine, FarmGrid
├── Simulation/   # AI, breeding, needs, collision
├── Scene/        # SpriteKit farm scene, nodes, camera
├── Views/        # SwiftUI screens and overlays
└── Shared/       # Extensions, utilities
docs/
├── ROADMAP.md    # Architecture decisions and rationale
├── CHECKLIST.md  # Human-readable progress tracker
└── specs/        # Specification documents (01–08)
```

## Getting Started

**Prerequisites:** Xcode 16+, XcodeGen (`brew install xcodegen`)

```bash
# Generate Xcode project from project.yml
xcodegen generate

# Build
xcodebuild -scheme BigPigFarm -destination 'platform=iOS Simulator,name=iPhone 17' build

# Test
xcodebuild -scheme BigPigFarmTests -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Task Tracking with Beads

This project uses [Beads](https://github.com/steveyegge/beads) for dependency-aware task management. Tasks are stored in `.beads/` and committed to git.

### Quick Reference

```bash
# See what's ready to work on (unblocked tasks)
bd ready

# Show details for a specific task
bd show <id>

# Claim a task before starting
bd update <id> --status in_progress

# Close a task when done
bd close <id>

# View task statistics
bd stats

# Check for dependency cycles
bd dep cycles

# See what blocks a task
bd dep list <id>

# View full dependency tree
bd dep tree <id>

# List all tasks (with filters)
bd list                    # All open tasks
bd list --status blocked   # Only blocked tasks
bd list -l phase-0         # Filter by label
```

### How It Works

Tasks form a **directed acyclic graph** (DAG) of dependencies. `bd ready` computes the frontier — tasks with zero unresolved blockers — so you always know what can be worked on next.

**Priority levels:**
- **P0** — Foundation (enums, models, config)
- **P1** — Core features (engine, simulation, sprites, specs)
- **P2** — UI and scene (SwiftUI screens, SpriteKit scene)
- **P3** — Polish and investigation (persistence, profiling)

### Task Lifecycle

```
ready → in_progress → closed
         ↓
    (discover new work → bd create)
```

### Agent Skills (Slash Commands)

Two Claude Code skills automate the task pickup workflow. They inject live `bd ready` output and all necessary context pointers so the agent can work autonomously.

**`/write-spec [spec-number]`** — Pick up and write a spec document

```bash
/write-spec        # picks the lowest-numbered unblocked spec
/write-spec 03     # targets Doc 03 specifically
```

The agent reads existing specs as format templates, analyzes the source Python codebase, and follows the ROADMAP's architectural decisions. It enters plan mode for approval before writing.

**`/implement [phase-or-id]`** — Pick up and implement a task

```bash
/implement         # picks highest-priority unblocked task
/implement p0      # filters for Phase 0 tasks
/implement big-pig-farm-mobile-5qe   # targets a specific bead
```

The agent reads the relevant spec, finds the source Python modules, checks existing Swift stubs, and enters plan mode for approval before coding.

Both skills follow the same lifecycle: claim task → explore context → plan → execute → update checklist → close bead → commit on feature branch → open PR.

### Relationship to CHECKLIST.md

Both coexist:
- **`docs/CHECKLIST.md`** — human-readable progress overview (manually updated)
- **`.beads/`** — machine-readable dependency graph for scheduling and parallelization

## Documentation

| Document | Purpose |
|----------|---------|
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Architecture decisions, technology choices, phase breakdown |
| [`docs/CHECKLIST.md`](docs/CHECKLIST.md) | Implementation progress tracker |
| [`docs/specs/01-project-setup.md`](docs/specs/01-project-setup.md) | Project scaffolding spec (complete) |
| [`docs/specs/02-data-models.md`](docs/specs/02-data-models.md) | Data models spec (complete) |
| Specs 03–08 | Remaining specs (in progress) |

## License

Private repository.
