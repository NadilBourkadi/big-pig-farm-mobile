# Spec 08 -- Persistence & Polish

> **Status:** Complete
> **Date:** 2026-02-27
> **Depends on:** All previous specs (01-07)
> **Blocks:** None (final spec)

---

## 1. Overview

This document specifies the persistence layer, app lifecycle management, haptic feedback, and TestFlight preparation for the iOS port. It is the final spec in the series and ties together all previous systems into a shippable application.

The Python source uses `SaveManagerV2` to serialize the entire `GameState` as a single JSON blob stored in SQLite (`game/save_manager_v2.py`). The iOS port simplifies this to a plain JSON file written via `FileManager`, as recommended by ROADMAP Decision 7. The game has exactly one save slot -- there is no need for a database layer.

### Scope

**In scope:**
- `SaveManager` -- JSON encode/decode via `Codable`, file I/O via `FileManager`, backup and corruption recovery
- `GameState` serialization via `CodableSnapshot` value type and `encodeToJSON()` / `fromSnapshot()` helpers -- avoids Swift 6 actor isolation issues with `@Observable`
- Save file format -- JSON structure, schema versioning, forward-compatibility
- Auto-save -- 300-tick cadence in `SimulationRunner`, background write, skip-if-in-progress
- App lifecycle -- `scenePhase` observation, save on background, pause on inactive, restore on active
- `BigPigFarmApp` entry point -- bootstraps state, engine, simulation runner, and new game setup
- Save migration -- post-load validation: area relayout, room resize, orphan pig clamping
- Haptic feedback -- `UIImpactFeedbackGenerator` for key game events
- App icon and launch screen -- asset catalog entries
- Performance profiling -- Instruments strategy, tick budget, JSON encode benchmarking
- TestFlight preparation -- build config, provisioning, Info.plist

**Out of scope:**
- Data model definitions (Doc 02)
- Game engine tick loop and simulation logic (Docs 04-05)
- SpriteKit rendering (Doc 06)
- SwiftUI screen implementations (Doc 07)

### Deliverable Summary

| Category | Files | Estimated Lines |
|----------|-------|----------------|
| SaveManager | `Engine/SaveManager.swift` | ~200 |
| GameState Codable | `Engine/GameState+Codable.swift` | ~150 |
| SaveMigration | `Engine/SaveMigration.swift` | ~100 |
| BigPigFarmApp | `BigPigFarmApp.swift` | ~120 |
| HapticManager | `Engine/HapticManager.swift` | ~60 |
| Tests | `BigPigFarmTests/SaveManagerTests.swift` | ~250 |
| **Total** | **6 files** | **~850** |

### Source File Mapping

| Python Source | Lines | Swift Target | Notes |
|---------------|-------|-------------|-------|
| `game/save_manager_v2.py` | 175 | `Engine/SaveManager.swift` | SQLite wrapper becomes plain JSON file I/O |
| `game/state.py` | 265 | `Engine/GameState+Codable.swift` | Pydantic auto-serialization becomes `CodableSnapshot` + `encodeToJSON()` |
| `game/world_migration.py` | 261 | `Engine/SaveMigration.swift` | Layout migration and orphan pig clamping |
| `app.py` | 194 | `BigPigFarmApp.swift` | Textual `App` becomes SwiftUI `App` with lifecycle |
| `simulation/runner.py` (lines 225-253) | 28 | `Simulation/SimulationRunner.swift` (delta) | Auto-save integration point |
| `tests/test_save_manager_v2.py` | 182 | `BigPigFarmTests/SaveManagerTests.swift` | Roundtrip and corruption tests |

---

## 2. SaveManager

**Maps from:** `game/save_manager_v2.py` `SaveManagerV2` + `CombinedSaveManager` (175 lines)
**Swift file:** `Engine/SaveManager.swift`

### Architecture Decision

Per ROADMAP Decision 7, the iOS port uses a plain JSON file via `FileManager` instead of SQLite. The Python version wraps a single JSON blob in SQLite (`game_state_v2` table with `id=1`), which is overkill for a single-save-slot game. On iOS, we write directly to `Documents/save.json` using `JSONEncoder`.

**Rationale:**
- One save slot containing one `GameState` -- no relational queries needed
- `JSONEncoder`/`JSONDecoder` handle all serialization via `Codable` conformance
- Trivially debuggable -- developers can inspect the JSON file directly
- Backup is a simple file copy (`save.json` to `save.json.bak`)
- No SQLite dependency to manage

### Type Signature

```swift
import Foundation

/// Handles saving and loading game state as a JSON file.
///
/// Maps from: `game/save_manager_v2.py` `SaveManagerV2`
/// The Python version stores JSON in SQLite; the iOS port writes
/// directly to a JSON file via `FileManager`.
struct SaveManager: Sendable {
    // MARK: - Constants

    /// Schema version for forward-compatibility detection.
    /// Increment when the save format changes in a breaking way.
    static let schemaVersion: Int = 1

    /// Default save file name.
    static let saveFileName = "save.json"

    /// Backup file name.
    static let backupFileName = "save.json.bak"

    // MARK: - File Paths

    /// The base directory for save files. Defaults to the app's Documents
    /// directory, which is backed up by iCloud and persists across app updates.
    /// Override in tests to use a temporary directory.
    let baseDirectoryURL: URL

    init(baseDirectoryURL: URL? = nil) {
        self.baseDirectoryURL = baseDirectoryURL ??
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Full path to the primary save file.
    var saveFileURL: URL {
        baseDirectoryURL.appendingPathComponent(Self.saveFileName)
    }

    /// Full path to the backup save file.
    var backupFileURL: URL {
        baseDirectoryURL.appendingPathComponent(Self.backupFileName)
    }

    // MARK: - Save

    /// Save game state to disk as JSON.
    ///
    /// Pipeline:
    /// 1. Call `state.encodeToJSON()` to get pre-encoded `Data`
    /// 2. If a previous save exists, copy it to `.bak` as backup
    /// 3. Write the new JSON data atomically
    ///
    /// - Parameter state: The game state to persist.
    /// - Throws: Encoding or file I/O errors.
    @MainActor
    func save(_ state: GameState) throws {
        let data = try state.encodeToJSON()

        // Create backup before overwriting
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: saveFileURL.path) {
            // Remove old backup first (copy won't overwrite)
            try? fileManager.removeItem(at: backupFileURL)
            try? fileManager.copyItem(at: saveFileURL, to: backupFileURL)
        }

        // Atomic write: writes to a temp file then renames, preventing
        // partial writes if the app is killed mid-save.
        try data.write(to: saveFileURL, options: .atomic)
    }

    /// Save a pre-encoded JSON blob to disk.
    ///
    /// Used by the auto-save system: `GameState` is encoded on the main
    /// actor, then the resulting `Data` is passed to a background Task
    /// for file I/O.
    ///
    /// - Parameter data: Pre-encoded JSON data (a `SaveEnvelope`).
    /// - Throws: File I/O errors.
    func saveData(_ data: Data) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: saveFileURL.path) {
            try? fileManager.removeItem(at: backupFileURL)
            try? fileManager.copyItem(at: saveFileURL, to: backupFileURL)
        }
        try data.write(to: saveFileURL, options: .atomic)
    }

    // MARK: - Load

    /// Load game state from disk.
    ///
    /// Pipeline:
    /// 1. Read JSON data from the save file
    /// 2. Decode `SaveEnvelope` to extract schema version and state
    /// 3. Run post-load migration (Section 8)
    /// 4. Return the restored `GameState`
    ///
    /// Returns `nil` if no save file exists. Falls back to the backup
    /// file if the primary file is corrupted.
    ///
    /// - Returns: The loaded game state, or `nil` if no save exists.
    func load() -> GameState? {
        // Try primary save file first
        if let state = loadFromURL(saveFileURL) {
            return state
        }
        // Fall back to backup if primary is missing or corrupted
        if let state = loadFromURL(backupFileURL) {
            return state
        }
        return nil
    }

    /// Attempt to load and decode a save file at the given URL.
    private func loadFromURL(_ url: URL) -> GameState? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(SaveEnvelope.self, from: data)
            let state = GameState.fromSnapshot(envelope.snapshot)
            SaveMigration.migrateIfNeeded(state)
            return state
        } catch {
            // Log but don't crash -- corrupted saves should not prevent
            // the player from starting a new game.
            print("SaveManager: failed to load \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    // MARK: - Query

    /// Check whether a save file exists.
    func hasSave() -> Bool {
        FileManager.default.fileExists(atPath: saveFileURL.path)
    }

    // MARK: - Delete

    /// Delete both the primary save and backup files.
    func deleteSave() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: saveFileURL)
        try? fileManager.removeItem(at: backupFileURL)
    }
}
```

