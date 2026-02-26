# Big Pig Farm — iOS Port Roadmap

> **Living document.** This roadmap guides the port of Big Pig Farm from Python/Textual to Swift/SpriteKit/SwiftUI for iOS. Update it as decisions are made and specs are written.

---

## 1. Project Overview

### What We're Porting

Big Pig Farm is a terminal-based idle simulation game where players manage a guinea pig farm. Pigs autonomously eat, sleep, play, breed, and socialize. The game features Mendelian genetics (6 loci, 144 phenotype combinations), an economy with contracts, multi-biome farm expansion, and a pixel art aesthetic rendered via Unicode half-block characters.

**Source codebase:** ~20,200 lines of Python across 79 files, plus 8,500 lines of tests across 31 files.

### Why iOS

The game's idle/simulation loop and pixel art style are a natural fit for mobile. The existing codebase has excellent game/UI separation — 70% of the code (all of `entities/`, `simulation/`, `economy/`, and most of `game/`) has zero Textual imports. Only 3 event callbacks connect simulation to UI. This clean architecture means the port is a "rewrite in a new language" rather than "untangle and rebuild."

### Technology Choices

| Layer | Python (Current) | Swift (Target) | Why |
|-------|-----------------|----------------|-----|
| UI framework | Textual (terminal) | SwiftUI | Native iOS, declarative, excellent for menu screens |
| Farm rendering | Half-block Unicode pixels | SpriteKit | Hardware-accelerated 2D, built-in camera/zoom, touch handling |
| Data models | Pydantic BaseModel | Swift structs + Codable | Type-safe serialization, same role |
| Persistence | SQLite + JSON blob | JSON file via FileManager | Simpler than SQLite for single-save games; Codable handles serialization |
| Game loop | asyncio tick loop | Timer / CADisplayLink | Native iOS game loop patterns |
| Pathfinding | Custom A* | GKGridGraph (GameplayKit) | Apple-provided, optimized for grids |
| Package manager | Poetry | Swift Package Manager | Standard Swift dependency management |

### Architectural Mapping

| Python Concept | Swift Equivalent |
|---------------|-----------------|
| `Pydantic BaseModel` | `struct` conforming to `Codable` |
| `StrEnum` / `IntEnum` | `enum: String, Codable` / `enum: Int, Codable` |
| `dict[UUID, GuineaPig]` | `[UUID: GuineaPig]` |
| `list[FarmArea]` | `[FarmArea]` |
| `Optional[str]` | `String?` |
| `@dataclass(frozen=True)` (config) | `enum` with static properties (namespace) or `struct` with `let` fields |
| `asyncio` tick loop | `Timer.scheduledTimer` on main run loop |
| `Callable[[str], None]` callbacks | `((String) -> Void)?` closures or `@Observable` properties |
| `Protocol` (facades.py) | `protocol` (Swift protocols) |
| A* pathfinding | `GKGridGraph.findPath(from:to:)` |
| Half-block pixel grid | `SKSpriteNode` with `SKTexture` from PNG |
| Textual `Screen` | SwiftUI `View` presented as `.sheet` or `NavigationStack` destination |
| Textual `Message` | SwiftUI action closures / `@Observable` state changes |

### Codebase Statistics

| Layer | Python Files | Lines | Port Complexity |
|-------|-------------|-------|-----------------|
| Entities (models, genetics) | 8 | 1,850 | Medium — straightforward struct translations, genetics logic needs care |
| Game (engine, world, state) | 13 | 3,152 | Medium-High — pathfinding, grid management, state container |
| Simulation (AI, breeding, needs) | 15 | 4,415 | High — behavior state machine, facility scoring, collision |
| Economy (shop, contracts) | 6 | 1,225 | Low — simple purchase/sell logic |
| Data/Config | 13 | 4,254 | Low-Medium — constants + sprite data (sprites become PNGs) |
| UI (screens + widgets) | 21 | 5,068 | Rewrite — all new SwiftUI/SpriteKit code |
| **Total** | **79** | **~20,200** | |

---

## 2. Specification Documents

Eight specification documents to be produced in future sessions, in dependency order. Each document will be written to `docs/specs/` and will contain implementation-ready detail.

### Dependency Graph

```
01-project-setup ─────────────────────┐
    │                                 │
    ├── 02-data-models ───────────────┤
    │       │                         │
    │       ├── 04-game-engine ───────┤
    │       │       │                 │
    │       │       ├── 05-behavior-ai│
    │       │       │       │         │
    │       │       ├───────┼── 07-swiftui-screens
    │       │       │       │
    │       ├───────┼───────┴── 06-farm-scene
    │       │       │
    ├── 03-sprite-pipeline ─┘
    │
    └── 08-persistence-polish (depends on all)
```

### Document Specifications

#### `01-project-setup.md`

| Field | Value |
|-------|-------|
| **Purpose** | Establish the Xcode project, folder structure, and development tooling |
| **Scope** | Xcode project creation, folder hierarchy, SPM dependencies, SwiftLint config, CLAUDE.md for the mobile repo, `.gitignore`, build schemes (Debug/Release), minimum iOS version, device targets |
| **Depends On** | — |
| **Key Decisions** | Minimum iOS version (17.0+ for `@Observable`?), folder structure convention, SwiftLint rule set |
| **Estimated Effort** | 1 session |
| **Template Outline** | 1. Xcode project settings (bundle ID, team, deployment target) |
| | 2. Folder structure with rationale |
| | 3. SPM dependencies (if any beyond Apple frameworks) |
| | 4. SwiftLint configuration |
| | 5. CLAUDE.md for mobile repo (coding conventions, shell commands, git workflow) |
| | 6. Build schemes and configurations |
| | 7. `.gitignore` |

---

#### `02-data-models.md`

