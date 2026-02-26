# Big Pig Farm iOS — Project Checklist

> **Living document.** Update this checklist immediately after completing any task. If it's not checked off here, it's not done.

---

## Spec Documents

- [x] 01 — Project Setup → [`docs/specs/01-project-setup.md`](specs/01-project-setup.md)
- [ ] 02 — Data Models
- [ ] 03 — Sprite Pipeline
- [ ] 04 — Game Engine
- [ ] 05 — Behavior AI
- [ ] 06 — Farm Scene
- [ ] 07 — SwiftUI Screens
- [ ] 08 — Persistence & Polish

---

## Investigation / Open Questions

- [ ] Profile `GKGridGraph` vs custom A* on 96x56 grid (during Phase 1)
- [ ] Determine `SKShader` vs alpha compositing for pattern overlays (during Phase 2)
- [ ] Test `SpriteView` performance with 50+ animated nodes (during Phase 3)
- [ ] Evaluate `CADisplayLink` vs `Timer` for tick loop precision (during Phase 1)
- [ ] Measure JSON save/load performance with 200+ pigs (during Phase 5)
- [ ] Test Swift 6 strict concurrency with SpriteKit scene updates (during Phase 3)

---

## Implementation Tasks

### Phase 0 — Foundation (Weeks 1–2)

- [x] Create Xcode project scaffolding (XcodeGen + folder structure)
- [ ] Translate all 21 enums to Swift
- [ ] Translate all 19 Pydantic models to Swift structs
- [ ] Port genetics system (`breed()`, mutations, rarity calculation)
- [ ] Write genetics comparison tests (Python vs Swift output parity)
- [ ] Port `GameConfig` constants (all 90+ tuning values)
- [ ] Port `PigNames` name generation

### Phase 1 — Headless Simulation (Weeks 3–5)

- [ ] Implement `GameState` observable container
- [ ] Implement `GameEngine` tick loop
- [ ] Implement `FarmGrid` with cell types
- [ ] Implement `Pathfinding` (GKGridGraph integration)
- [ ] Implement `Tunnels` and `AreaManager`
- [ ] Implement `GridExpansion` tier system
- [ ] Implement `NeedsSystem` (decay/recovery)
- [ ] Implement `SimulationRunner` tick orchestration
- [ ] Implement `BehaviorController` + decision tree
- [ ] Implement `BehaviorMovement` + seeking
- [ ] Implement `Collision` spatial hash
- [ ] Implement `Breeding` + `Birth` systems
- [ ] Implement `Shop`, `Market`, `Contracts`, `Upgrades`
- [ ] Implement `FacilityManager` scoring
- [ ] Write headless simulation integration tests

### Phase 2 — Sprite Pipeline (Week 3, parallel)

- [ ] Create Python sprite export tool (PNG from half-block data)
- [ ] Generate 8 base color variant PNGs
- [ ] Create sprite atlas for Xcode (Assets.xcassets)
- [ ] Implement runtime pattern overlay rendering
- [ ] Create facility sprite assets

### Phase 3 — Farm Scene (Weeks 6–8)

- [ ] Implement `FarmScene` (SKScene + tile map)
- [ ] Implement `PigNode` (animated sprite)
- [ ] Implement `FacilityNode`
- [ ] Implement `CameraController` (pan/zoom/bounds)
- [ ] Wire `SpriteView` into `ContentView`
- [ ] Implement touch handling (tap pig, place facility)
- [ ] Performance test with 50+ pigs

### Phase 4 — SwiftUI Screens (Weeks 9–12)

- [ ] Implement `StatusBarView` (HUD overlay)
- [ ] Implement `ShopView` (4-tab shop)
- [ ] Implement `PigListView` (sortable list)
- [ ] Implement `PigDetailView` (stats + genetics)
- [ ] Implement `BreedingView` (pair selection)
- [ ] Implement `AlmanacView` (Pigdex + contracts)
- [ ] Implement `BiomeSelectView` (biome picker)
- [ ] Implement `AdoptionView` (bloodline adoption)
- [ ] Implement `SharedComponents` (currency, badges, bars)

### Phase 5 — Persistence & Polish (Weeks 13–14)

- [ ] Implement `SaveManager` (JSON save/load)
- [ ] Implement app lifecycle save (background/terminate)
- [ ] Implement auto-save (every 300 ticks)
- [ ] Add app icon
- [ ] Polish animations and transitions
- [ ] TestFlight build and testing