### SaveEnvelope

The save file wraps `CodableSnapshot` in a versioned envelope so future updates can detect old formats and migrate them. See Section 3 for the full `SaveEnvelope` and `CodableSnapshot` definitions.

```swift
/// Versioned wrapper around the save payload.
///
/// The envelope lives at the top level of the JSON file:
/// ```json
/// {
///   "schema_version": 1,
///   "state": { ... }
/// }
/// ```
struct SaveEnvelope: Codable, Sendable {
    let schemaVersion: Int
    let snapshot: CodableSnapshot

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case snapshot = "state"  // JSON key remains "state" for compatibility
    }
}
```

### Error Handling Strategy

Save failures are logged but never crash the app. The `save()` method is marked `throws` so callers can handle errors, but in practice:

- **Auto-save failures** are silently logged. The previous save remains intact because we write atomically.
- **Lifecycle save failures** (background/terminate) are logged. The auto-save or backup file provides a recent fallback.
- **Load failures** fall through to the backup file, then to `nil` (which triggers a new game).

This matches the Python implementation where `load()` catches all exceptions and returns `None`.

### Documents Directory Choice

The save file is stored in the app's `Documents/` directory rather than `Application Support/` because:
- `Documents/` is backed up by iCloud by default, preserving saves across device migrations
- It is the standard location for user-generated data on iOS
- It persists across app updates

If a future version needs to opt out of iCloud backup (e.g., save file grows very large), add the `isExcludedFromBackup` resource value to the file URL.

---

## 3. GameState Codable Conformance

**Maps from:** `game/state.py` `GameState(BaseModel)` -- Pydantic auto-serialization
**Swift file:** `Engine/GameState+Codable.swift`

### Why Not Direct Codable Conformance

`GameState` is an `@Observable class` (per ROADMAP Decision 1 and Doc 04 Section 2). Two problems prevent standard `Codable` conformance:

1. The `@Observable` macro synthesizes backing storage properties that interfere with the compiler's auto-generated `Codable` conformance.
2. Under Swift 6 strict concurrency (`complete` mode), `GameState` properties are `@MainActor`-isolated. The `Encodable` protocol requires a `nonisolated encode(to:)` method, which cannot access isolated properties — the compiler rejects it.

Therefore, `GameState` does **not** conform to `Codable`. Instead, serialization uses an intermediate `CodableSnapshot` value type (a plain `Sendable` struct with auto-synthesized `Codable`) and two helper methods: `encodeToJSON()` and `fromSnapshot()`.

### CodingKeys

The Python `GameState` uses `snake_case` field names. The Swift `CodingKeys` on `CodableSnapshot` map `camelCase` Swift properties to `snake_case` JSON keys for compatibility. See the `CodableSnapshot` definition in the Encoding section above for the full `CodingKeys` enum.

### Encoding

`GameState` is `@MainActor`-isolated (via `@Observable`). Under Swift 6 strict concurrency (`complete` mode), a `nonisolated` function cannot access `@MainActor`-isolated stored properties -- the compiler rejects it even if the call site is always on the main actor.

**Solution:** Instead of conforming to `Encodable` directly (which requires a `nonisolated encode(to:)` method), provide a `@MainActor` helper that callers use explicitly. The `Codable` conformance is achieved through `Decodable` only; encoding goes through the helper:

```swift
extension GameState {
    /// Encode the game state to JSON data.
    ///
    /// This is a @MainActor method (not the Encodable protocol method) because
    /// GameState is @MainActor-isolated and Swift 6 strict concurrency prevents
    /// nonisolated access to isolated properties. Callers use this directly
    /// instead of JSONEncoder.encode(self).
    @MainActor
    func encodeToJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        // Build a CodableSnapshot that captures all persistent fields.
        // This is a plain Sendable struct with auto-synthesized Codable.
        let snapshot = CodableSnapshot(
            guineaPigs: guineaPigs,
            facilities: facilities,
            farm: farm,
            money: money,
            gameTime: gameTime,
            speed: speed,
            isPaused: isPaused,
            sessionStart: sessionStart,
            lastSave: lastSave,
            events: events,
            maxEvents: maxEvents,
            pigdex: pigdex,
            contractBoard: contractBoard,
            breedingProgram: breedingProgram,
            breedingPair: breedingPair,
            socialAffinity: socialAffinity,
            farmTier: farmTier,
            purchasedUpgrades: purchasedUpgrades,
            totalPigsBorn: totalPigsBorn,
            totalPigsSold: totalPigsSold,
            totalEarnings: totalEarnings
        )
        let envelope = SaveEnvelope(
            schemaVersion: SaveManager.schemaVersion,
            snapshot: snapshot
        )
        return try encoder.encode(envelope)
    }
}
```

### CodableSnapshot

A plain `Sendable` struct that mirrors `GameState`'s persistent fields. Because it is a value type with no `@Observable` macro, the compiler auto-synthesizes `Codable`:

```swift
/// Immutable snapshot of GameState's persistent fields for serialization.
///
/// GameState is an @Observable class whose properties are @MainActor-isolated.
/// This snapshot struct captures all persistent fields as plain values,
/// enabling auto-synthesized Codable without actor isolation issues.
struct CodableSnapshot: Codable, Sendable {
    let guineaPigs: [UUID: GuineaPig]
    let facilities: [UUID: Facility]
    let farm: FarmGrid
    let money: Int
    let gameTime: GameTime
    let speed: GameSpeed
    let isPaused: Bool
    let sessionStart: Date
    let lastSave: Date?
    let events: [EventLog]
    let maxEvents: Int
    let pigdex: Pigdex
    let contractBoard: ContractBoard
    let breedingProgram: BreedingProgram
    let breedingPair: BreedingPair?
    let socialAffinity: [String: Int]
    let farmTier: Int
    let purchasedUpgrades: Set<String>
    let totalPigsBorn: Int
    let totalPigsSold: Int
    let totalEarnings: Int

