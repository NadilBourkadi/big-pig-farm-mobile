# Big Pig Farm iOS — Project Checklist

> **Living document.** Update this checklist immediately after completing any task. If it's not checked off here, it's not done.

---

## Spec Documents

- [x] 01 — Project Setup → [`docs/specs/01-project-setup.md`](specs/01-project-setup.md)
- [x] 02 — Data Models → [`docs/specs/02-data-models.md`](specs/02-data-models.md)
- [x] 03 — Sprite Pipeline → [`docs/specs/03-sprite-pipeline.md`](specs/03-sprite-pipeline.md)
- [x] 04 — Game Engine → [`docs/specs/04-game-engine.md`](specs/04-game-engine.md)
- [x] 05 — Behavior AI → [`docs/specs/05-behavior-ai.md`](specs/05-behavior-ai.md)
- [x] 06 — Farm Scene → [`docs/specs/06-farm-scene.md`](specs/06-farm-scene.md)
- [x] 07 — SwiftUI Screens → [`docs/specs/07-swiftui-screens.md`](specs/07-swiftui-screens.md)
- [x] 08 — Persistence & Polish → [`docs/specs/08-persistence-polish.md`](specs/08-persistence-polish.md)

---

## Investigation / Open Questions

- [ ] Profile `GKGridGraph` vs custom A* on 96x56 grid (during Phase 1)
- [x] Determine `SKShader` vs alpha compositing for pattern overlays (during Phase 2)
- [x] Test `SpriteView` performance with 50+ animated nodes (during Phase 3)
- [ ] Evaluate `CADisplayLink` vs `Timer` for tick loop precision (during Phase 1)
- [ ] Measure JSON save/load performance with 200+ pigs (during Phase 5)
- [ ] Test Swift 6 strict concurrency with SpriteKit scene updates (during Phase 3)

---

## Implementation Tasks

### Phase 0 — Foundation (Weeks 1–2)

- [x] Create Xcode project scaffolding (XcodeGen + folder structure)
- [x] Translate all 21 enums to Swift
- [x] Translate all 19 Pydantic models to Swift structs
- [x] Port genetics system (`breed()`, mutations, rarity calculation)
- [x] Write genetics comparison tests (Python vs Swift output parity)
- [x] Port `GameConfig` constants (all 90+ tuning values)
- [x] Port `GameConfig.Behavior` constants (~50 behavior AI values)
- [x] Port `GameConfig.Tiers` data tables (TierUpgrade + RoomCost)
- [x] Port `PigNames` name generation

### Phase 1 — Headless Simulation (Weeks 3–5)

- [x] Implement `GameState` observable container
- [x] Implement context protocols (`NeedsContext`, `BreedingContext`, `BirthContext`, `CullingContext`)
- [x] Introduce Economy context protocols (`CurrencyContext`, `AdoptionContext`, `MarketContext`, `UpgradesContext`, `ShopContext`, `ContractGeneratorContext`) — bead d43
- [x] Implement `GameEngine` tick loop
- [x] Implement `FarmGrid` with cell types
- [x] Implement `Pathfinding` (GKGridGraph integration)
- [x] Implement `Tunnels` and `AreaManager`
- [x] Implement `GridExpansion` tier system
- [x] Implement `AutoArrange` zone-based layout
- [x] Implement `NeedsSystem` (decay/recovery)
- [x] Implement `SimulationRunner` tick orchestration
- [x] Implement `BehaviorController` + decision tree
- [x] Implement `BehaviorMovement` + seeking
- [x] Implement `Collision` spatial hash (`SpatialGrid` + `CollisionHandler`)
- [x] Implement `Breeding` + `Birth` systems
- [x] Implement `Culling` surplus management
- [x] Implement `Acclimation` biome adoption
- [x] Implement `AutoResources` drip/AoE/veggie systems
- [x] Implement `BreedingProgram` scoring and carrier-aware filter
- [x] Implement `Shop`, `Market`, `Contracts`, `Upgrades`, `Currency`
- [x] Implement `FacilityManager` scoring
- [x] Write headless simulation integration tests

### Phase 2 — Sprite Pipeline (Week 3, parallel)