| Field | Value |
|-------|-------|
| **Purpose** | Translate all Python Pydantic models and enums to Swift Codable structs/enums |
| **Scope** | ~19 Pydantic models → Swift structs, ~21 enums → Swift enums, type aliases, computed properties, `Codable` conformance, `Hashable`/`Equatable` where needed |
| **Depends On** | 01 |
| **Key Decisions** | `GameState` as `@Observable class` vs struct (recommendation: class — see Section 4), UUID generation strategy, `Codable` coding keys for JSON compatibility |
| **Estimated Effort** | 1-2 sessions |
| **Template Outline** | 1. Entity models: `GuineaPig`, `Needs`, `Position`, `Genotype`, `Phenotype` |
| | 2. Facility models: `Facility`, `FacilitySize`, `FacilityType` enum (17 cases) |
| | 3. World models: `FarmArea`, `TunnelConnection`, `Cell`, `CellType` |
| | 4. Game state: `GameState`, `GameTime`, `EventLog`, `BreedingPair` |
| | 5. Economy models: `BreedingContract`, `ContractBoard`, `BreedingProgram` |
| | 6. Collection models: `Pigdex`, `Bloodline` |
| | 7. All 21 enums with raw values and `Codable` conformance |
| | 8. Config namespaces: `SimulationConfig`, `NeedsConfig`, `BreedingConfig`, `EconomyConfig`, `BehaviorConfig`, `GeneticsConfig`, `BiomeConfig`, `ContractConfig` |
| | 9. Validation rules (which Pydantic validators need manual Swift equivalents) |

**Source files to translate:**

| Python File | Lines | Swift Structs/Enums |
|-------------|-------|-------------------|
| `entities/guinea_pig.py` | 291 | `GuineaPig`, `Needs`, `Position`, `Gender`, `AgeGroup`, `BehaviorState`, `Personality` |
| `entities/genetics.py` | 654 | `Genotype`, `Phenotype`, `Allele`, `BaseColor`, `Pattern`, `ColorIntensity`, `RoanType`, `Rarity` |
| `entities/facilities.py` | 362 | `Facility`, `FacilitySize`, `FacilityType` |
| `entities/areas.py` | 78 | `FarmArea`, `TunnelConnection` |
| `entities/biomes.py` | 185 | `BiomeType` |
| `entities/bloodlines.py` | 116 | `Bloodline`, `BloodlineType` |
| `entities/pigdex.py` | 163 | `Pigdex` |
| `game/state.py` | 264 | `GameState`, `GameTime`, `EventLog`, `BreedingPair` |
| `game/world.py` | 496 | `FarmGrid`, `Cell`, `CellType` |
| `economy/contracts.py` | 307 | `BreedingContract`, `ContractBoard`, `ContractDifficulty` |
| `economy/shop.py` | 441 | `ShopItem`, `ShopCategory` |
| `simulation/breeding_program.py` | 388 | `BreedingProgram`, `BreedingStrategy` |
| `data/config.py` | 507 | All config namespaces |

---

#### `03-sprite-pipeline.md`

| Field | Value |
|-------|-------|
| **Purpose** | Convert Python pixel art data into PNG texture atlases for SpriteKit |
| **Scope** | Python export tool that reads pixel grids + palettes and outputs PNGs, texture atlas organization, color variant generation, pattern overlay system, animation frame sheets |
| **Depends On** | 01 |
| **Key Decisions** | Export resolution (1x, 2x, 3x?), atlas packing strategy, runtime vs build-time color variant generation, pattern application method |
| **Estimated Effort** | 2-3 sessions |
| **Template Outline** | 1. Inventory of all sprite data (pigs: 3 zoom × 2 ages × 2 directions × ~10 states; facilities: 17 types × 3 zooms; indicators; portraits) |
| | 2. Python export tool design: read pixel grid → apply palette → output PNG |
| | 3. Color variants: 8 base colors × pattern overlays |
| | 4. Animation frames: walking (3), eating (2), sleeping (2), happy (2), sad (1) |
| | 5. Texture atlas structure and naming conventions |
| | 6. SpriteKit `SKTextureAtlas` loading strategy |
| | 7. Runtime pattern/intensity application (if not pre-rendered) |
| | 8. Asset catalog organization |

**Sprite inventory from source:**

| Asset Type | Source File | Variants |
|-----------|------------|----------|
| Pig (normal zoom) | `pig_sprites.py` (469 lines) | 14×8px adults, 8×6px babies, 10 animation states, 2 directions |
| Pig (close zoom) | `pig_sprites_close.py` (366 lines) | 28×16px adults, hand-crafted |
| Pig portraits | `pig_portraits.py` (246 lines) | Larger pixel art for detail views |
| Facilities (normal) | `facility_pixels.py` (670 lines) | 17 types, varying sizes |
| Facilities (close) | `facility_pixels_close.py` (732 lines) | 17 types, hand-crafted |
| Indicators | `indicator_pixels.py` (191 lines) | Status icons (hunger, sleep, etc.) |
| Color palettes | `sprite_engine.py` (lines 152-281) | 8 palettes, 13 color keys each |

**Note:** We will use only the "normal zoom" sprites. SpriteKit's camera system handles zoom levels natively — no need to port the multi-zoom sprite sets. Close-zoom sprites are skipped; the camera simply zooms into the normal-resolution textures. This significantly reduces the sprite pipeline scope.

---

#### `04-game-engine.md`