    enum CodingKeys: String, CodingKey {
        case guineaPigs = "guinea_pigs"
        case facilities
        case farm
        case money
        case gameTime = "game_time"
        case speed
        case isPaused = "is_paused"
        case sessionStart = "session_start"
        case lastSave = "last_save"
        case events
        case maxEvents = "max_events"
        case pigdex
        case contractBoard = "contract_board"
        case breedingProgram = "breeding_program"
        case breedingPair = "breeding_pair"
        case socialAffinity = "social_affinity"
        case farmTier = "farm_tier"
        case purchasedUpgrades = "purchased_upgrades"
        case totalPigsBorn = "total_pigs_born"
        case totalPigsSold = "total_pigs_sold"
        case totalEarnings = "total_earnings"
    }
}
```

**Note:** `SaveEnvelope` wraps `CodableSnapshot` (not `GameState` directly):

```swift
struct SaveEnvelope: Codable, Sendable {
    let schemaVersion: Int
    let snapshot: CodableSnapshot

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case snapshot = "state"  // JSON key remains "state" for compatibility
    }
}
```

### Decoding (Restoring GameState from CodableSnapshot)

Decoding goes through `CodableSnapshot` (which has auto-synthesized `Decodable`), then restores a `GameState` from the snapshot:

```swift
extension GameState {
    /// Restore a GameState from a decoded CodableSnapshot.
    ///
    /// This is used by SaveManager after decoding a SaveEnvelope.
    /// Transient caches are left as nil and rebuilt lazily on first
    /// access (the existing cache properties in Doc 04 Section 2 handle this).
    @MainActor
    static func fromSnapshot(_ snapshot: CodableSnapshot) -> GameState {
        let state = GameState()
        state.guineaPigs = snapshot.guineaPigs
        state.facilities = snapshot.facilities
        state.farm = snapshot.farm
        state.money = snapshot.money
        state.gameTime = snapshot.gameTime
        state.speed = snapshot.speed
        state.isPaused = snapshot.isPaused
        state.sessionStart = snapshot.sessionStart
        state.lastSave = snapshot.lastSave
        state.events = snapshot.events
        // maxEvents is a let constant -- use the default (100)
        state.pigdex = snapshot.pigdex
        state.contractBoard = snapshot.contractBoard
        state.breedingProgram = snapshot.breedingProgram
        state.breedingPair = snapshot.breedingPair
        state.socialAffinity = snapshot.socialAffinity
        state.farmTier = snapshot.farmTier
        state.purchasedUpgrades = snapshot.purchasedUpgrades
        state.totalPigsBorn = snapshot.totalPigsBorn
        state.totalPigsSold = snapshot.totalPigsSold
        state.totalEarnings = snapshot.totalEarnings

        // Transient caches are nil by default and rebuild lazily
        // FarmGrid rebuilds its own caches in init(from:) (Doc 04 Section 7)
        return state
    }
}
```

The `SaveManager.loadFromURL()` call site becomes:

```swift
let envelope = try decoder.decode(SaveEnvelope.self, from: data)
let state = GameState.fromSnapshot(envelope.snapshot)
SaveMigration.migrateIfNeeded(state)
return state
```

### Key Design Notes

1. **`decodeIfPresent` with defaults on CodableSnapshot:** `CodableSnapshot` uses non-optional types with `Codable` auto-synthesis. For forward compatibility with older saves missing new fields, use a custom `init(from:)` on `CodableSnapshot` with `decodeIfPresent` defaults when new fields are added in future versions.

2. **Transient caches excluded:** `pigsListCache`, `facilitiesListCache`, and `facilitiesByTypeCache` are not part of `CodableSnapshot`. They are rebuilt lazily on first access, as specified in Doc 04 Section 2.

3. **No `nonisolated` encoding hack:** The `CodableSnapshot` approach avoids the Swift 6 actor isolation problem entirely. `GameState` never conforms to `Encodable` -- instead, the `@MainActor` method `encodeToJSON()` reads isolated properties and produces a `CodableSnapshot`, which is a plain `Sendable` struct with auto-synthesized `Codable`.

4. **`FarmGrid` cache rebuild:** `FarmGrid.init(from:)` already calls `rebuildCaches()` to restore transient lookups (`areaLookup`, `biomeAreaCache`, `walkableGraph`), as specified in Doc 04 Section 7.

---

## 4. Save File Format

### JSON Structure

The save file is a single JSON object with a versioned envelope:

```json
{
  "schema_version": 1,
  "state": {
    "guinea_pigs": {
      "550e8400-e29b-41d4-a716-446655440000": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "name": "Patches",
        "gender": "female",
        "position": { "x": 12.5, "y": 8.3 },
        "needs": { "hunger": 75.0, "thirst": 80.0, ... },
        "genotype": { ... },
        "phenotype": { ... },
        ...
      }
    },
    "facilities": { ... },
    "farm": {
      "width": 24, "height": 14, "tier": 1,
      "cells": [ [...], [...] ],
      "areas": [ ... ],
      "tunnels": [ ... ]
    },
    "money": 500,
    "game_time": { "day": 3, "hour": 14, "minute": 30, ... },
    "speed": "normal",
    "farm_tier": 1,
    ...
  }
}
```

### Schema Versioning

The `schema_version` field at the envelope level allows future updates to detect and migrate old save formats. The migration strategy is:

1. Decode the envelope to read `schemaVersion`
2. If `schemaVersion < SaveManager.schemaVersion`, run version-specific migration logic
3. If `schemaVersion > SaveManager.schemaVersion`, the save was created by a newer app version -- load it anyway (best effort), relying on `decodeIfPresent` defaults for unknown fields

For v1 (the initial iOS release), no migration is needed. Future spec addenda will define migration functions as `schemaVersion` increments.

### Expected File Size

Based on the Python codebase:
- Empty state: ~2 KB
- 20 pigs, 10 facilities, 1 area: ~15-25 KB
- 50 pigs, 30 facilities, 4 areas, full pigdex: ~80-120 KB
- Worst case (200 pigs, 8 areas, full grid): ~500 KB

These sizes are well within iOS memory and `FileManager` write performance. The CHECKLIST includes a Phase 5 investigation item to benchmark JSON save/load with 200+ pigs.

### Date Encoding

All `Date` fields use ISO 8601 encoding (`.iso8601` strategy on both encoder and decoder). This produces human-readable timestamps in the JSON file and avoids platform-specific `timeIntervalSinceReferenceDate` values.

---

## 5. Auto-Save

**Maps from:** `simulation/runner.py` `SimulationRunner._background_save()` (lines 225-253)
**Swift integration point:** `Simulation/SimulationRunner.swift` (delta to Doc 05 Section 14)

### Auto-Save Cadence

The simulation auto-saves every 300 ticks, which at the base 10 TPS rate equals approximately 30 seconds of real time. This matches the Python implementation exactly.

The counter is maintained in `SimulationRunner` as specified in Doc 04 Section 19:

```swift
// Already specified in SimulationRunner (Doc 04):
private var saveCounter: Int = 0

// Phase 13 of the tick method:
saveCounter += 1
if saveCounter >= 300 {
    saveCounter = 0
    backgroundSave()
}
```

### Background Save Strategy

The Python implementation serializes state on the main thread (via `model_dump_json()`), then writes the resulting blob to disk on a background daemon thread. This is critical -- serialization must happen synchronously within the tick to capture a consistent snapshot, but the disk I/O can be offloaded.

The iOS port follows the same pattern using Swift concurrency:

```swift
/// Reference to SaveManager for auto-save and lifecycle saves.
/// Injected at initialization (Section 7).
private let saveManager: SaveManager

/// Tracks whether a background save is currently in progress.
/// Prevents overlapping saves from queueing up.
private var isSaving: Bool = false

/// Serialize state on the main actor, write to disk on a background Task.
///
/// Maps from: `simulation/runner.py` `_background_save()`
///
/// Skips if a previous save is still in progress. Serialization happens
/// synchronously within `tick()` on the main actor -- no state mutations
/// can occur between the start and end of encoding.
@MainActor
private func backgroundSave() {
    guard !isSaving else {
        // Previous save still in progress -- skip this cycle.
        // The Python version logs a warning here; we silently skip.
        return
    }

    do {
        // encodeToJSON() runs on @MainActor, capturing a consistent snapshot
        let data = try state.encodeToJSON()

        // Update lastSave timestamp
        state.lastSave = Date()

        // Offload file I/O to a background Task
        isSaving = true
        let saveManager = self.saveManager
        Task.detached(priority: .utility) { [weak self] in
            defer {
                Task { @MainActor in
                    self?.isSaving = false
                }
            }
            do {
                try saveManager.saveData(data)
            } catch {
                print("Auto-save failed: \(error)")
            }
        }
    } catch {
        print("Auto-save encoding failed: \(error)")
    }
}
```

### Key Design Notes

1. **Encode on main actor, write in background:** `state.encodeToJSON()` runs synchronously on the main actor within the tick method. This captures a consistent snapshot via `CodableSnapshot` -- no mutations can interleave. The resulting `Data` blob is then handed to a detached `Task` for the actual file write.

2. **Skip-if-in-progress:** The `isSaving` flag prevents overlapping saves. If a save from 300 ticks ago is still writing (unlikely but possible on slow storage), the current auto-save is skipped. The next 300-tick cycle will try again.

3. **`Task.detached` not `Task`:** Using `Task.detached(priority: .utility)` ensures the file I/O runs off the main actor. A plain `Task {}` would inherit the main actor context and block the UI.

4. **Weak self:** The detached task captures `[weak self]` to avoid retaining the `SimulationRunner` if the game is torn down during a save.

5. **Counter not affected by speed:** The counter counts raw ticks, not game-time. At faster speeds the tick rate stays at 10 TPS (only the `deltaSeconds` scaling changes), so auto-save fires at the same wall-clock interval regardless of game speed.

---

## 6. App Lifecycle

**Maps from:** `app.py` `BigPigFarmApp` (194 lines)
**Swift file:** `BigPigFarmApp.swift`

### Overview

The Python `BigPigFarmApp` is a Textual `App` subclass that:
1. Creates or loads `GameState` via `CombinedSaveManager`
2. Sets up the `GameEngine`, `BehaviorController`, and `SimulationRunner`
3. Saves on exit (`on_unmount`)
4. Provides callbacks for pig sold, pregnancy, and birth events

The iOS port translates this to a SwiftUI `App` struct with `@Environment(\.scenePhase)` for lifecycle observation.

### BigPigFarmApp Type Signature

```swift
import SwiftUI