- [x] Create Python sprite export tool (PNG from half-block data)
- [x] Generate 8 base color variant PNGs
- [x] Export indicator sprite PNGs (12 image sets)
- [x] Export portrait sprite PNGs (144 image sets)
- [x] Export terrain tile PNGs (24 image sets)
- [x] Generate pattern mask PNGs (6 image sets)
- [x] Create sprite atlas for Xcode (Assets.xcassets)
- [x] Create facility sprite assets
- [x] Implement `SpriteAssets` loading API
- [x] Implement `AnimationData` timing constants
- [x] Implement `PigPalettes` color dictionaries
- [x] Implement `SpriteFurMaps` coordinate data
- [x] Implement runtime pattern overlay rendering

### Phase 3 — Farm Scene (Weeks 6–8)

- [x] Implement `FarmScene` (SKScene + tile map)
- [x] Implement `PigNode` (animated sprite)
- [x] Implement `FacilityNode`
- [x] Implement `CameraController` (pan/zoom/bounds)
- [x] Wire `SpriteView` into `ContentView`
- [x] Implement touch handling (tap pig, place facility)
- [x] Implement edit mode action panel (Move/Remove/Auto-Arrange) — bead v85
- [x] Performance test with 50+ pigs

### Phase 4 — SwiftUI Screens (Weeks 9–12)

- [x] Implement `StatusBarView` (HUD overlay)
- [x] Implement `ShopView` (4-tab shop)
- [x] Implement `PigListView` (sortable list)
- [x] Implement `PigDetailView` (stats + genetics)
- [x] Implement `BreedingView` (pair selection)
- [x] Implement `AlmanacView` (Pigdex + contracts)
- [x] Implement `BiomeSelectView` (biome picker)
- [x] Implement `AdoptionView` (bloodline adoption)
- [x] Implement `UIComponents` + `DisplayFormatting` (currency, badges, bars, formatting)

### Phase 5 — Persistence & Polish (Weeks 13–14)

- [x] Implement `SaveManager` (JSON save/load)
- [x] Implement `HapticManager` (7 event methods + 9 integration call sites)
- [x] Implement app lifecycle save (background/terminate)
- [x] Implement auto-save (every 300 ticks)
- [x] Add app icon
- [ ] Polish animations and transitions
- [x] Add manual Refill All HUD button for food/water facilities (bead 4r8)
- [x] Show refill cost on disabled button / distinguish "all full" from "can't afford" (bead 86k)
- [x] TestFlight build and testing (code-complete: PrivacyInfo, metadata, 1.0.0, 1187 tests passing, clean build; upload gated on paid Apple Developer account)
- [x] Extract shared `HUDButton` component from duplicated toolbar/panel buttons (bead 42b)
- [x] Extract shared `InfoRow` component (duplicated in PigDetailView/AlmanacView with inconsistent fonts) (bead 1h1)
- [x] Extract shared `StatusBadge` component from duplicated pill badges (bead 9r3)
- [x] Fix gender display inconsistency: AdoptionView uses ♂/♀ in blue/pink matching PigListView (bead dfe)
- [x] Replace AdoptionView inline detail panel with sheet presentation (bead 5fj)
- [x] Fix inert Pigdex milestone "READY" label — make tappable with reward claim (bead a8c)
- [x] Split oversized files using +Extension pattern: Breeding, BreedingProgram, Birth, FarmScene (bead wqr)
- [x] Fix cryptic "TN" tier label — display "Tier N" in status HUD (bead 88v)
- [x] Remove redundant speed indicator from StatusInfoRow — consolidated into StatusToolbar (bead b3s)
- [x] Fix horizontally-stretched facility sprites — aspectFit sizing in FacilityNode (bead e8l)
- [x] Render tunnel mouth walls with area biome texture instead of tunnel texture (bead 0q2)
- [x] Centralize gender display logic with `displaySymbol`/`displayColor` on `Gender` enum (bead 4bj)
- [x] Implement `NotificationManager` — toast queue, burst throttling, offline suppression (bead c2o)
- [x] Clarify "LOW POP" HUD warning — display contextual threshold text with accessibility label (bead z5x)

---

## Debug & Developer Tools

- [x] Implement `DebugLogger` — SQLite storage, in-memory buffer, async queries, log rotation (bead rscr)
- [x] Implement `DebugServer` — NWListener HTTP server on port 8361, `#if DEBUG` (bead rscr)
- [x] Instrument simulation subsystems — behavior, breeding, birth, needs, culling, economy (bead rscr)