| Field | Value |
|-------|-------|
| **Purpose** | Port the core game engine: tick loop, state management, grid world, pathfinding, economy |
| **Scope** | `SimulationRunner` tick orchestration, `GameEngine` timer, `FarmGrid` with areas/tunnels/expansion, A* pathfinding (via `GKGridGraph`), `FacilityManager` scoring and caching, economy (shop purchases, market sales, contracts), auto-arrange |
| **Depends On** | 02 |
| **Key Decisions** | `GKGridGraph` vs custom A* (recommendation: GKGridGraph — see Section 4), tick rate on iOS (10 TPS matches Python), facility manager cache invalidation strategy |
| **Estimated Effort** | 3-4 sessions |
| **Template Outline** | 1. `SimulationRunner` — tick phase orchestration (needs → behavior → breeding → birth → aging → collision → economy) |
| | 2. `GameEngine` — `Timer`-based tick loop with speed control (7 speed levels) |
| | 3. `FarmGrid` — 2D grid, `CellType`, walkability, multi-area support |
| | 4. Area management — `FarmArea` creation, tunnel carving, grid expansion by tier |
| | 5. Pathfinding — `GKGridGraph` integration, path caching, performance counters |
| | 6. `FacilityManager` — facility scoring (distance + crowding + biome affinity), resource consumption, occupancy tracking, unreachable backoff |
| | 7. Economy — shop purchase/refund, market sell with rarity pricing, contract fulfillment |
| | 8. Auto-arrange — facility layout algorithm |
| | 9. Collision — spatial hash grid, separation forces, dodge logic |
| | 10. Performance targets and profiling strategy |

**Source files to port:**

| Python File | Lines | Key Logic |
|-------------|-------|-----------|
| `simulation/runner.py` | 252 | Tick orchestration phases |
| `game/engine.py` | 122 | Async tick loop |
| `game/world.py` | 496 | FarmGrid core |
| `game/world_pathfinding.py` | 142 | A* implementation |
| `game/world_tunnels.py` | 181 | Tunnel carving |
| `game/world_areas.py` | 142 | Area management |
| `game/world_expansion.py` | 256 | Grid expansion |
| `game/auto_arrange.py` | 787 | Facility auto-layout |
| `simulation/facility_manager.py` | 858 | Facility scoring, path cache |
| `simulation/collision.py` | 250 | Spatial hash, separation |
| `simulation/needs.py` | 227 | Needs decay/recovery |
| `simulation/auto_resources.py` | 134 | Drip systems, AoE facilities |
| `economy/shop.py` | 441 | Shop items, purchase logic |
| `economy/market.py` | 174 | Pig selling, value calc |
| `economy/contracts.py` | 307 | Contracts system |
| `economy/upgrades.py` | 264 | 20+ permanent perks |
| `economy/currency.py` | 38 | Currency formatting |
| `game/state.py` | 264 | GameState container |
| `game/facades.py` | 84 | Protocol interfaces |

---

#### `05-behavior-ai.md`

| Field | Value |
|-------|-------|
| **Purpose** | Port the pig behavior AI: state machine, decision tree, movement, facility seeking, courtship |
| **Scope** | `BehaviorController` (coordinator), `BehaviorDecision` (need evaluation + personality), `BehaviorMovement` (pathfinding, wandering, dodging), `BehaviorSeeking` (facility scoring, social, courtship), breeding system (pair selection, courtship timer, pregnancy, birth, aging) |
| **Depends On** | 02, 04 |
| **Key Decisions** | Enum + switch vs `GKStateMachine` (recommendation: enum — see Section 4), commitment system implementation, content pig throttling |
| **Estimated Effort** | 2-3 sessions |
| **Template Outline** | 1. Behavior states: IDLE, WANDERING, EATING, DRINKING, PLAYING, SLEEPING, SOCIALIZING, COURTING |
| | 2. Decision tree: priority-based need evaluation with personality modifiers |
| | 3. Guard system: interruption rules per state, critical need overrides |
| | 4. Commitment system: pigs stay at activity until need >= 90% |
| | 5. Content pig throttling: 8s decision interval when all needs satisfied |
| | 6. Facility seeking: scoring function (distance + crowding + biome + randomness) |
| | 7. Social interactions: nearest non-shy pig seeking |
| | 8. Movement: multi-waypoint consumption, collision-aware movement, dodge attempts |
| | 9. Wandering: biome-biased A* for color-matched pigs, straight-line for others |
| | 10. Courtship: partner selection, proximity timer, success/failure |
| | 11. Breeding: pair selection, gestation, litter generation, genetics inheritance |
| | 12. Birth and aging: baby → adult → senior transitions, senior mortality |
| | 13. Culling: surplus management, auto-sell by breeding program strategy |
| | 14. Acclimation: biome preference development over time |

**Source files to port:**

| Python File | Lines | Key Logic |
|-------------|-------|-----------|
| `simulation/behavior_controller.py` | 168 | AI coordinator |
| `simulation/behavior_decision.py` | 312 | Decision tree, need priorities |
| `simulation/behavior_movement.py` | 502 | Movement, wandering, dodging |
| `simulation/behavior_seeking.py` | 285 | Facility scoring, social, courtship seeking |
| `simulation/breeding.py` | 458 | Pair selection, courtship, auto-pairing |
| `simulation/breeding_program.py` | 388 | Targeted breeding strategies |
| `simulation/birth.py` | 328 | Pregnancy, birth, aging |
| `simulation/culling.py` | 206 | Surplus management |
| `simulation/acclimation.py` | 46 | Biome acclimation |
| `entities/genetics.py` | 654 | Mendelian genetics, breeding |
| `entities/bloodlines.py` | 116 | Adoption bloodlines |

---

#### `06-farm-scene.md`