@main
struct BigPigFarmApp: App {
    /// Root game state -- either loaded from disk or freshly created.
    @State private var gameState: GameState

    /// Timer-based tick loop.
    @State private var gameEngine: GameEngine

    /// Tick orchestration for all simulation subsystems.
    @State private var simulationRunner: SimulationRunner

    /// Persistence manager.
    private let saveManager: SaveManager

    /// Tracks app lifecycle transitions.
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let save = SaveManager()
        let state: GameState
        if let loaded = save.load() {
            state = loaded
            state.logEvent("Welcome back to Big Pig Farm!", eventType: "info")
        } else {
            state = GameState()
            NewGameSetup.configure(state)
        }

        let engine = GameEngine(state: state)
        let runner = SimulationRunner(
            state: state,
            saveManager: save
        )
        engine.registerTickCallback(runner.tick)

        _gameState = State(initialValue: state)
        _gameEngine = State(initialValue: engine)
        _simulationRunner = State(initialValue: runner)
        self.saveManager = save
    }

    var body: some Scene {
        WindowGroup {
            ContentView(gameState: gameState)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(from: oldPhase, to: newPhase)
                }
                .onAppear {
                    gameEngine.start()
                }
        }
    }
}
```

### Scene Phase Handling

```swift
extension BigPigFarmApp {
    /// Respond to app lifecycle transitions.
    ///
    /// Maps from: `app.py` `on_unmount()` (save on exit)
    ///
    /// iOS apps can be suspended or terminated at any time. We save
    /// aggressively on every transition away from `.active`.
    @MainActor
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App returned to foreground -- resume simulation
            if oldPhase == .inactive || oldPhase == .background {
                gameEngine.start()
                gameState.sessionStart = Date()
            }

        case .inactive:
            // App is transitioning (e.g., control center pulled down,
            // incoming call). Pause the simulation but don't save yet --
            // the app may return to .active immediately.
            gameEngine.stop()

        case .background:
            // App is fully backgrounded. Save immediately and
            // synchronously -- iOS may terminate the process shortly.
            gameEngine.stop()
            lifecycleSave()

        @unknown default:
            break
        }
    }

    /// Synchronous save for lifecycle events.
    ///
    /// Unlike auto-save (which offloads I/O to a background Task),
    /// lifecycle saves must complete synchronously because iOS may
    /// terminate the process immediately after entering background.
    @MainActor
    private func lifecycleSave() {
        do {
            gameState.lastSave = Date()
            try saveManager.save(gameState)
        } catch {
            print("Lifecycle save failed: \(error)")
        }
    }
}
```

### New Game Setup

When no save file exists, the app creates a fresh `GameState` and populates it with starter content. This mirrors `app.py` `_setup_new_game()`:

```swift
/// Configures a fresh GameState with starting pigs, facilities, and log message.
///
/// Maps from: `app.py` `_setup_new_game()` (lines 113-151)
enum NewGameSetup {
    static func configure(_ state: GameState) {
        var existingNames: Set<String> = []

        // Create one male and one female starter pig
        for gender in [Gender.male, .female] {
            let name = PigNames.generateUniqueName(
                existing: existingNames,
                gender: gender
            )
            existingNames.insert(name)

            let position: Position
            if let walkable = state.farm.findRandomWalkable() {
                position = Position(x: Double(walkable.x), y: Double(walkable.y))
            } else {
                position = Position(x: 5.0, y: 5.0)
            }

            let pig = GuineaPig.create(
                name: name,
                gender: gender,
                position: position,
                ageDays: 5.0  // Start as adults
            )
            state.addGuineaPig(pig)
        }

        // Register starter pigs in pigdex
        for pig in state.getPigsList() {
            Birth.registerPigInPigdex(state, pig: pig)
        }

        // Place starting facilities
        let foodBowl = Facility.create(type: .foodBowl, x: 5, y: 3)
        let waterBottle = Facility.create(type: .waterBottle, x: 10, y: 3)
        let hideout = Facility.create(type: .hideout, x: 14, y: 3)

        _ = state.addFacility(foodBowl)
        _ = state.addFacility(waterBottle)
        _ = state.addFacility(hideout)

        state.logEvent("Welcome to Big Pig Farm!", eventType: "info")
    }
}
```

### SimulationRunner Save Integration

The `SimulationRunner` needs a reference to `SaveManager` for auto-save. This is injected at initialization. The relevant delta to the Doc 05 specification:

```swift
// Add to SimulationRunner init (Doc 05 Section 14):
let saveManager: SaveManager

