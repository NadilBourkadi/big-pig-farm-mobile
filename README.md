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
├── decisions/    # Architecture Decision Records (ADRs)
└── specs/        # Specification documents (01–08, all complete)
```

## Getting Started

**Prerequisites:** Xcode 26+, XcodeGen (`brew install xcodegen`), Beads (`brew install beads`)

```bash
# Generate Xcode project from project.yml
xcodegen generate

# Build
xcodebuild -scheme BigPigFarm -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run tests (logic tests only, fast)
bash scripts/run-tests.sh

# Run all tests (logic + scene)
bash scripts/run-tests.sh --all

# Lint
swiftlint lint
```

## Working with Agents

This project is designed for parallel development with multiple Claude Code agents. The user orchestrates 3–4 agent instances, each working in its own git worktree.

### Quick Start

1. Open a Claude Code session
2. Run `/next` to see available tasks and pending decisions
3. Run `/implement` to pick up the highest-priority task (or `/implement <bead-id>` for a specific one)
4. The agent plans, implements, tests, and opens a PR
5. Review the PR, then tell the agent to merge ("go ahead" / "merge it")
6. Run `/clear`, then repeat

### Skills

| Skill | Purpose |
|-------|---------|
| `/triage` | Investigate a bug or feature request. Creates a bead, auto-implements if simple. |
| `/implement [id]` | Pick up and implement the next unblocked task. Plans, codes, tests, opens PR. |
| `/next [feature:label]` | Show pending decisions, then auto-start the top task if nothing is blocking. |
| `/status [feature:label]` | Feature workstream overview — progress, blockers, what's in flight across agents. |
| `/test [--fast\|--full\|--all]` | Run tests in a subagent to keep context clean. |
| `/code-review swift` | Pre-push code quality review. |
| `/sim` | Build and launch in iOS Simulator. |

### Typical Session

```
You (terminal 1):  /next                    → see available tasks + pending decisions
You (terminal 1):  /implement               → agent picks up P1 task, starts working
You (terminal 2):  /implement bdye          → agent picks up a specific task
You (terminal 3):  /triage                   → investigate a bug report
You:               review PR from terminal 1 → "merge it"
You (terminal 1):  /clear                   → reset context
You (terminal 1):  /next                    → check for new decisions, pick next task
```

### Decision Handling

When an agent encounters an architectural choice during implementation, it does NOT silently pick one. Instead:

- **If you're in the conversation:** The agent pauses and presents the options to you directly. You decide, the agent records an ADR and continues.
- **If you're busy:** The agent creates a **decision bead** with full context (problem, options, trade-offs, what it blocks). You'll see it the next time you run `/next` — decisions are surfaced before the task list, with enough detail to resolve on the spot.

Decisions are recorded as Architecture Decision Records in `docs/decisions/`.

### Feature Workstreams

For coordinated multi-task features, use **epics** and **labels**:

```bash
# Create an epic (parent container)
bd create "iCloud Sync" -t epic -p P1

# Create child tasks
bd create "CloudKit container setup" -t task -p P2 --parent <epic-id>

# Label everything for filtering
bd label add <id> feature:icloud-sync

# Track progress
/status feature:icloud-sync

# See what's available in this feature
/next feature:icloud-sync
```

### Reviewing PRs

Every PR requires your explicit approval. The agent pushes and opens the PR automatically, then stops and waits. After reviewing:

- **Approve:** Say "merge it", "go ahead", or "lgtm" — the agent merges via rebase
- **Request changes:** Describe what to fix — the agent updates the PR
- **Reject:** Say "close this" or explain why

### Human-in-the-Loop Guarantees

| Gate | What happens |
|------|-------------|
| **Code review** | Every PR waits for explicit merge approval |
| **Architecture decisions** | Agents surface options and wait for your choice |
| **Task assignment** | You choose features/priorities; agents respect the dependency DAG |
| **Feature planning** | Epic + child beads created with your input before implementation starts |

## Task Tracking with Beads

Tasks form a **directed acyclic graph** (DAG) of dependencies. `bd ready` computes the frontier — tasks with zero unresolved blockers.

### Key Commands

```bash
bd ready -t task              # Unblocked implementable tasks
bd ready -t task -l feature:X # ...filtered by feature
bd show <id>                  # Task details and dependencies
bd update <id> --claim        # Atomically claim (race-safe)
bd close <id>                 # Mark complete
bd stats                      # Overview of open/closed counts
bd comments <id>              # View agent-to-agent messages
bd query "status=in_progress" # See what's being worked on
```

### Priority Levels

- **P0** — Critical (blocks everything)
- **P1** — High (significant impact)
- **P2** — Medium (normal priority)
- **P3** — Low (nice to have / polish)

### Bead Types

| Type | Purpose |
|------|---------|
| `task` | Implementation work — picked up by `/implement` |
| `bug` | Bug fix — created by `/triage` |
| `epic` | Feature container — parent for child tasks |
| `decision` | Architectural choice needing human input — surfaced by `/next` |

### Inter-Agent Communication

Agents communicate through bead comments (visible instantly via the shared Dolt DB):

```bash
# Agent A warns Agent B about an API change
bd comments add <bead-id> "[HEADS UP from <my-id>] Renamed Foo.bar() → baz()"

# Before starting work, agents check for warnings
bd comments <my-bead-id>
```

## Documentation

| Document | Purpose |
|----------|---------|
| [`CLAUDE.md`](CLAUDE.md) | Agent conventions — all agents follow these rules |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Architecture decisions and technology choices |
| [`docs/CHECKLIST.md`](docs/CHECKLIST.md) | Implementation progress tracker |
| [`docs/decisions/`](docs/decisions/) | Architecture Decision Records |
| [`docs/specs/`](docs/specs/) | Specification documents (01–08, all complete) |

## License

Private repository.