| Field | Value |
|-------|-------|
| **Purpose** | Build the SpriteKit farm scene: terrain, pigs, facilities, camera, touch interaction |
| **Scope** | `FarmScene` (SKScene), terrain tile rendering, pig sprite nodes with animation, facility sprite nodes, camera system (pan, pinch-zoom), touch interaction (tap pig, tap empty cell), HUD overlay, edit mode (move/remove facilities) |
| **Depends On** | 02, 03, 04 |
| **Key Decisions** | `SKTileMapNode` vs manual tile placement (recommendation: `SKTileMapNode` — see Section 4), node pooling for pigs, camera bounds, touch target sizing |
| **Estimated Effort** | 3-4 sessions |
| **Template Outline** | 1. `FarmScene: SKScene` — setup, update loop tied to simulation tick |
| | 2. Terrain rendering: `SKTileMapNode` per biome area, wall tiles, tunnel tiles |
| | 3. Pig nodes: `SKSpriteNode` with `SKAction` animations (walk, eat, sleep, etc.) |
| | 4. Facility nodes: `SKSpriteNode` positioned on grid, interaction point indicators |
| | 5. Camera: `SKCameraNode` with pan (drag), zoom (pinch), bounds clamping |
| | 6. Touch handling: tap-to-select pig, tap-to-place facility, long-press for info |
| | 7. HUD layer: status indicators above pigs (hunger, sleep icons) |
| | 8. Edit mode: facility move/remove with visual feedback |
| | 9. Biome transitions: visual differentiation between areas |
| | 10. Performance: node count management, culling off-screen nodes |

---

#### `07-swiftui-screens.md`

| Field | Value |
|-------|-------|
| **Purpose** | Build all menu/info screens in SwiftUI |
| **Scope** | 8 screens: Shop (4-tab), Pig List (sortable table), Breeding (pair selection + preview), Pig Detail (stats + genotype), Almanac/Journal (Pigdex + Contracts + Stats tabs), Biome Select (modal picker), Adoption Center, Confirmation dialogs |
| **Depends On** | 02, 04 |
| **Key Decisions** | Navigation pattern (sheets vs full-screen covers vs NavigationStack), `SpriteView` ↔ SwiftUI bridge approach (recommendation: SpriteView + sheets — see Section 4), list vs LazyVGrid for pig list |
| **Estimated Effort** | 3-4 sessions |
| **Template Outline** | 1. Navigation architecture: `SpriteView` as root, SwiftUI screens as `.sheet` overlays |
| | 2. Shop screen: 4-tab layout (Facilities, Perks, Upgrades, Adoption), purchase flow, tier gating |
| | 3. Pig List screen: sortable by name/age/rarity, filterable, tap for detail |
| | 4. Breeding screen: pair selection, offspring phenotype preview (Monte Carlo), strategy picker |
| | 5. Pig Detail screen: portrait, needs bars, genotype (if Genetics Lab built), family tree |
| | 6. Almanac/Journal: Pigdex grid (144 phenotypes), contract list, stats summary |
| | 7. Biome Select: modal picker for new room biome assignment |
| | 8. Adoption Center: bloodline pigs with carrier allele hints |
| | 9. Confirmation dialogs: sell pig, remove facility, new game |
| | 10. Shared components: currency display, rarity badges, need bars, pig portrait view |

**Source screens to redesign:**

| Python Screen | Lines | iOS Equivalent |
|--------------|-------|---------------|
| `ui/screens/shop.py` | 753 | `ShopView` — 4-tab shop |
| `ui/screens/breeding.py` | 571 | `BreedingView` — pair selection |
| `ui/screens/pig_list.py` | 229 | `PigListView` — sortable list |
| `ui/screens/pig_detail.py` | 302 | `PigDetailView` — pig stats |
| `ui/screens/almanac.py` | 310 | `AlmanacView` — Pigdex + contracts |
| `ui/screens/biome_select.py` | 179 | `BiomeSelectView` — modal picker |
| `ui/screens/confirm.py` | 69 | `.confirmationDialog` modifier |
| `ui/widgets/pig_sidebar.py` | 173 | Integrated into `PigDetailView` |
| `ui/widgets/status_bar.py` | 127 | `StatusBarView` — HUD overlay |
| `ui/widgets/breeding_program_panel.py` | 280 | Integrated into `BreedingView` |

---

#### `08-persistence-polish.md`

| Field | Value |
|-------|-------|
| **Purpose** | Save/load system, app lifecycle handling, haptics, performance tuning, TestFlight preparation |
| **Scope** | JSON persistence via `FileManager`, auto-save timer, app background/foreground handling, haptic feedback for key actions, performance profiling and optimization, TestFlight build, App Store metadata |
| **Depends On** | All previous documents |
| **Key Decisions** | Save format (JSON file — see Section 4), auto-save frequency, background execution policy, haptic intensity levels |
| **Estimated Effort** | 2-3 sessions |
| **Template Outline** | 1. Save system: `JSONEncoder`/`JSONDecoder` with `GameState` `Codable` |
| | 2. File management: save location (`Documents/`), backup strategy, corruption recovery |
| | 3. Auto-save: timer-based (every 300 ticks), skip if save in progress |
| | 4. App lifecycle: `scenePhase` observation, save on background, pause simulation |
| | 5. Haptics: `UIImpactFeedbackGenerator` for purchases, births, discoveries |
| | 6. Performance: Instruments profiling, tick budget monitoring, node count optimization |
| | 7. TestFlight: build configuration, beta testing setup |
| | 8. App Store: icon, screenshots, description, age rating |

---

## 3. Phased Implementation Plan

### Phase 0 — Foundation (Weeks 1-2)

**Deliverable:** Xcode project with all data models, genetics logic, and passing tests.

| Task | Details |
|------|---------|
| Create Xcode project | Bundle ID, deployment target (iOS 17.0+), folder structure |
| Write CLAUDE.md | Mobile repo conventions, shell commands, git workflow |
| Translate all enums | 21 enums → Swift `enum` with `Codable` conformance |
| Translate all models | 19 Pydantic models → Swift structs/classes |
| Port genetics system | 654 lines: `Genotype`, `Phenotype`, `breed()`, `calculate_rarity()`, mutations |
| Port config constants | All balance constants as Swift namespaces |
| Write genetics tests | Monte Carlo comparison tests to verify fidelity vs Python |

**Exit criteria:** `swift test` passes with genetics producing statistically identical distributions to Python implementation.

---

### Phase 1 — Headless Simulation (Weeks 3-5)

**Deliverable:** Full game simulation running in a test harness with no rendering.