init(state: GameState, saveManager: SaveManager, ...) {
    self.saveManager = saveManager
    // ... rest of init from Doc 05
}
```

The `SimulationRunner` does not need to conform to any save protocol. It holds a `SaveManager` value directly and calls `backgroundSave()` on the 300-tick cadence as shown in Section 5.

### Event Callbacks

The Python `app.py` registers three callbacks: `on_pig_sold`, `on_pregnancy`, `on_birth`. These are specified in Doc 05 Section 14 (`SimulationRunner` event callbacks). On iOS, they update `GameState` event log entries, and the UI layer observes these via `@Observable` -- no additional wiring is needed in `BigPigFarmApp`.

For haptic feedback on these events, see Section 9.

---

## 7. ContentView Updates

**Swift file:** `ContentView.swift` (delta to Doc 06 Section 11 and Doc 07 Section 2)

Doc 06 specifies `ContentView` as the `SpriteView` root with sheet wiring. Doc 07 adds all the sheet presentations. This spec adds one change: `ContentView` now receives `gameState` as a parameter from `BigPigFarmApp`:

```swift
// ContentView signature update:
struct ContentView: View {
    let gameState: GameState
    // ... rest as specified in Doc 06 Section 11 and Doc 07 Section 2
}
```

This replaces the stub's `Text("Big Pig Farm")` body. The full `ContentView` implementation is specified across Doc 06 (SpriteView + sheet wiring) and Doc 07 (sheet presentations). This spec only adds the `gameState` injection from `BigPigFarmApp`.

---

## 8. Save Migration

**Maps from:** `game/world_migration.py` (261 lines)
**Swift file:** `Engine/SaveMigration.swift`

### Overview

When loading a save file, certain post-load repairs may be needed:
- Farm areas may need relayout after a grid layout algorithm change
- Rooms may need resizing after a tier upgrade change
- Pigs may end up on non-walkable cells after area/room changes

The Python `save_manager_v2.py` `load()` method runs these checks inline. The iOS port extracts them into a dedicated `SaveMigration` enum.

### Type Signature

```swift
/// Post-load migration and repair for saved game states.
///
/// Maps from: `game/world_migration.py` `relayout_areas()`,
/// `resize_all_rooms()`, `_clamp_orphaned_pigs()` and
/// `game/save_manager_v2.py` `load()` inline migration logic.
enum SaveMigration {
    /// Run all post-load migrations on a loaded GameState.
    ///
    /// Called by `SaveManager.loadFromURL()` after JSON decoding.
    /// Mutates the state in place.
    static func migrateIfNeeded(_ state: GameState) {
        // 1. Ensure areas exist (for saves that predate multi-area)
        if state.farm.areas.isEmpty {
            state.farm.createLegacyStarterArea()
        }

        // 2. Relayout areas to current grid layout algorithm
        let didRelayout = relayoutAreas(state)
        if !didRelayout {
            // relayoutAreas rebuilds everything when it fires;
            // only run repair + tunnel rebuild when it was a no-op
            state.farm.repairAreaCells()
            state.farm.rebuildTunnels()
        }

        // 3. Sync farm.tier and resize rooms to match current tier dimensions
        state.farm.tier = state.farmTier
        resizeAllRooms(state, tier: state.farmTier)
    }
}
```

### relayoutAreas

```swift
extension SaveMigration {
    /// Migrate a legacy or outdated layout to the 2-column grid layout.
    ///
    /// Maps from: `game/world_migration.py` `relayout_areas()` (lines 17-115)
    ///
    /// Assigns grid_col/grid_row to each area, computes new world positions,
    /// relocates pigs and facilities, and rebuilds the grid fresh.
    ///
    /// - Returns: `true` if a relayout was performed, `false` if already up-to-date.
    @discardableResult
    static func relayoutAreas(_ state: GameState) -> Bool {
        // IMPORTANT: FarmGrid is a struct (value type). All mutations must go
        // through state.farm directly so changes are persisted back to GameState.
        // A local `let farm = state.farm` would create a copy and discard changes.
        guard state.farm.areas.count >= 2 else { return false }

        // Step 1: Assign grid slots
        for (i, area) in state.farm.areas.enumerated() {
            area.gridCol = i % 2
            area.gridRow = i / 2
        }

        // Step 2: Compute expected positions
        let origins = GridExpansion.computeGridLayout(state.farm)

        // Check if any area is out of position
        let needsRelayout = state.farm.areas.enumerated().contains { i, area in
            (area.x1, area.y1) != origins[i]
        }
        guard needsRelayout else { return false }

        // Step 3: Compute deltas and relocate entities
        var deltas: [UUID: (dx: Int, dy: Int)] = [:]
        for (i, area) in state.farm.areas.enumerated() {
            let (targetX1, targetY1) = origins[i]
            deltas[area.id] = (targetX1 - area.x1, targetY1 - area.y1)
        }

        // Relocate pigs
        for pig in state.getPigsList() {
            let area = state.farm.getAreaAt(Int(pig.position.x), Int(pig.position.y))
            if let area, let delta = deltas[area.id] {
                pig.position.x += Double(delta.dx)
                pig.position.y += Double(delta.dy)
            }
            pig.path = []
            pig.targetPosition = nil
            pig.targetFacilityID = nil
        }

        // Relocate facilities
        for facility in state.getFacilitiesList() {
            let area = state.farm.getAreaAt(facility.positionX, facility.positionY)
            if let area, let delta = deltas[area.id] {
                state.farm.removeFacility(facility)
                facility.positionX += delta.dx
                facility.positionY += delta.dy
            }
        }

        // Step 4: Update area coordinates
        for (i, area) in state.farm.areas.enumerated() {
            let (targetX1, targetY1) = origins[i]
            let areaWidth = area.x2 - area.x1 + 1
            let areaHeight = area.y2 - area.y1 + 1
            area.x1 = targetX1
            area.y1 = targetY1
            area.x2 = targetX1 + areaWidth - 1
            area.y2 = targetY1 + areaHeight - 1
        }

        // Step 5: Rebuild grid fresh
        state.farm.rebuildGridFromAreas()

        // Re-place facilities
        for facility in state.getFacilitiesList() {
            state.farm.placeFacility(facility)
        }

        // Rebuild tunnels
        state.farm.rebuildTunnels()

        clampOrphanedPigs(state)

        return true
    }
}
```

### resizeAllRooms

```swift
extension SaveMigration {
    /// Resize all rooms to match the given tier's dimensions.
    ///
    /// Maps from: `game/world_migration.py` `resize_all_rooms()` (lines 118-240)
    ///
    /// No-op if all rooms already have the correct dimensions.
    ///
    /// - Returns: `true` if a resize was performed.
    @discardableResult
    static func resizeAllRooms(_ state: GameState, tier: Int) -> Bool {
        // IMPORTANT: FarmGrid is a struct — all mutations go through state.farm.
        let tierInfo = TierUpgradeConfig.forTier(tier)
        let targetWidth = tierInfo.roomWidth
        let targetHeight = tierInfo.roomHeight

        // Check if any area needs resizing
        let needsResize = state.farm.areas.contains { area in
            (area.x2 - area.x1 + 1) != targetWidth ||
            (area.y2 - area.y1 + 1) != targetHeight
        }
        guard needsResize else { return false }

        // Record old bounds for entity relocation
        var oldBounds: [UUID: (x1: Int, y1: Int, x2: Int, y2: Int)] = [:]
        for area in state.farm.areas {
            oldBounds[area.id] = (area.x1, area.y1, area.x2, area.y2)
        }

        // Resize all areas
        for area in state.farm.areas {
            area.x2 = area.x1 + targetWidth - 1
            area.y2 = area.y1 + targetHeight - 1
        }

        // Recompute grid layout with new dimensions
        let origins = GridExpansion.computeGridLayout(state.farm)

        // Compute per-area deltas
        var deltas: [UUID: (dx: Int, dy: Int)] = [:]
        for (i, area) in state.farm.areas.enumerated() {
            let (targetX1, targetY1) = origins[i]
            guard let old = oldBounds[area.id] else { continue }
            let dx = targetX1 - old.x1
            let dy = targetY1 - old.y1
            if dx != 0 || dy != 0 {
                deltas[area.id] = (dx, dy)
            }
        }

        // Relocate pigs by their area's delta
        for pig in state.getPigsList() {
            let pigX = Int(pig.position.x)
            let pigY = Int(pig.position.y)
            for (areaID, old) in oldBounds {
                if old.x1 <= pigX && pigX <= old.x2 &&
                   old.y1 <= pigY && pigY <= old.y2 {
                    if let delta = deltas[areaID] {
                        pig.position.x += Double(delta.dx)
                        pig.position.y += Double(delta.dy)
                    }
                    break
                }
            }
            pig.path = []
            pig.targetPosition = nil
            pig.targetFacilityID = nil
        }

        // Relocate facilities
        for facility in state.getFacilitiesList() {
            for (areaID, old) in oldBounds {
                if old.x1 <= facility.positionX && facility.positionX <= old.x2 &&
                   old.y1 <= facility.positionY && facility.positionY <= old.y2 {
                    state.farm.removeFacility(facility)
                    if let delta = deltas[areaID] {
                        facility.positionX += delta.dx
                        facility.positionY += delta.dy
                    }
                    break
                }
            }
        }

        // Update area coordinates to new positions
        for (i, area) in state.farm.areas.enumerated() {
            let (targetX1, targetY1) = origins[i]
            area.x1 = targetX1
            area.y1 = targetY1
            area.x2 = targetX1 + targetWidth - 1
            area.y2 = targetY1 + targetHeight - 1
        }

        // Rebuild grid fresh
        state.farm.rebuildGridFromAreas()

        // Re-place facilities
        for facility in state.getFacilitiesList() {
            state.farm.placeFacility(facility)
        }

        state.farm.rebuildTunnels()
        clampOrphanedPigs(state)
        state.farm.tier = tier

        return true
    }
}
```

### clampOrphanedPigs

```swift
extension SaveMigration {
    /// Clamp pigs on non-walkable cells to the nearest walkable cell.
    ///
    /// Maps from: `game/world_migration.py` `_clamp_orphaned_pigs()` (lines 243-261)
    ///
    /// Falls back to the first area's center if no walkable cell is nearby.
    static func clampOrphanedPigs(_ state: GameState) {
        // Note: FarmGrid is read-only here (no mutations), so a local copy is safe.
        // Using state.farm directly for consistency with the other migration functions.
        for pig in state.getPigsList() {
            let pigX = Int(pig.position.x)
            let pigY = Int(pig.position.y)
            if !state.farm.isWalkable(pigX, pigY) {
                if let walkable = state.farm.findNearestWalkable(
                    from: GridPosition(x: pigX, y: pigY),
                    maxDistance: 20
                ) {
                    pig.position.x = Double(walkable.x)
                    pig.position.y = Double(walkable.y)
                } else if let firstArea = state.farm.areas.first {
                    pig.position.x = Double(firstArea.centerX)
                    pig.position.y = Double(firstArea.centerY)
                }
            }
        }
    }
}
```

### FarmGrid Helper Method

The migration code above references `state.farm.rebuildGridFromAreas()`, which consolidates the Python pattern of clearing cells, re-carving areas, and recomputing grid size:

```swift
extension FarmGrid {
    /// Rebuild the entire grid from scratch based on current areas.
    ///
    /// Used by SaveMigration after relocating areas. Clears all cells,
    /// recomputes grid dimensions, re-carves areas, and rebuilds tunnels.
    mutating func rebuildGridFromAreas() {
        // Compute required grid size
        var totalWidth = 0
        var totalHeight = 0
        for area in areas {
            totalWidth = max(totalWidth, area.x2 + 1)
            totalHeight = max(totalHeight, area.y2 + 1)
        }

        // Reset grid
        width = totalWidth
        height = totalHeight
        cells = (0..<totalHeight).map { _ in
            (0..<totalWidth).map { _ in Cell() }
        }
        tunnels.removeAll()

        // Re-carve all areas
        let savedAreas = Array(areas)
        areas.removeAll()
        areaLookup.removeAll()
        for area in savedAreas {
            addArea(area)
        }
    }
}
```

**Note:** `rebuildGridFromAreas()` should be added to the `FarmGrid` implementation alongside the existing methods specified in Doc 04 Section 7. It is a convenience wrapper that avoids duplicating the 15-line rebuild pattern across three migration functions.

---

## 9. Haptic Feedback

**Swift file:** `Engine/HapticManager.swift`

### Overview

Haptic feedback provides tactile responses for key game events, enhancing the feel of the iOS app. The Python Textual source has no haptic equivalent -- this is an iOS-native enhancement.

### Type Signature

```swift
import UIKit