| Task | Details |
|------|---------|
| Port `FarmGrid` | 2D grid, cell types, walkability, multi-area support |
| Port pathfinding | Integrate `GKGridGraph`, verify path equivalence with Python A* |
| Port `SimulationRunner` | Tick orchestration: needs → behavior → breeding → birth → collision |
| Port `FacilityManager` | Facility scoring, path caching, occupancy tracking |
| Port behavior AI | 4-file behavior system: controller, decision, movement, seeking |
| Port breeding/birth | Pair selection, courtship, pregnancy, birth, aging |
| Port economy | Shop, market, contracts, upgrades, currency |
| Port collision | Spatial hash grid, separation forces |
| Integration tests | Run 1000-tick simulation, verify pig population dynamics |

**Exit criteria:** A headless simulation can run 1000 ticks with 20 pigs, producing reasonable behavior (pigs eat when hungry, breed when happy, age and die).

---

### Phase 2 — Sprite Pipeline (Week 3, parallel with Phase 1)

**Deliverable:** Complete set of PNG sprite assets in Xcode asset catalog.

| Task | Details |
|------|---------|
| Build Python export tool | Read pixel grids + palettes → output PNG files |
| Export pig sprites | Normal zoom only: 8 colors × 10 states × 2 directions × 2 ages |
| Export facility sprites | Normal zoom: 17 types |
| Export indicators | Status icons |
| Export portraits | Larger pig art for detail views |
| Build texture atlases | Organize into `SKTextureAtlas` groups |
| Pattern overlay system | Solid, Dutch, Dalmatian pattern application |
| Integration test | Load all atlases in SpriteKit, verify no missing textures |

**Exit criteria:** All sprite assets load in a test SpriteKit scene, all 8 color × 3 pattern variants render correctly.

---

### Phase 3 — Farm Scene (Weeks 6-8)

**Deliverable:** Interactive SpriteKit farm scene with animated pigs, facilities, and camera controls.

| Task | Details |
|------|---------|
| `FarmScene` scaffold | `SKScene` with update loop, camera, touch handling |
| Terrain rendering | `SKTileMapNode` for floor tiles, walls, biome differentiation |
| Pig sprite nodes | Animated `SKSpriteNode` per pig, state-driven animation |
| Facility nodes | Static `SKSpriteNode` per facility, interaction point markers |
| Camera system | Pan (drag), pinch-zoom, bounds clamping, smooth animation |
| Touch interaction | Tap pig → select, tap empty → deselect, long-press → info |
| HUD overlay | Status indicators above pigs, selected pig highlight |
| Edit mode | Move/remove facilities with visual feedback |
| Wire to simulation | `SpriteView` displaying live simulation state |

**Exit criteria:** Farm scene renders a multi-area farm with 20+ animated pigs, facilities, smooth camera, and tap-to-select interaction.

---

### Phase 4 — SwiftUI Screens (Weeks 9-12)

**Deliverable:** All 8 menu/info screens functional and styled.

| Task | Details |
|------|---------|
| Navigation architecture | `SpriteView` root + `.sheet` overlays for menus |
| Shop screen | 4-tab layout, purchase flow, tier gating, refund on remove |
| Pig List screen | Sortable/filterable list, tap for detail |
| Pig Detail screen | Portrait, needs bars, genotype, family tree |
| Breeding screen | Pair selection, offspring preview, strategy picker |
| Almanac/Journal | Pigdex grid (144 phenotypes), contracts, stats |
| Biome Select | Modal picker for room biome |
| Adoption Center | Bloodline pigs, carrier allele display |
| Status bar | Currency, pig count, game time, speed control |
| Confirmation dialogs | Sell, remove, new game confirmations |

**Exit criteria:** All screens navigable, data flows correctly from `GameState`, purchases/sales update state and persist.

---

### Phase 5 — Persistence & Polish (Weeks 13-14)

**Deliverable:** Shippable build ready for TestFlight.

| Task | Details |
|------|---------|
| Save/load system | JSON file via `FileManager`, auto-save every 300 ticks |
| App lifecycle | Save on background, pause simulation, restore on foreground |
| Haptic feedback | Purchases, births, pigdex discoveries, contract completions |
| Performance tuning | Instruments profiling, tick budget monitoring |
| Edge case fixes | Bug fixing, balance adjustments from playtesting |
| TestFlight build | Build configuration, provisioning, beta distribution |

**Exit criteria:** App runs stable 30+ minute sessions, saves/loads correctly, handles background/foreground transitions, ready for beta testing.

---

## 4. Key Architectural Decisions

### Decision 1: GameState as `@Observable class`

**Context:** `GameState` is the root state container, mutated every tick (10 TPS) by the simulation runner. It contains `[UUID: GuineaPig]` dictionaries, facility lists, economy state, and more.

**Options:**
1. **`struct` with value semantics** — Idiomatic Swift, but copying a large state struct 10x/second with 50+ pigs creates unnecessary allocations. Mutating nested structs through dictionaries requires verbose subscript access.
2. **`@Observable class`** — Reference semantics, mutation in place, SwiftUI observation built in.
3. **Actor** — Thread-safe but adds `await` overhead on every access; simulation is single-threaded.

**Recommendation: `@Observable class`.** The simulation tick mutates dozens of fields across multiple pigs per frame. Reference semantics avoid copy overhead and simplify nested mutation. `@Observable` gives SwiftUI automatic view updates when screens read state properties.

---

### Decision 2: GKGridGraph for pathfinding

**Context:** The Python implementation uses a custom A* with Manhattan distance on a 2D grid (up to 96×56 cells). It includes an LRU path cache in `FacilityManager` keyed on `(start, goal, grid_generation)`.

**Options:**
1. **Custom A*** — Full control, direct port of Python implementation.
2. **`GKGridGraph`** — Apple's GameplayKit provides grid-based pathfinding out of the box. Handles node creation, neighbor connectivity, and `findPath(from:to:)`.

**Recommendation: `GKGridGraph`.** Use Apple's implementation first — it handles the grid connectivity and A* internally. Profile before adding an LRU cache; Swift's performance may make caching unnecessary for grids this size. If profiling shows pathfinding is a bottleneck, add caching as an optimization.

---

### Decision 3: Enum + switch for behavior states

**Context:** Pig behavior uses 8 states (IDLE, WANDERING, EATING, DRINKING, PLAYING, SLEEPING, SOCIALIZING, COURTING) with a decision tree that evaluates needs and picks the next state.

**Options:**
1. **`GKStateMachine`** — Apple's GameplayKit state machine. Formal enter/exit/update per state, but requires a class per state (8 classes + boilerplate).
2. **`enum BehaviorState` + `switch`** — Direct port of the Python pattern. All logic in the behavior controller, state is just a value.

**Recommendation: Enum + switch.** The Python implementation works well as a flat decision tree — each tick evaluates needs and picks a state. `GKStateMachine` adds class-per-state ceremony that doesn't buy anything for this codebase's relatively simple state transitions. The `switch` approach is also easier to port file-by-file from Python.

---

### Decision 4: SKTileMapNode for terrain

**Context:** The farm is a 2D grid (up to 96×56 = 5,376 cells) with floor tiles, walls, bedding, and grass. Each biome has distinct visual styling.

**Options:**
1. **Manual `SKSpriteNode` per tile** — Simple but 5,000+ nodes degrades performance.
2. **`SKTileMapNode`** — SpriteKit's built-in tile map. Efficient batched rendering, supports multiple tile groups (biomes), handles large grids well.

**Recommendation: `SKTileMapNode`.** Purpose-built for exactly this use case. One `SKTileMapNode` per biome area (max 8 areas = 8 tile map nodes) keeps the node count manageable. Tile groups define the visual variants (floor, wall, bedding, grass) per biome.

---

### Decision 5: SpriteView + SwiftUI sheets for the bridge

**Context:** The app needs both SpriteKit (farm rendering) and SwiftUI (menu screens). These two frameworks need to coexist.

**Options:**
1. **`SpriteView`** — SwiftUI wrapper for `SKScene`. The farm scene is a SwiftUI view, and menus are presented as `.sheet` overlays.
2. **`SKView` in UIKit** — Embed SpriteKit in a `UIViewController`, present SwiftUI via `UIHostingController`. More control but more glue code.
3. **Full SwiftUI with Canvas** — Use SwiftUI's `Canvas` for rendering instead of SpriteKit. Loses SpriteKit's built-in camera, physics, and sprite management.

**Recommendation: `SpriteView` + SwiftUI sheets.** The simplest bridge. `SpriteView` is the root view, menus are `.sheet` modifiers on the `SpriteView`. The simulation pauses when a sheet is presented (or optionally continues). This avoids UIKit bridging entirely — the entire app is SwiftUI with an embedded SpriteKit scene.

---

### Decision 6: Pre-render 8 base color variants, apply patterns at runtime

**Context:** Pigs have 8 base colors × 3 patterns × 3 intensities × 2 roan states = 144 visual variants, plus animation states and directions.

**Options:**
1. **Pre-render all 144 variants** — Complete texture atlas, no runtime processing. But 144 × ~10 animation states × 2 directions × 2 ages = ~5,760 textures. Large asset size.
2. **Pre-render 8 colors, apply patterns at runtime** — 8 solid-color base sprites, apply Dutch/Dalmatian patterns via shader or compositing. Reduces textures by ~18x.
3. **Runtime palette swap via shader** — Single grayscale sprite, colorize with shader uniforms. Most flexible but adds GPU complexity.

**Recommendation: Pre-render 8 base colors, apply patterns at runtime.** Strike the balance between asset size and runtime complexity. The export tool generates 8 base-color sprite sheets. Pattern overlays (Dutch: white belly/face; Dalmatian: white spots) are applied at runtime via `SKShader` or alpha compositing with a pattern mask. Intensity (chinchilla, himalayan) can be a subtle tint adjustment. This keeps the asset catalog manageable (~640 textures for 8 colors × 10 states × 2 directions × 2 ages × 2 roan) while still achieving visual variety.

---

### Decision 7: JSON file via FileManager for persistence

**Context:** The Python version stores a single JSON blob in SQLite. The game has exactly one save slot.

**Options:**
1. **SQLite** — Direct port of the Python approach. Overkill for a single JSON blob.
2. **SwiftData / Core Data** — Apple's persistence frameworks. Massive overhead for a flat JSON save.
3. **JSON file via `FileManager`** — Write `GameState` as JSON to `Documents/save.json`. Simplest possible approach.
4. **UserDefaults** — Limited to ~1MB, not suitable for large game states.

**Recommendation: JSON file via `FileManager`.** The game has one save slot containing one `GameState`. `JSONEncoder().encode(state)` → write to `Documents/save.json`. `JSONDecoder().decode(data)` → restore. Backup by copying to `save.json.bak` before write. No database overhead, trivially debuggable (open the JSON file), and `Codable` conformance is already required for the data models.

---

## 5. Risk Register

### Risk 1: Performance at Scale (HIGH severity)

**Description:** The Python simulation targets 10 TPS with 50 pigs on a 96×56 grid, achieving <8ms per behavior tick. The iOS version must match or exceed this on mobile hardware.

**Likelihood:** Low — Swift is 10-50x faster than Python for computational workloads. The Python version already runs well, and Swift will have significant headroom.

**Mitigation:**
- Profile with Instruments from Phase 1 (headless simulation) onward
- Set tick budget alerts: warn if any tick exceeds 16ms (one 60fps frame)
- Port the spatial hash grid for O(n×k) collision checks
- `GKGridGraph` pathfinding is C++ under the hood — likely faster than Python A*
- If needed, add path caching (the Python LRU cache pattern is ready to port)