/// Provides haptic feedback for key game events.
///
/// All methods are safe to call from any context -- they dispatch
/// to the main actor internally, since UIKit haptic APIs require
/// main-thread access.
enum HapticManager {
    // MARK: - Feedback Generators

    /// Light impact for routine events (pig selected, menu opened).
    @MainActor
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)

    /// Medium impact for meaningful events (purchase, sale).
    @MainActor
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)

    /// Heavy impact for major events (birth, pigdex discovery).
    @MainActor
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)

    /// Success notification for positive outcomes.
    @MainActor
    private static let notification = UINotificationFeedbackGenerator()

    // MARK: - Event Methods

    /// Pig tapped/selected in the farm scene.
    @MainActor
    static func pigSelected() {
        lightImpact.impactOccurred()
    }

    /// Facility or perk purchased from the shop.
    @MainActor
    static func purchase() {
        mediumImpact.impactOccurred()
    }

    /// Pig sold at market or auto-sold.
    @MainActor
    static func pigSold() {
        mediumImpact.impactOccurred()
    }

    /// New pig born.
    @MainActor
    static func birth() {
        heavyImpact.impactOccurred()
    }

    /// New phenotype discovered in the pigdex.
    @MainActor
    static func pigdexDiscovery() {
        notification.notificationOccurred(.success)
    }

    /// Breeding contract completed.
    @MainActor
    static func contractCompleted() {
        notification.notificationOccurred(.success)
    }

    /// Error or failure (insufficient funds, invalid placement).
    @MainActor
    static func error() {
        notification.notificationOccurred(.error)
    }
}
```

### Integration Points

Haptic calls are added at the call sites in the existing view and scene code:

| Event | Where to Call | Haptic |
|-------|--------------|--------|
| Pig tapped | `FarmScene.touchesBegan` (Doc 06 Section 9) | `pigSelected()` |
| Facility purchased | `ShopView` purchase action (Doc 07 Section 4) | `purchase()` |
| Perk/upgrade purchased | `ShopView` purchase action (Doc 07 Section 4) | `purchase()` |
| Pig sold | `SimulationRunner` `onPigSold` callback (Doc 05 Section 14) | `pigSold()` |
| Pig born | `SimulationRunner` `onBirth` callback (Doc 05 Section 14) | `birth()` |
| Pigdex discovery | `Birth.registerPigInPigdex` when new entry (Doc 05 Section 10) | `pigdexDiscovery()` |
| Contract completed | `Market.sellPig` when contract fulfilled (Doc 04 Section 17) | `contractCompleted()` |
| Insufficient funds | `ShopView` purchase denied (Doc 07 Section 4) | `error()` |
| Invalid placement | `FarmScene` edit mode failure (Doc 06 Section 10) | `error()` |

These are single-line additions at the existing call sites -- no structural changes to the views or scene.

---

## 10. App Icon and Launch Screen

### App Icon

The app icon uses a guinea pig illustration in the game's pixel art style. The icon asset set goes in `Assets.xcassets/AppIcon.appiconset/`.

Since Xcode 15+, a single 1024x1024 PNG is sufficient -- Xcode automatically generates all required sizes from it. The `project.yml` already references `Assets.xcassets` (Doc 01).

**Icon design guidelines:**
- Feature a single guinea pig face in the game's art style
- Use the meadow biome green as the background color
- Keep the design simple and recognizable at small sizes (29x29 down to app icon)
- No text in the icon

**Implementation note:** The actual icon artwork is a creative asset, not a code deliverable. The implementer should create or commission a 1024x1024 PNG and place it at `Assets.xcassets/AppIcon.appiconset/AppIcon.png` with the corresponding `Contents.json`.

### Launch Screen

iOS 17+ apps can use a SwiftUI launch screen defined in `Info.plist` or a `LaunchScreen.storyboard`. The simplest approach is a solid background color with the app name:

In `project.yml`, add under the target settings:

```yaml
settings:
  INFOPLIST_KEY_UILaunchScreen_Generation: true
  # Optional: customize the background color
  # INFOPLIST_KEY_UILaunchScreen.BackgroundColor: MeadowGreen
```

This tells Xcode to auto-generate a minimal launch screen. If a custom launch screen is desired later, create `LaunchScreen.storyboard` with a centered guinea pig logo and meadow green background.

---

## 11. Performance Profiling

### Tick Budget

At 10 TPS, each tick has a 100ms budget. The simulation must complete well within this. Targets:

| Metric | Target | Measurement |
|--------|--------|-------------|
| Tick time (20 pigs) | < 10ms | `SimulationRunner` TPS counter |
| Tick time (50 pigs) | < 30ms | `SimulationRunner` TPS counter |
| Tick time (100 pigs) | < 60ms | Instruments Time Profiler |
| JSON encode (50 pigs) | < 50ms | `CFAbsoluteTimeGetCurrent` before/after |
| JSON decode (50 pigs) | < 100ms | `CFAbsoluteTimeGetCurrent` before/after |
| Save file write | < 20ms | Measured in background Task |

### Instruments Profiling Strategy

Use Xcode Instruments with these templates during Phase 5:

1. **Time Profiler:** Identify hot spots in the tick loop. Focus on pathfinding, collision, and needs updates.
2. **Allocations:** Watch for unexpected heap allocations in the tick loop. Value types should stay on the stack.
3. **SpriteKit:** Monitor frame rate, node count, draw calls. Target 60 FPS with 50+ pig nodes.
4. **File Activity:** Verify auto-save writes complete quickly and don't block the main thread.

### JSON Encode/Decode Benchmarking

The CHECKLIST includes an investigation item: "Measure JSON save/load performance with 200+ pigs." The benchmark should:

1. Create a `GameState` with 200 pigs, 50 facilities, 4 areas
2. Encode to JSON and measure wall-clock time
3. Decode from JSON and measure wall-clock time
4. Verify the roundtrip produces an equivalent state

If encoding exceeds 100ms at 200 pigs, consider:
- Pre-encoding static data (genotypes, phenotypes don't change between saves)
- Incremental save (only encode changed pigs) -- significant complexity, defer unless needed

### Node Count Optimization

From Doc 06 Section 13, SpriteKit performance degrades with excessive draw calls. Monitor:
- Total `SKSpriteNode` count (pigs + facilities + indicators)
- Off-screen node culling effectiveness
- Texture atlas utilization (batched draw calls)

---

## 12. TestFlight Preparation

### Build Configuration

The `project.yml` already defines Debug and Release configurations (Doc 01). For TestFlight:

1. **Release scheme:** Ensure the Release configuration enables optimizations (`-O`) and strips debug symbols
2. **Bundle identifier:** `com.bigpigfarm.ios` (or the developer's chosen prefix)
3. **Version:** `1.0.0` (build number `1`, incremented per TestFlight upload)
4. **Minimum deployment:** iOS 17.0

### Info.plist Entries

Add to the target's `Info.plist` configuration in `project.yml`:

```yaml
settings:
  INFOPLIST_KEY_CFBundleDisplayName: Big Pig Farm
  INFOPLIST_KEY_LSApplicationCategoryType: "public.app-category.simulation-games"
  INFOPLIST_KEY_UIRequiredDeviceCapabilities: [arm64]
  INFOPLIST_KEY_UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]
  INFOPLIST_KEY_UISupportedInterfaceOrientations~ipad: [UIInterfaceOrientationPortrait, UIInterfaceOrientationPortraitUpsideDown, UIInterfaceOrientationLandscapeLeft, UIInterfaceOrientationLandscapeRight]
  INFOPLIST_KEY_UIStatusBarStyle: UIStatusBarStyleLightContent
```

### Device Orientation

The farm scene works best in landscape on iPad and portrait on iPhone. For the initial TestFlight build:
- **iPhone:** Portrait only (simplifies the camera and HUD layout)
- **iPad:** All orientations (the camera system from Doc 06 handles viewport resizing)

### TestFlight Checklist

Before uploading the first TestFlight build:

- [ ] All Phase 0-5 implementation tasks complete
- [ ] Zero SwiftLint warnings
- [ ] All tests pass
- [ ] Save/load roundtrip verified on device
- [ ] 30-minute play session without crashes
- [ ] App icon set in asset catalog
- [ ] Launch screen configured
- [ ] Bundle version and build number set
- [ ] Archive build succeeds with Release configuration
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) included if required by App Store

---

## 13. Stub Corrections

The following placeholder files created in Doc 01 need updates:

### `Engine/SaveManager.swift`

**Current stub:**
```swift
struct SaveManager: Sendable {
    // TODO: Implement in doc 08
}
```

**Correct signature:** Full `SaveManager` struct as specified in Section 2, plus `SaveEnvelope` as specified in Section 2.

### `BigPigFarmApp.swift`

**Current stub:**
```swift
@main
struct BigPigFarmApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Correct signature:** Full `BigPigFarmApp` with `@State` properties, `SaveManager`, `scenePhase` handling, and `NewGameSetup` as specified in Section 6.

### New Files

The following files do not have stubs and must be created:

| File | Contents |
|------|----------|
| `Engine/GameState+Codable.swift` | `CodableSnapshot`, `SaveEnvelope`, `GameState.encodeToJSON()`, `GameState.fromSnapshot()` (Section 3) |
| `Engine/SaveMigration.swift` | `SaveMigration` enum with migration functions (Section 8) |
| `Engine/HapticManager.swift` | `HapticManager` enum (Section 9) |

---

## 14. Testing

**Swift file:** `BigPigFarmTests/SaveManagerTests.swift`

### Test Cases

Maps from `tests/test_save_manager_v2.py` (182 lines), adapted for the JSON file approach.

```swift
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Helpers

/// Create a SaveManager that uses a temporary directory.
/// Returns the manager and the temp directory URL for cleanup.
private func makeTempSaveManager() throws -> (SaveManager, URL) {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: tempDir, withIntermediateDirectories: true
    )
    let manager = SaveManager(baseDirectoryURL: tempDir)
    return (manager, tempDir)
}

/// Create a test pig.
private func makePig(
    name: String = "Test",
    gender: Gender = .male,
    ageDays: Double = 5.0
) -> GuineaPig {
    GuineaPig.create(
        name: name,
        gender: gender,
        position: Position(x: 5.0, y: 5.0),
        ageDays: ageDays
    )
}
```

#### SaveManager Roundtrip Tests

```swift
@Test("Roundtrip empty state")
func roundtripEmptyState() throws {
    let (manager, tempDir) = try makeTempSaveManager()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let state = GameState()
    try manager.save(state)

    let loaded = manager.load()
    #expect(loaded != nil)
    #expect(loaded?.money == state.money)
    #expect(loaded?.guineaPigs.count == 0)
}

@Test("Roundtrip with pigs")
func roundtripWithPigs() throws {
    let (manager, tempDir) = try makeTempSaveManager()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let state = GameState()
    let pig = makePig()
    state.addGuineaPig(pig)

    try manager.save(state)
    let loaded = manager.load()

    #expect(loaded != nil)
    #expect(loaded?.guineaPigs.count == 1)
    let loadedPig = loaded?.getPigsList().first
    #expect(loadedPig?.name == pig.name)
    #expect(loadedPig?.position.x == pig.position.x)
}

@Test("Roundtrip with facilities")
func roundtripWithFacilities() throws {
    let (manager, tempDir) = try makeTempSaveManager()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let state = GameState()
    let facility = Facility.create(type: .foodBowl, x: 5, y: 3)
    _ = state.addFacility(facility)

    try manager.save(state)
    let loaded = manager.load()

    #expect(loaded != nil)
    #expect(loaded?.getFacilitiesList().count == 1)
    let loadedFacility = loaded?.getFacilitiesList().first
    #expect(loadedFacility?.facilityType == .foodBowl)
}

@Test("Roundtrip money and speed")
func roundtripMoneyAndSpeed() throws {
    let (manager, tempDir) = try makeTempSaveManager()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let state = GameState()
    state.money = 999
    state.speed = .fast

    try manager.save(state)
    let loaded = manager.load()

    #expect(loaded?.money == 999)
    #expect(loaded?.speed == .fast)
}

@Test("Roundtrip statistics")
func roundtripStatistics() throws {
    let (manager, tempDir) = try makeTempSaveManager()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let state = GameState()
    state.totalPigsBorn = 10
    state.totalPigsSold = 5
    state.totalEarnings = 500

    try manager.save(state)
    let loaded = manager.load()

    #expect(loaded?.totalPigsBorn == 10)
    #expect(loaded?.totalPigsSold == 5)
    #expect(loaded?.totalEarnings == 500)
}

@Test("Roundtrip farm grid")
func roundtripFarmGrid() throws {
    let (manager, tempDir) = try makeTempSaveManager()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let state = GameState()

    try manager.save(state)
    let loaded = manager.load()

    #expect(loaded?.farm.width == state.farm.width)
    #expect(loaded?.farm.height == state.farm.height)
    #expect(loaded?.farmTier == state.farmTier)
    // Verify pathfinding still works after reload
    #expect(loaded?.farm.findRandomWalkable() != nil)
}
```

#### Query and Delete Tests

```swift
@Test("Load nonexistent returns nil")
func loadNonexistentReturnsNil() throws {
    let (manager, tempDir) = try makeTempSaveManager()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    #expect(manager.load() == nil)
}

@Test("hasSave returns correct value")
func hasSave() throws {
    let (manager, tempDir) = try makeTempSaveManager()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    #expect(!manager.hasSave())

    let state = GameState()
    try manager.save(state)
    #expect(manager.hasSave())
}

@Test("deleteSave removes files")
func deleteSave() throws {
    let (manager, tempDir) = try makeTempSaveManager()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let state = GameState()
    try manager.save(state)
    #expect(manager.hasSave())

    manager.deleteSave()
    #expect(!manager.hasSave())
}
```

#### Backup and Corruption Tests