---

### Risk 2: Sprite Pipeline Complexity (MEDIUM severity)

**Description:** Converting 2,200+ lines of Python pixel grid data into SpriteKit-ready PNG textures requires a reliable export tool. Color variants, patterns, and animation frames multiply the output.

**Likelihood:** Medium — the pixel art format is well-structured (2D arrays of palette keys), but the export tool needs to handle transparency, palette mapping, and atlas packing correctly.

**Mitigation:**
- Build the export tool incrementally: single sprite → all frames → all colors → patterns
- Use Python Pillow for PNG generation — proven library for pixel art
- Validate exports visually before moving to the next batch
- Start with Phase 2 early (parallel with Phase 1) to catch issues before they block Phase 3
- Keep the export tool in `tools/` in the Python repo for future art iterations

---

### Risk 3: Swift/SpriteKit Learning Curve (MEDIUM-HIGH severity)

**Description:** The developer(s) may have limited Swift/SpriteKit experience. Architectural mistakes early on compound in later phases.

**Likelihood:** Medium — Swift is a well-documented language, but SpriteKit has nuances (scene lifecycle, node hierarchy, coordinate systems) that take time to internalize.

**Mitigation:**
- Phases ordered to ease learning: pure Swift first (models, genetics) → game logic → rendering → UI
- Phase 0 (data models) is the safest starting point — straightforward struct translations
- Phase 1 (headless simulation) builds Swift fluency before touching SpriteKit
- Each spec document will include Swift code examples and API references
- Consider a small SpriteKit prototype (bouncing sprites, camera) as a warmup exercise

---

### Risk 4: Behavior AI Fidelity (MEDIUM severity)

**Description:** The pig behavior system is 1,267 lines across 4 files with 90+ tuning constants. Subtle porting errors could make pigs behave differently — wrong need priorities, broken commitment system, or pathfinding anomalies.

**Likelihood:** Medium — the logic is complex but deterministic. The main risk is in threshold comparisons, floating-point behavior, and edge cases.

**Mitigation:**
- Port file-by-file, preserving function signatures and constant names
- Write comparison tests: run identical scenarios in Python and Swift, compare pig states after N ticks
- Keep all 90+ behavior constants in a single config namespace (easy to audit against Python)
- Log behavior decisions in debug mode for side-by-side comparison

---

### Risk 5: SwiftUI State Observation During Ticks (LOW-MEDIUM severity)

**Description:** `@Observable` notifies SwiftUI of every property change. If the simulation mutates 50 pigs × 10 properties per tick at 10 TPS, that's 5,000 change notifications per second — potentially causing excessive view updates.

**Likelihood:** Low-Medium — SwiftUI coalesces updates within a run loop cycle, but the sheer volume of changes could still cause frame drops on menu screens.

**Mitigation:**
- The farm scene (`SKScene`) reads state in its `update()` method — not reactive, no observation overhead
- SwiftUI screens (shop, pig list) only display when the farm scene is partially obscured — simulation can pause while sheets are presented
- If needed, use `withObservationTracking` sparingly and batch state reads
- Profile SwiftUI view update frequency with Instruments

---

### Risk 6: Genetics Edge Cases (LOW severity)

**Description:** The genetics system has edge cases: lethal RR rerolling, directional mutations (biome-driven allele bias), and rarity scoring. Misporting these produces subtly wrong phenotype distributions.

**Likelihood:** Low — the genetics code is well-structured and testable in isolation.

**Mitigation:**
- Monte Carlo comparison tests: breed 10,000 pairs in both Python and Swift, compare phenotype distribution histograms
- Port `calculate_target_probability()` (analytical Punnett square) and verify against Monte Carlo
- Test lethal RR rerolling explicitly
- Test directional mutations with known biome inputs

---

## 6. Critical Files Reference

Map of the most important Python source files and what they translate to in the Swift project.

### Core State

| Python File | Lines | Swift Target | Notes |
|-------------|-------|-------------|-------|
| `game/state.py` | 264 | `Models/GameState.swift` | Root `@Observable class`, contains all game data |
| `entities/guinea_pig.py` | 291 | `Models/GuineaPig.swift` | Core entity struct + `Needs`, `Position` |
| `entities/genetics.py` | 654 | `Models/Genetics.swift` | `Genotype`, `Phenotype`, `breed()`, mutations |
| `entities/facilities.py` | 362 | `Models/Facility.swift` | `Facility` struct + `FacilityType` enum (17 cases) |
| `entities/areas.py` | 78 | `Models/FarmArea.swift` | `FarmArea`, `TunnelConnection` |
| `entities/biomes.py` | 185 | `Models/BiomeType.swift` | Biome definitions and properties |
| `entities/bloodlines.py` | 116 | `Models/Bloodline.swift` | Adoption bloodlines with carrier alleles |
| `entities/pigdex.py` | 163 | `Models/Pigdex.swift` | Collection tracker (144 phenotypes) |

### Game Engine

| Python File | Lines | Swift Target | Notes |
|-------------|-------|-------------|-------|
| `game/engine.py` | 122 | `Engine/GameEngine.swift` | `Timer`-based tick loop with speed control |
| `game/world.py` | 496 | `Engine/FarmGrid.swift` | 2D grid, cell management |
| `game/world_pathfinding.py` | 142 | `Engine/Pathfinding.swift` | `GKGridGraph` integration |
| `game/world_tunnels.py` | 181 | `Engine/Tunnels.swift` | Tunnel carving between areas |
| `game/world_areas.py` | 142 | `Engine/AreaManager.swift` | Area creation and management |
| `game/world_expansion.py` | 256 | `Engine/GridExpansion.swift` | Tier-based grid expansion |
| `game/auto_arrange.py` | 787 | `Engine/AutoArrange.swift` | Facility auto-layout algorithm |
| `game/facades.py` | 84 | `Engine/Protocols.swift` | `NeedsContext`, `BreedingContext`, etc. |