```swift
@Test("Backup created on second save")
func backupCreated() throws {
    let (manager, tempDir) = try makeTempSaveManager()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let state = GameState()
    try manager.save(state)  // First save
    try manager.save(state)  // Second save creates backup

    #expect(FileManager.default.fileExists(atPath: manager.backupFileURL.path))
}

@Test("Corrupted save file returns nil")
func corruptedSaveReturnsNil() throws {
    let (manager, tempDir) = try makeTempSaveManager()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    // Write garbage data to the save file
    let garbage = "not valid json!!!".data(using: .utf8)!
    try garbage.write(to: manager.saveFileURL, options: .atomic)

    #expect(manager.load() == nil)
}

@Test("Falls back to backup when primary is corrupted")
func fallbackToBackup() throws {
    let (manager, tempDir) = try makeTempSaveManager()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let state = GameState()
    state.money = 777
    try manager.save(state)

    // Save again to create a backup of the money=777 state
    state.money = 888
    try manager.save(state)

    // Corrupt the primary save
    let garbage = "corrupted".data(using: .utf8)!
    try garbage.write(to: manager.saveFileURL, options: .atomic)

    // Load should fall back to backup (which has money=777)
    let loaded = manager.load()
    #expect(loaded != nil)
    #expect(loaded?.money == 777)
}
```

#### GameState Codable Tests

```swift
@Test("GameState encode/decode roundtrip preserves all fields")
@MainActor
func gameStateCodableRoundtrip() throws {
    let state = GameState()
    state.money = 1234
    state.farmTier = 3
    state.totalPigsBorn = 42
    state.purchasedUpgrades = ["auto_feeder", "genetics_lab"]
    state.socialAffinity = ["abc:def": 5]
    state.speed = .fast
    state.isPaused = true

    // Use encodeToJSON() which produces a SaveEnvelope
    let data = try state.encodeToJSON()

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let envelope = try decoder.decode(SaveEnvelope.self, from: data)
    let decoded = GameState.fromSnapshot(envelope.snapshot)

    #expect(decoded.money == 1234)
    #expect(decoded.farmTier == 3)
    #expect(decoded.totalPigsBorn == 42)
    #expect(decoded.purchasedUpgrades == ["auto_feeder", "genetics_lab"])
    #expect(decoded.socialAffinity == ["abc:def": 5])
    #expect(decoded.speed == .fast)
    #expect(decoded.isPaused == true)
}

@Test("CodableSnapshot decodes missing optional fields with defaults")
func snapshotDecodesWithDefaults() throws {
    // Simulate a minimal save from an older version wrapped in a SaveEnvelope
    // Note: CodableSnapshot uses auto-synthesized Codable, so for forward
    // compatibility with new fields, a custom init(from:) with decodeIfPresent
    // defaults should be added when new fields are introduced.
    let minimalJSON = """
    {
        "schema_version": 1,
        "state": {
            "guinea_pigs": {},
            "facilities": {},
            "farm": \(minimalFarmJSON()),
            "money": 500,
            "game_time": {"day": 1, "hour": 8, "minute": 0,
                           "last_update": "2026-01-01T00:00:00Z",
                           "total_game_minutes": 0},
            "speed": "normal",
            "is_paused": false,
            "session_start": "2026-01-01T00:00:00Z",
            "events": [],
            "max_events": 100,
            "pigdex": {},
            "contract_board": {},
            "breeding_program": {},
            "social_affinity": {},
            "farm_tier": 1,
            "purchased_upgrades": [],
            "total_pigs_born": 0,
            "total_pigs_sold": 0,
            "total_earnings": 0
        }
    }
    """
    let data = minimalJSON.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let envelope = try decoder.decode(SaveEnvelope.self, from: data)
    let state = GameState.fromSnapshot(envelope.snapshot)

    // Fields should have their expected values
    #expect(state.farmTier == 1)
    #expect(state.totalPigsBorn == 0)
    #expect(state.purchasedUpgrades.isEmpty)
    #expect(state.socialAffinity.isEmpty)
    #expect(state.isPaused == false)
}
```

### Test Directory Configuration

Per Doc 01, all tests live in `BigPigFarmTests/`. The `SaveManager` accepts a `baseDirectoryURL` parameter (see Section 2) that the `makeTempSaveManager()` helper uses to redirect save I/O to a temporary directory, avoiding pollution of the app's real Documents directory during testing.

---

## 15. Implementation Order

The recommended implementation order within Phase 5:

| Step | Task | Depends On | Estimated Effort |
|------|------|------------|-----------------|
| 1 | `GameState+Codable.swift` | Doc 04 `GameState` impl | 1-2 hours |
| 2 | `SaveManager.swift` + `SaveEnvelope` | Step 1 | 1-2 hours |
| 3 | `SaveManagerTests.swift` | Steps 1-2 | 1-2 hours |
| 4 | `SaveMigration.swift` | Steps 1-2, Doc 04 `FarmGrid` impl | 2-3 hours |
| 5 | `BigPigFarmApp.swift` + `NewGameSetup` | Steps 1-4, Doc 04-05 impls | 1-2 hours |
| 6 | Auto-save integration in `SimulationRunner` | Step 2, Doc 05 impl | 30 min |
| 7 | `HapticManager.swift` + call site integration | Doc 06-07 impls | 1 hour |
| 8 | App icon + launch screen | None | 30 min |
| 9 | Performance profiling | All impls | 2-4 hours |
| 10 | TestFlight build | All above | 1-2 hours |

**Total estimated effort:** 10-18 hours (2-3 sessions as noted in the ROADMAP).

Steps 1-3 can begin as soon as the Phase 1 `GameState` implementation is complete. Steps 4-6 require the full engine and simulation. Steps 7-8 can proceed in parallel with testing. Step 9 requires a device build.

---

## 16. Decisions Needed

### Decision: Save file location within Documents

**Options:**
1. `Documents/save.json` -- flat in the Documents root
2. `Documents/BigPigFarm/save.json` -- in a subdirectory

**Recommendation:** Option 1. There is only one file. A subdirectory adds complexity with no benefit for a single-save-slot game. If multi-save is added later, migrate to a subdirectory then.

### Decision: iCloud backup opt-in

Save files in `Documents/` are backed up to iCloud by default. This preserves saves across device migrations, but large save files count against the user's iCloud quota.

**Recommendation:** Keep iCloud backup enabled. Save files are small (< 500 KB worst case). If a user has 200+ pigs and complains about iCloud usage, add an `isExcludedFromBackup` toggle in a future update.

### Decision: New Game confirmation

When a save exists and the player wants to start a new game, should the app:
1. Overwrite the save immediately
2. Show a confirmation dialog first

**Recommendation:** Option 2 -- show a `.confirmationDialog` before deleting the save. The dialog is already specified in Doc 07 (SharedComponents `ConfirmationDialog` helper). Wire it into a "New Game" button in the status bar or settings.

---

## 17. Dependencies on Previous Specs

This spec depends on all previous specs and references specific sections:

| Dependency | Section Referenced | What It Provides |
|------------|-------------------|-----------------|
| Doc 01 (Project Setup) | Folder structure, project.yml | File locations, build config |
| Doc 02 (Data Models) | All struct definitions | `Codable` conformance on all model types |
| Doc 03 (Sprite Pipeline) | Asset catalog layout | App icon location in Assets.xcassets |
| Doc 04 (Game Engine) | Section 2 (GameState), Section 7 (FarmGrid), Section 19 (SimulationRunner) | State container, grid caches, auto-save hook |
| Doc 05 (Behavior AI) | Section 14 (Tick orchestration, event callbacks) | Auto-save cadence, callback integration |
| Doc 06 (Farm Scene) | Section 9 (Touch handling), Section 11 (ContentView) | Haptic trigger points, ContentView shell |
| Doc 07 (SwiftUI Screens) | Section 2 (Navigation), Section 4 (ShopView) | Sheet wiring, purchase haptic points |

---

## 18. Summary

With this spec complete, all 8 specification documents for the Big Pig Farm iOS port are finalized. The persistence layer specified here is deliberately simple -- a single JSON file with atomic writes, backup recovery, and versioned envelopes. This matches the game's single-save-slot design and avoids the complexity of database-backed persistence.

The key architectural decisions:
- **JSON file via `FileManager`** over SQLite (ROADMAP Decision 7)
- **`CodableSnapshot` value type** instead of `Codable` on `GameState` directly -- avoids Swift 6 actor isolation issues with `@Observable`
- **Encode on main actor, write in background** for auto-save (matching the Python threading pattern)
- **Synchronous save on lifecycle** because iOS may terminate immediately after backgrounding
- **Versioned envelope** for forward-compatible save format evolution

The remaining work is implementation, following the phases in the ROADMAP and tracked in `docs/CHECKLIST.md`.