### Simulation

| Python File | Lines | Swift Target | Notes |
|-------------|-------|-------------|-------|
| `simulation/runner.py` | 252 | `Simulation/SimulationRunner.swift` | Tick phase orchestration |
| `simulation/behavior_controller.py` | 168 | `Simulation/BehaviorController.swift` | AI coordinator |
| `simulation/behavior_decision.py` | 312 | `Simulation/BehaviorDecision.swift` | Decision tree, need priorities |
| `simulation/behavior_movement.py` | 502 | `Simulation/BehaviorMovement.swift` | Movement, wandering, dodging |
| `simulation/behavior_seeking.py` | 285 | `Simulation/BehaviorSeeking.swift` | Facility scoring, social seeking |
| `simulation/facility_manager.py` | 858 | `Simulation/FacilityManager.swift` | Scoring, caching, occupancy |
| `simulation/collision.py` | 250 | `Simulation/Collision.swift` | Spatial hash grid, separation |
| `simulation/breeding.py` | 458 | `Simulation/Breeding.swift` | Pair selection, courtship |
| `simulation/breeding_program.py` | 388 | `Simulation/BreedingProgram.swift` | Targeted breeding strategies |
| `simulation/birth.py` | 328 | `Simulation/Birth.swift` | Pregnancy, birth, aging |
| `simulation/needs.py` | 227 | `Simulation/NeedsSystem.swift` | Needs decay and recovery |
| `simulation/culling.py` | 206 | `Simulation/Culling.swift` | Surplus management |
| `simulation/auto_resources.py` | 134 | `Simulation/AutoResources.swift` | Drip systems, AoE facilities |
| `simulation/acclimation.py` | 46 | `Simulation/Acclimation.swift` | Biome preference development |

### Economy

| Python File | Lines | Swift Target | Notes |
|-------------|-------|-------------|-------|
| `economy/shop.py` | 441 | `Economy/Shop.swift` | Shop items, purchase/refund logic |
| `economy/market.py` | 174 | `Economy/Market.swift` | Pig selling, value calculation |
| `economy/contracts.py` | 307 | `Economy/Contracts.swift` | Breeding contracts system |
| `economy/upgrades.py` | 264 | `Economy/Upgrades.swift` | 20+ permanent perks |
| `economy/currency.py` | 38 | `Economy/Currency.swift` | Currency formatting |

### Data/Config

| Python File | Lines | Swift Target | Notes |
|-------------|-------|-------------|-------|
| `data/config.py` | 507 | `Config/GameConfig.swift` | All balance constants |
| `data/names.py` | 120 | `Config/PigNames.swift` | Name generation arrays |
| `data/pig_sprites.py` | 469 | *Exported as PNGs* | Normal-zoom pixel art → asset catalog |
| `data/pig_portraits.py` | 246 | *Exported as PNGs* | Portrait pixel art → asset catalog |
| `data/facility_pixels.py` | 670 | *Exported as PNGs* | Facility pixel art → asset catalog |
| `data/sprite_engine.py` | 346 | `tools/export_sprites.py` | Export tool (stays in Python) |

### UI (Rewrite — no direct port)

| Python Screen | Lines | Swift Target | Notes |
|--------------|-------|-------------|-------|
| `ui/screens/main_game.py` | 535 | `Views/ContentView.swift` + `FarmScene.swift` | SpriteKit scene + SwiftUI shell |
| `ui/screens/shop.py` | 753 | `Views/ShopView.swift` | 4-tab SwiftUI shop |
| `ui/screens/breeding.py` | 571 | `Views/BreedingView.swift` | Pair selection + preview |
| `ui/screens/pig_list.py` | 229 | `Views/PigListView.swift` | Sortable pig list |
| `ui/screens/pig_detail.py` | 302 | `Views/PigDetailView.swift` | Individual pig stats |
| `ui/screens/almanac.py` | 310 | `Views/AlmanacView.swift` | Pigdex + contracts + stats |
| `ui/screens/biome_select.py` | 179 | `Views/BiomeSelectView.swift` | Biome picker modal |
| `ui/widgets/farm_view.py` | 565 | `Scene/FarmScene.swift` | SpriteKit `SKScene` |
| `ui/widgets/status_bar.py` | 127 | `Views/StatusBarView.swift` | HUD overlay |

---

## Appendix A: Glossary

| Term | Meaning |
|------|---------|
| **Squeaks** | In-game currency |
| **Pigdex** | Collection tracker for phenotype combinations (like a Pokedex) |
| **Locus** | A genetic position; the game has 6 loci (Extension, Brown, Spotting, Intensity, Roan, Dilution) |
| **Phenotype** | Observable appearance: base color + pattern + intensity + roan |
| **Genotype** | Underlying allele pairs at each locus |
| **Tier** | Farm expansion level (1-5), gates facilities and features |
| **Biome** | Room theme (Meadow, Burrow, Garden, etc.) affecting pig happiness |
| **Bloodline** | Special adoption pig carrying hidden rare alleles |
| **Contract** | NPC order requesting a specific phenotype for bonus currency |
| **Breeding Program** | Automated pairing system with configurable strategy |

## Appendix B: Session Log

Track which spec documents have been written and when.

| Doc | Status | Session Date | Notes |
|-----|--------|-------------|-------|
| 01 - Project Setup | Complete | 2026-02-26 | XcodeGen project, 54 stubs, SwiftLint, CLAUDE.md, CHECKLIST.md |
| 02 - Data Models | Complete | 2026-02-26 | Full Python→Swift translation spec |
| 03 - Sprite Pipeline | Not started | — | — |
| 04 - Game Engine | Not started | — | — |
| 05 - Behavior AI | Not started | — | — |
| 06 - Farm Scene | Not started | — | — |
| 07 - SwiftUI Screens | Not started | — | — |
| 08 - Persistence & Polish | Not started | — | — |
