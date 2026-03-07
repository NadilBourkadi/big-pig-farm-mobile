# Spec 02 — Data Models

> **Status:** Complete
> **Date:** 2026-02-26
> **Depends on:** 01 (Project Setup)
> **Blocks:** 04 (Game Engine), 05 (Behavior AI), 06 (Farm Scene), 07 (SwiftUI Screens), 08 (Persistence)

---

## 1. Overview

This document specifies the complete translation of all Python Pydantic models, enums, and config constants into Swift. It serves as the implementer's reference — every type, field, and value is documented so the implementer never needs to read the 20,200-line Python source.

### Scope

**In scope:**
- All enums from `entities/`, `game/`, `economy/`, `simulation/`
- All Pydantic models → Swift `struct: Codable, Sendable`
- Config constants (`data/config.py`) → caseless `enum` namespaces
- Name generation (`data/names.py`) → `PigNames` enum
- New helper types (`AllelePair`, `GridPosition`) for Swift compatibility
- Stub corrections for all 13 incorrect placeholder types

**Out of scope:**
- Game logic (tick loop, pathfinding, behavior AI) — those are Docs 04-05
- SpriteKit rendering — Doc 06
- SwiftUI screens — Doc 07
- Persistence mechanics — Doc 08
- Sprite data files (pixel grids, palettes) — Doc 03

### Deliverable Summary

| Category | Types | Files |
|----------|-------|-------|
| Enums | 18 | 7 existing + 2 new |
| Structs/Models | 24 | 7 existing + 4 new |
| Config namespaces | 13 | 1 existing → split to 3 |
| Name arrays | 7 + 2 functions | 1 existing |
| Test files | 4 | 4 existing |

---

## 2. Translation Rules

### Python → Swift Type Mapping

| Python | Swift | Notes |
|--------|-------|-------|
| `class Foo(BaseModel)` | `struct Foo: Codable, Sendable` | Unless reference semantics needed |
| `class Foo(str, Enum)` | `enum Foo: String, Codable, CaseIterable, Sendable` | Raw value = Python `.value` |
| `class Foo(Enum)` (int values) | `enum Foo: Int, Codable, CaseIterable, Sendable` | — |
| `@dataclass(frozen=True)` (config) | `enum Foo` (caseless, `static let`) | Prevents instantiation |
| `@dataclass(frozen=True)` (data) | `struct Foo: Codable, Sendable` with `let` fields | Immutable value type |
| `@dataclass` (mutable) | `struct Foo: Codable, Sendable` with `var` fields | — |
| `tuple[str, str]` (alleles) | `AllelePair` struct | Tuples aren't `Codable` |
| `tuple[int, int]` (grid coords) | `GridPosition` struct | Reusable, `Codable` |
| `float` (0.0–100.0) | `Double` | — |
| `int` | `Int` | — |
| `str` | `String` | — |
| `bool` | `Bool` | — |
| `Optional[T]` | `T?` | — |
| `UUID` | `UUID` (Foundation) | — |
| `dict[K, V]` | `[K: V]` | — |
| `list[T]` | `[T]` | — |
| `set[str]` | `Set<String>` | — |
| `datetime` | `Date` (Foundation) | — |
| `Callable` | Closure type | — |
| `@property` | `var ... { ... }` computed property | — |
| `Field(default_factory=...)` | Default initializer | — |

### CodingKeys Strategy

All struct properties use `camelCase` in Swift. For JSON persistence compatibility with the Python save format, add `CodingKeys` with `snake_case` string values where the Swift name differs:

```swift
enum CodingKeys: String, CodingKey {
    case eLocus = "e_locus"
    case bLocus = "b_locus"
    // ... etc
}
```

### Sendable Conformance

All value types (`struct`, `enum`) conform to `Sendable` — required by Swift 6 strict concurrency. `GameState` is the sole `@Observable class` and uses `@unchecked Sendable`.

---

## 3. Stub Corrections

The Doc 01 stubs contain placeholder values. Every correction is documented here.

| Stub | File | Problem | Correct Values |
|------|------|---------|---------------|
| `BaseColor` | `Genetics.swift` | 8 wrong cases | `black, chocolate, golden, cream, blue, lilac, saffron, smoke` |
| `Pattern` | `Genetics.swift` | 3 wrong cases | `solid, dutch, dalmatian` |
| `ColorIntensity` | `Genetics.swift` | 3 wrong cases | `full, chinchilla, himalayan` |
| `Rarity` | `Genetics.swift` | "epic" should be "veryRare" | `common, uncommon, rare, veryRare, legendary` |
| `Allele` | `Genetics.swift` | Empty struct → 12-case enum | `E, e, B, b, S, s, C, ch, R, r, D, d` |
| `AgeGroup` | `GuineaPig.swift` | Has `juvenile` | 3 cases: `baby, adult, senior` |
| `BehaviorState` | `GuineaPig.swift` | Wrong cases | `idle, wandering, eating, drinking, playing, sleeping, socializing, courting` |
| `Personality` | `GuineaPig.swift` | Empty struct → 7-case enum | `greedy, lazy, playful, shy, social, brave, picky` |
| `Position` | `GuineaPig.swift` | `x: Int, y: Int` | `x: Double, y: Double` (sub-cell movement) |
| `BiomeType` | `BiomeType.swift` | 8 wrong cases | `meadow, burrow, garden, tropical, alpine, crystal, wildflower, sanctuary` |
| `FacilityType` | `Facility.swift` | 6 generic cases | 17 cases (see Section 4) |
| `FacilitySize` | `Facility.swift` | Enum → struct | `struct FacilitySize` with `width: Int, height: Int` |
| `CellType` | `FarmGrid.swift` | `empty, wall, facility, tunnel` | `floor, bedding, grass, wall` |
| `Bloodline` | `Bloodline.swift` | Has `id: UUID` | No UUID — identity is `bloodlineType` |

---

## 4. Models/ — Detailed Specification

### 4.1 `Genetics.swift` (~200 lines)

**Maps from:** `entities/genetics.py` (lines 1–235, enums and phenotype calculation)

#### Enums

```swift
enum Allele: String, Codable, CaseIterable, Sendable {
    // Extension locus
    case dominantE = "E"    // Black/color (dominant)
    case recessiveE = "e"   // Red/golden (recessive)
    // Brown locus
    case dominantB = "B"    // Black (dominant)
    case recessiveB = "b"   // Chocolate (recessive)
    // Spotting locus
    case dominantS = "S"    // Solid (dominant)
    case recessiveS = "s"   // Spotted (recessive)
    // Intensity locus
    case dominantC = "C"    // Full color (dominant)
    case chinchilla = "ch"  // Diluted (recessive)
    // Roan locus
    case dominantR = "R"    // Roan (dominant, lethal homozygous)
    case recessiveR = "r"   // Normal (recessive)
    // Dilution locus
    case dominantD = "D"    // Full color (dominant)
    case recessiveD = "d"   // Diluted (recessive)
}

enum BaseColor: String, Codable, CaseIterable, Sendable {
    case black, chocolate, golden, cream
    case blue       // Diluted black (dd)
    case lilac      // Diluted chocolate (bb + dd)
    case saffron    // Diluted golden (ee + dd)
    case smoke      // Diluted cream (ee + bb + dd)
}

enum Pattern: String, Codable, CaseIterable, Sendable {
    case solid, dutch, dalmatian
}

enum ColorIntensity: String, Codable, CaseIterable, Sendable {
    case full, chinchilla, himalayan
}

enum RoanType: String, Codable, CaseIterable, Sendable {
    case none, roan
}

enum Rarity: String, Codable, CaseIterable, Sendable {
    case common, uncommon, rare, veryRare = "very_rare", legendary
}
```

#### AllelePair

New type — Python uses `tuple[str, str]` for allele pairs, but Swift tuples aren't `Codable`.

```swift
struct AllelePair: Codable, Sendable, Hashable {
    let first: String
    let second: String

    /// Check if either allele matches the given value.
    func contains(_ allele: String) -> Bool { ... }

    /// Count occurrences of the given allele (0, 1, or 2).
    func count(_ allele: String) -> Int { ... }

    /// Check if both alleles are the same value.
    func isHomozygous(_ allele: String) -> Bool { ... }

    /// Check if at least one allele matches (dominance check).
    func hasDominant(_ dominant: String) -> Bool { ... }
}
```

#### Genotype

```swift
struct Genotype: Codable, Sendable {
    var eLocus: AllelePair   // Extension: E/e
    var bLocus: AllelePair   // Brown: B/b
    var sLocus: AllelePair   // Spotting: S/s
    var cLocus: AllelePair   // Intensity: C/ch
    var rLocus: AllelePair   // Roan: R/r
    var dLocus: AllelePair   // Dilution: D/d

    /// Generate random common genotype (solid, full color, no roan, no dilution).
    static func randomCommon() -> Genotype { ... }

    /// Generate random genotype with more variation.
    static func random() -> Genotype { ... }

    enum CodingKeys: String, CodingKey {
        case eLocus = "e_locus"
        case bLocus = "b_locus"
        case sLocus = "s_locus"
        case cLocus = "c_locus"
        case rLocus = "r_locus"
        case dLocus = "d_locus"
    }
}
```

#### Phenotype

```swift
struct Phenotype: Codable, Sendable, Hashable {
    let baseColor: BaseColor
    let pattern: Pattern
    let intensity: ColorIntensity
    let roan: RoanType
    let rarity: Rarity

    /// Human-readable name (e.g. "Roan Chinchilla Dutch Black").
    var displayName: String { ... }

    enum CodingKeys: String, CodingKey {
        case baseColor = "base_color"
        case pattern, intensity, roan, rarity
    }
}
```

#### Functions (in Genetics.swift)

| Function | Signature | Notes |
|----------|-----------|-------|
| `calculatePhenotype` | `(Genotype) -> Phenotype` | Determines observable traits from alleles |
| `calculateRarity` | `(BaseColor, Pattern, ColorIntensity, RoanType) -> Rarity` | Point-based rarity scoring |
| `determineBaseColor` | `(Bool, Bool, Bool) -> BaseColor` | From E/B/D dominance flags (private) |

#### Constants

```swift
/// Locus definitions for mutation/breeding: (locusKeyPath, dominant, recessive)
let locusDefinitions: [(String, String, String)] = [
    ("eLocus", "E", "e"),
    ("bLocus", "B", "b"),
    ("sLocus", "S", "s"),
    ("cLocus", "C", "ch"),
    ("rLocus", "R", "r"),
    ("dLocus", "D", "d"),
]

/// Human-readable locus names for UI/logging.
let locusDisplayNames: [String: String] = [
    "eLocus": "Extension",
    "bLocus": "Brown",
    "sLocus": "Spotted",
    "cLocus": "Intensity",
    "rLocus": "Roan",
    "dLocus": "Dilution",
]
```

### 4.2 `GeneticsBreeding.swift` (~200 lines) — NEW FILE

**Maps from:** `entities/genetics.py` (lines 288–655, breeding and prediction)

Split from `Genetics.swift` to stay under 300 lines.

#### BreedResult

```swift
struct BreedResult: Sendable {
    let genotype: Genotype
    let mutations: [String]
}
```

#### Functions

| Function | Signature | Notes |
|----------|-----------|-------|
| `breed` | `(Genotype, Genotype, Double, [String: Double]?, [String: String]?, Double) -> BreedResult` | Mendelian inheritance + mutations |
| `inheritAllele` | `(AllelePair, AllelePair) -> AllelePair` | Random allele from each parent |
| `mutateLocus` | `(AllelePair, String, String, Double) -> (AllelePair, Bool)` | Random flip at mutation rate |
| `mutateLocusDirectional` | `(AllelePair, String, Double) -> (AllelePair, Bool)` | Push toward target allele |
| `carrierSummary` | `(Genotype) -> String` | Human-readable carrier allele list |
| `predictOffspringPhenotypes` | `(Genotype, Genotype) -> [(Phenotype, Double)]` | Monte Carlo (1000 samples) |
| `calculateTargetProbability` | `(Genotype, Genotype, Set<BaseColor>, Set<Pattern>, Set<ColorIntensity>, Set<RoanType>) -> Double` | Analytical Punnett square |

### 4.3 `GuineaPig.swift` (~250 lines)

**Maps from:** `entities/guinea_pig.py` (292 lines)

#### Corrected Enums

```swift
enum Gender: String, Codable, CaseIterable, Sendable {
    case male, female
}

enum AgeGroup: String, Codable, CaseIterable, Sendable {
    case baby, adult, senior  // No "juvenile"
}

enum BehaviorState: String, Codable, CaseIterable, Sendable {
    case idle, wandering, eating, drinking
    case playing, sleeping, socializing, courting
}

enum Personality: String, Codable, CaseIterable, Sendable {
    case greedy     // +50% hunger decay
    case lazy       // -30% energy decay
    case playful    // +50% boredom decay
    case shy        // Avoids pigs, prefers hideouts
    case social     // Seeks pigs, group happiness
    case brave      // Explores more
    case picky      // Prefers quality facilities
}
```

#### Position (corrected: Double, not Int)

```swift
struct Position: Codable, Sendable, Hashable {
    var x: Double = 0.0
    var y: Double = 0.0

    /// Euclidean distance to another position.
    func distanceTo(_ other: Position) -> Double { ... }

    /// Integer grid cell coordinate.
    var gridPosition: GridPosition { ... }
}
```

#### Needs

```swift
struct Needs: Codable, Sendable {
    var hunger: Double = 100.0      // 0–100
    var thirst: Double = 100.0
    var energy: Double = 100.0
    var happiness: Double = 75.0
    var health: Double = 100.0
    var social: Double = 50.0
    var boredom: Double = 0.0       // 0 = not bored, 100 = very bored

    /// Clamp all values to 0.0–100.0.
    mutating func clampAll() { ... }
}
```

#### GuineaPig

```swift
struct GuineaPig: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String

    // Genetics
    var genotype: Genotype
    var phenotype: Phenotype

    // Demographics
    var gender: Gender
    var birthTime: Date
    var ageDays: Double = 0.0

    // Traits
    var personality: [Personality] = []

    // State
    var needs: Needs = Needs()
    var behaviorState: BehaviorState = .idle
    var position: Position = Position()

    // Movement
    var targetPosition: Position?
    var targetDescription: String?
    var targetFacilityId: UUID?
    var path: [GridPosition] = []

    // Breeding
    var isPregnant: Bool = false
    var pregnancyDays: Double = 0.0
    var partnerId: UUID?
    var partnerGenotype: Genotype?
    var partnerName: String?
    var lastBirthAge: Double?

    // Courtship
    var courtingPartnerId: UUID?
    var courtingInitiator: Bool = false
    var courtingTimer: Double = 0.0

    // Family
    var motherId: UUID?
    var fatherId: UUID?
    var motherName: String?
    var fatherName: String?

    // Breeding control
    var breedingLocked: Bool = false
    var markedForSale: Bool = false

    // Origin
    var originTag: String?

    // Area/biome tracking
    var currentAreaId: UUID?
    var birthAreaId: UUID?
    var preferredBiome: String?

    // Biome acclimation
    var acclimationTimer: Double = 0.0
    var acclimatingBiome: String?

    // Computed properties
    var ageGroup: AgeGroup { ... }
    var isBaby: Bool { ... }
    var isAdult: Bool { ... }
    var isSenior: Bool { ... }
    var canBreed: Bool { ... }
    var breedingBlockReason: String? { ... }
    var displayState: String { ... }

    func hasTrait(_ trait: Personality) -> Bool { ... }
    func getValue() -> Int { ... }

    /// Factory method with phenotype calculation and random personality.
    static func create(
        name: String,
        gender: Gender,
        genotype: Genotype?,
        position: Position?,
        ageDays: Double,
        motherId: UUID?,
        fatherId: UUID?,
        motherName: String?,
        fatherName: String?
    ) -> GuineaPig { ... }
}
```

### 4.4 `Facility.swift` (~250 lines)

**Maps from:** `entities/facilities.py` (363 lines)

#### FacilityType (corrected: 17 cases)

```swift
enum FacilityType: String, Codable, CaseIterable, Sendable {
    case foodBowl = "food_bowl"
    case waterBottle = "water_bottle"
    case hayRack = "hay_rack"
    case hideout
    case exerciseWheel = "exercise_wheel"
    case tunnel
    case playArea = "play_area"
    case breedingDen = "breeding_den"
    case nursery
    case veggieGarden = "veggie_garden"
    case groomingStation = "grooming_station"
    case geneticsLab = "genetics_lab"
    case feastTable = "feast_table"
    case campfire
    case therapyGarden = "therapy_garden"
    case hotSpring = "hot_spring"
    case stage

    var displayName: String { ... }
}
```

#### FacilitySize (corrected: struct, not enum)

```swift
struct FacilitySize: Codable, Sendable {
    let width: Int
    let height: Int
}
```

#### FacilityInfo (NEW)

```swift
struct FacilityInfo: Sendable {
    let name: String
    let size: FacilitySize
    let baseCost: Int
    let description: String
    let capacity: Int
    let refillCost: Int
    let healthBonus: Double
    let happinessBonus: Double
    let socialBonus: Double
    let breedingBonus: Double
    let growthBonus: Double
    let saleBonus: Double
    let foodProduction: Int
}
```

#### facilityInfo lookup table

```swift
let facilityInfo: [FacilityType: FacilityInfo] = [
    .foodBowl: FacilityInfo(name: "Food Bowl", size: FacilitySize(width: 2, height: 1),
                            baseCost: 20, description: "Provides food to reduce hunger",
                            capacity: 200, refillCost: 5, ...),
    .waterBottle: FacilityInfo(name: "Water Bottle", size: FacilitySize(width: 1, height: 2),
                               baseCost: 20, description: "Provides water for hydration",
                               capacity: 200, refillCost: 2, ...),
    // ... all 17 entries from FACILITY_INFO in Python
]
```

**All 17 facility sizes from Python source:**

| Facility | Width | Height | Capacity | Cost |
|----------|-------|--------|----------|------|
| Food Bowl | 2 | 1 | 200 | 20 |
| Water Bottle | 1 | 2 | 200 | 20 |
| Hay Rack | 2 | 1 | 200 | 80 |
| Hideout | 3 | 2 | 2 | 60 |
| Exercise Wheel | 2 | 2 | 2 | 150 |
| Tunnel | 3 | 1 | 3 | 200 |
| Play Area | 3 | 2 | 4 | 600 |
| Breeding Den | 2 | 2 | 0 | 3000 |
| Nursery | 3 | 2 | 4 | 5000 |
| Veggie Garden | 2 | 2 | 0 | 5000 |
| Grooming Station | 2 | 1 | 0 | 500 |
| Genetics Lab | 3 | 2 | 0 | 1000 |
| Feast Table | 5 | 5 | 300 | 350 |
| Campfire | 5 | 5 | 3 | 1200 |
| Therapy Garden | 5 | 5 | 2 | 1500 |
| Hot Spring | 6 | 6 | 4 | 15000 |
| Stage | 6 | 6 | 1 | 150000 |

#### Facility

```swift
struct Facility: Identifiable, Codable, Sendable {
    let id: UUID
    var facilityType: FacilityType
    var positionX: Int
    var positionY: Int
    var level: Int = 1
    let maxLevel: Int = 3

    // Resource state
    var currentAmount: Double = 100.0
    var maxAmount: Double = 100.0
    var autoRefill: Bool = false

    // Area tracking
    var areaId: UUID?

    // Computed properties
    var info: FacilityInfo { ... }
    var name: String { ... }
    var size: FacilitySize { ... }
    var width: Int { ... }
    var height: Int { ... }
    var cells: [GridPosition] { ... }
    var interactionPoint: GridPosition { ... }
    var interactionPoints: [GridPosition] { ... }
    var isEmpty: Bool { ... }
    var fillPercentage: Double { ... }

    mutating func consume(_ amount: Double) -> Double { ... }
    mutating func refill(_ amount: Double?) { ... }
    mutating func upgrade() -> Bool { ... }
    func getUpgradeCost() -> Int { ... }

    static func create(type: FacilityType, x: Int, y: Int) -> Facility { ... }

    enum CodingKeys: String, CodingKey {
        case id, facilityType = "facility_type"
        case positionX = "position_x", positionY = "position_y"
        case level, maxLevel = "max_level"
        case currentAmount = "current_amount", maxAmount = "max_amount"
        case autoRefill = "auto_refill", areaId = "area_id"
    }
}
```

### 4.5 `FarmArea.swift` (~80 lines)

**Maps from:** `entities/areas.py` (79 lines)

```swift
struct FarmArea: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var biome: BiomeType
    var x1: Int       // Top-left corner (inclusive, wall)
    var y1: Int
    var x2: Int       // Bottom-right corner (inclusive, wall)
    var y2: Int
    var isStarter: Bool = false
    var gridCol: Int = 0
    var gridRow: Int = 0

    // Computed interior bounds (inside walls)
    var interiorX1: Int { x1 + 1 }
    var interiorY1: Int { y1 + 1 }
    var interiorX2: Int { x2 - 1 }
    var interiorY2: Int { y2 - 1 }
    var interiorWidth: Int { interiorX2 - interiorX1 + 1 }
    var interiorHeight: Int { interiorY2 - interiorY1 + 1 }
    var centerX: Int { (x1 + x2) / 2 }
    var centerY: Int { (y1 + y2) / 2 }

    func contains(x: Int, y: Int) -> Bool { ... }
    func containsInterior(x: Int, y: Int) -> Bool { ... }

    enum CodingKeys: String, CodingKey {
        case id, name, biome, x1, y1, x2, y2
        case isStarter = "is_starter"
        case gridCol = "grid_col", gridRow = "grid_row"
    }
}

struct TunnelConnection: Identifiable, Codable, Sendable {
    let id: UUID
    var areaAId: UUID
    var areaBId: UUID
    var cells: [GridPosition] = []
    var orientation: String = "horizontal"

    enum CodingKeys: String, CodingKey {
        case id
        case areaAId = "area_a_id", areaBId = "area_b_id"
        case cells, orientation
    }
}
```

### 4.6 `BiomeType.swift` (~100 lines)

**Maps from:** `entities/biomes.py` (186 lines)

#### BiomeType (corrected)

```swift
enum BiomeType: String, Codable, CaseIterable, Sendable {
    case meadow, burrow, garden, tropical
    case alpine, crystal, wildflower, sanctuary
}
```

#### BiomeInfo (NEW)

Rendering fields (`floorChars`, `floorColors`, `floorBg`, `wallTint*`) are omitted — SpriteKit uses tile sets instead of terminal character rendering.

```swift
struct BiomeInfo: Sendable {
    let displayName: String
    let description: String
    let requiredTier: Int
    let cost: Int
    let mutationBoostLoci: [String: Double]
    let signatureColor: BaseColor?
    let directionalAlleles: [String: String]
    let happinessBonus: Double
}
```

#### biomes lookup table

```swift
let biomes: [BiomeType: BiomeInfo] = [
    .meadow: BiomeInfo(
        displayName: "Meadow",
        description: "Lush green grass — a natural home for guinea pigs",
        requiredTier: 1, cost: 0,
        mutationBoostLoci: [:],
        signatureColor: .black,
        directionalAlleles: ["eLocus": "E", "bLocus": "B", "dLocus": "D"],
        happinessBonus: 0.5
    ),
    .burrow: BiomeInfo(
        displayName: "Burrow",
        description: "Dark earthy tunnels — cozy and warm",
        requiredTier: 1, cost: 300,
        mutationBoostLoci: [:],
        signatureColor: .chocolate,
        directionalAlleles: ["eLocus": "E", "bLocus": "b", "dLocus": "D"],
        happinessBonus: 0.5
    ),
    .garden: BiomeInfo(
        displayName: "Garden",
        description: "A lush vegetable garden with rich soil",
        requiredTier: 2, cost: 600,
        mutationBoostLoci: [:],
        signatureColor: .golden,
        directionalAlleles: ["eLocus": "e", "bLocus": "B", "dLocus": "D"],
        happinessBonus: 0.8
    ),
    .tropical: BiomeInfo(
        displayName: "Tropical",
        description: "Warm and exotic — palm fronds and sandy floors",
        requiredTier: 2, cost: 800,
        mutationBoostLoci: ["sLocus": 0.08],
        signatureColor: .cream,
        directionalAlleles: ["eLocus": "e", "bLocus": "b", "dLocus": "D"],
        happinessBonus: 0.8
    ),
    .alpine: BiomeInfo(
        displayName: "Alpine",
        description: "Cool mountain rocks with grey-blue stone floors",
        requiredTier: 3, cost: 1200,
        mutationBoostLoci: ["cLocus": 0.08],
        signatureColor: .blue,
        directionalAlleles: ["eLocus": "E", "bLocus": "B", "dLocus": "d"],
        happinessBonus: 1.0
    ),
    .crystal: BiomeInfo(
        displayName: "Crystal Cave",
        description: "A mysterious cave with glowing purple crystals",
        requiredTier: 3, cost: 1500,
        mutationBoostLoci: ["rLocus": 0.08],
        signatureColor: .lilac,
        directionalAlleles: ["eLocus": "E", "bLocus": "b", "dLocus": "d"],
        happinessBonus: 1.0
    ),
    .wildflower: BiomeInfo(
        displayName: "Wildflower",
        description: "A colorful field bursting with wildflowers",
        requiredTier: 4, cost: 2000,
        mutationBoostLoci: ["sLocus": 0.05],
        signatureColor: .saffron,
        directionalAlleles: ["eLocus": "e", "bLocus": "B", "dLocus": "d"],
        happinessBonus: 1.2
    ),
    .sanctuary: BiomeInfo(
        displayName: "Sanctuary",
        description: "A golden temple of tranquility — all mutations enhanced",
        requiredTier: 5, cost: 3500,
        mutationBoostLoci: ["sLocus": 0.03, "cLocus": 0.03, "rLocus": 0.03],
        signatureColor: .smoke,
        directionalAlleles: ["eLocus": "e", "bLocus": "b", "dLocus": "d"],
        happinessBonus: 1.5
    ),
]
```

#### Helper lookups

```swift
/// Biome value string → signature BaseColor.
let biomeSignatureColors: [String: BaseColor] = ...

/// BaseColor → biome value string (reverse lookup).
let colorToBiome: [BaseColor: String] = ...
```

### 4.7 `Bloodline.swift` (~100 lines)

**Maps from:** `entities/bloodlines.py` (117 lines)

#### BloodlineType (corrected: 7 cases)

```swift
enum BloodlineType: String, Codable, CaseIterable, Sendable {
    case spotted
    case chocolate
    case golden
    case silver
    case roan
    case exoticSpotSilver = "exotic_spot_silver"
    case exoticRoanSilver = "exotic_roan_silver"
}
```

#### Bloodline (corrected: no UUID)

```swift
struct Bloodline: Codable, Sendable {
    let bloodlineType: BloodlineType    // This IS the identity
    let displayName: String
    let description: String
    let requiredTier: Int
    let costMultiplier: Double
    let locusOverrides: [String: AllelePair]

    func applyToGenotype(_ genotype: Genotype) -> Genotype { ... }

    enum CodingKeys: String, CodingKey {
        case bloodlineType = "bloodline_type"
        case displayName = "display_name"
        case description
        case requiredTier = "required_tier"
        case costMultiplier = "cost_multiplier"
        case locusOverrides = "locus_overrides"
    }
}
```

#### bloodlines lookup table

```swift
let bloodlines: [BloodlineType: Bloodline] = [
    .spotted: Bloodline(bloodlineType: .spotted, displayName: "Spotted Bloodline",
        description: "May produce offspring with unusual patterns",
        requiredTier: 1, costMultiplier: 1.5,
        locusOverrides: ["sLocus": AllelePair(first: "S", second: "s")]),
    .chocolate: Bloodline(..., requiredTier: 1, costMultiplier: 1.3,
        locusOverrides: ["bLocus": AllelePair(first: "B", second: "b")]),
    .golden: Bloodline(..., requiredTier: 2, costMultiplier: 1.8,
        locusOverrides: ["eLocus": AllelePair(first: "E", second: "e")]),
    .silver: Bloodline(..., requiredTier: 2, costMultiplier: 2.5,
        locusOverrides: ["cLocus": AllelePair(first: "C", second: "ch")]),
    .roan: Bloodline(..., requiredTier: 3, costMultiplier: 3.0,
        locusOverrides: ["rLocus": AllelePair(first: "R", second: "r")]),
    .exoticSpotSilver: Bloodline(..., requiredTier: 4, costMultiplier: 4.0,
        locusOverrides: ["sLocus": ..., "cLocus": ...]),
    .exoticRoanSilver: Bloodline(..., requiredTier: 4, costMultiplier: 5.0,
        locusOverrides: ["rLocus": ..., "cLocus": ...]),
]
```

#### Free functions

```swift
func getAvailableBloodlines(farmTier: Int) -> [Bloodline] { ... }
func generateBloodlinePigGenotype(_ bloodline: Bloodline) -> Genotype { ... }
func pickRandomBloodline(farmTier: Int) -> Bloodline? { ... }
```

### 4.8 `Pigdex.swift` (~120 lines)

**Maps from:** `entities/pigdex.py` (164 lines)

```swift
/// Total phenotype combinations: 8 × 3 × 3 × 2 = 144.
let totalPhenotypes = 144

let milestoneThresholds = [25, 50, 75, 100]

struct Pigdex: Codable, Sendable {
    var discovered: [String: Int] = [:]          // phenotypeKey → game day
    var milestoneRewardsClaimed: [Int] = []

    var totalPossible: Int { totalPhenotypes }
    var discoveredCount: Int { discovered.count }
    var completionPercent: Double { ... }

    mutating func registerPhenotype(key: String, gameDay: Int) -> Bool { ... }
    func checkMilestones() -> [Int] { ... }
    mutating func claimMilestone(_ threshold: Int) { ... }
    func isDiscovered(_ key: String) -> Bool { ... }

    enum CodingKeys: String, CodingKey {
        case discovered
        case milestoneRewardsClaimed = "milestone_rewards_claimed"
    }
}
```

#### Free functions

```swift
func phenotypeKey(_ phenotype: Phenotype) -> String { ... }
func phenotypeKeyFromParts(baseColor: BaseColor, pattern: Pattern,
                           intensity: ColorIntensity, roan: RoanType) -> String { ... }
func keyToDisplayName(_ key: String) -> String { ... }
func keyToRarity(_ key: String) -> Rarity { ... }
func getAllPhenotypeKeys() -> [String] { ... }
func getDiscoveryReward(_ rarity: Rarity) -> Int { ... }
func getMilestoneReward(_ threshold: Int) -> Int { ... }
```

---

## 5. Config/ — Detailed Specification

### 5.1 `GameConfig.swift` (~250 lines)

**Maps from:** `data/config.py` (lines 1–250)

All config constants live in caseless `enum` namespaces inside a top-level `GameConfig` enum. Values are `static let` properties copied exactly from the Python `@dataclass(frozen=True)` defaults.

```swift
enum GameConfig {
    enum Time {
        static let realSecondsPerGameMinute: Double = 0.1
        static let gameMinutesPerHour: Int = 60
        static let gameHoursPerDay: Int = 24
        static let dayStartHour: Int = 6
        static let nightStartHour: Int = 20
    }

    enum Needs {
        // Decay rates per game hour
        static let hungerDecay: Double = 0.6
        static let thirstDecay: Double = 0.8
        static let energyDecay: Double = 0.6
        // Thresholds
        static let criticalThreshold: Int = 20
        static let lowThreshold: Int = 40
        static let highThreshold: Int = 70
        static let satisfactionThreshold: Int = 90
        // Health
        static let healthDrainHunger: Double = 0.3
        static let healthDrainThirst: Double = 0.5
        static let healthPassiveRecovery: Double = 1.0
        static let healthSleepRecovery: Double = 1.5
        // Recovery amounts
        static let foodRecovery: Double = 40.0
        static let waterRecovery: Double = 50.0
        static let sleepRecoveryPerHour: Double = 25.0
        static let playHappinessBoost: Double = 15.0
        static let socialHappinessBoost: Double = 10.0
        // Boredom
        static let boredomDecay: Double = 2.0
        static let boredomExtraHappinessThreshold: Int = 70
        static let boredomExtraHappinessDrain: Double = 1.0
        static let boredomPlayRecovery: Double = 15.0
        static let playEnergyCost: Double = 1.0
        static let socialRecovery: Double = 10.0
        // Social
        static let socialRadius: Double = 8.0
        static let socialBoostPerPig: Double = 3.0
        static let socialBoostCap: Double = 8.0
        static let socialDecayWithPigs: Double = 0.5
        static let socialDecayAlone: Double = 2.0
        // Happiness
        static let eatingHappinessBoost: Double = 2.0
        static let happinessContentmentRecovery: Double = 2.0
        static let hungerHappinessDrain: Double = 2.0
        static let thirstHappinessDrain: Double = 2.5
        static let energyHappinessDrain: Double = 1.5
        // Personality modifiers
        static let greedyHungerMult: Double = 1.5
        static let lazyEnergyMult: Double = 0.7
        static let playfulBoredomMult: Double = 1.5
        static let socialSocialMult: Double = 1.3
        static let shySocialMult: Double = 0.5
        // Wellbeing weights
        static let wellbeingHungerWeight: Double = 0.25
        static let wellbeingThirstWeight: Double = 0.25
        static let wellbeingEnergyWeight: Double = 0.15
        static let wellbeingHappinessWeight: Double = 0.20
        static let wellbeingHealthWeight: Double = 0.15
    }

    enum Breeding {
        static let minHappinessToBreed: Int = 70
        static let minAgeDays: Int = 3
        static let maxAgeDays: Int = 30
        static let gestationDays: Int = 2
        static let minLitterSize: Int = 1
        static let maxLitterSize: Int = 4
        static let recoveryDays: Int = 2
        static let breedingDistance: Double = 3.0
        static let baseBreedingChance: Double = 0.05
        static let breedingDenBonus: Double = 0.10
        static let highHappinessThreshold: Int = 80
        static let highHappinessBonus: Double = 0.05
        static let oldAgeDeathRate: Double = 0.1
        static let minBreedingPopulation: Int = 2
        static let affinityWeight: Double = 0.01
        static let maxAffinitySelectionBonus: Double = 0.05
        static let affinityChanceBonus: Double = 0.01
        static let maxAffinityChanceBonus: Double = 0.05
    }

    enum Economy {
        static let startingMoney: Int = 100
        static let startingPigs: Int = 2
        static let commonPigValue: Int = 25
        static let uncommonMultiplier: Double = 1.5
        static let rareMultiplier: Double = 2.5
        static let veryRareMultiplier: Double = 4.0
        static let legendaryMultiplier: Double = 10.0
        // Facility costs (all 17)
        static let foodBowlCost: Int = 20
        static let waterBottleCost: Int = 20
        static let hideoutCost: Int = 60
        static let hayRackCost: Int = 80
        static let exerciseWheelCost: Int = 150
        static let tunnelCost: Int = 200
        static let feastTableCost: Int = 350
        static let groomingStationCost: Int = 500
        static let playAreaCost: Int = 600
        static let geneticsLabCost: Int = 1000
        static let campfireCost: Int = 1200
        static let therapyGardenCost: Int = 1500
        static let breedingDenCost: Int = 3000
        static let nurseryCost: Int = 5000
        static let veggieGardenCost: Int = 5000
        static let hotSpringCost: Int = 15000
        static let stageCost: Int = 150000
    }

    enum Simulation {
        static let ticksPerSecond: Int = 10
        static let baseMoveSpeed: Double = 1.0
        static let maxPathfindingIterations: Int = 1500
        static let decisionIntervalSeconds: Double = 2.0
        static let babyAgeDays: Int = 0
        static let adultAgeDays: Int = 3
        static let seniorAgeDays: Int = 30
        static let maxAgeDays: Int = 45
    }

    enum Genetics {
        static let mutationRate: Double = 0.02
        static let mutationRateWithLab: Double = 0.03
        static let directionalMutationRate: Double = 0.06
        static let directionalMutationRateWithLab: Double = 0.09
    }

    enum Bloodline {
        static let bloodlinePigChance: Double = 0.5
        static let adoptionRefreshDays: Int = 5
    }

    enum Pigdex {
        static let commonReward: Int = 10
        static let uncommonReward: Int = 20
        static let rareReward: Int = 35
        static let veryRareReward: Int = 50
        static let legendaryReward: Int = 100
        static let milestone25Reward: Int = 250
        static let milestone50Reward: Int = 750
        static let milestone75Reward: Int = 2000
        static let milestone100Reward: Int = 10000
    }

    enum Contracts {
        static let maxActiveContracts: Int = 4
        static let refreshIntervalDays: Int = 10
        static let expiryDays: Int = 20
        static let easyRewardMin: Int = 500
        static let easyRewardMax: Int = 1000
        static let mediumRewardMin: Int = 2000
        static let mediumRewardMax: Int = 4000
        static let hardRewardMin: Int = 5000
        static let hardRewardMax: Int = 10000
        static let expertRewardMin: Int = 12000
        static let expertRewardMax: Int = 20000
        static let legendaryRewardMin: Int = 20000
        static let legendaryRewardMax: Int = 40000
    }

    enum Biome {
        static let preferredBiomeHappinessBonus: Double = 1.5
        static let biomeMutationBoost: Double = 0.08
        static let biomeContractRewardBonus: Double = 0.50
        static let biomeContractChance: Double = 0.3
        static let acclimationDays: Double = 3.0
        static let colorMatchAffinityReduction: Double = 0.6
        static let colorMatchAcclimationMultiplier: Double = 0.5
    }

    enum FacilityInteraction {
        static let adjacencyDistance: Int = 1
        static let defaultHideoutCapacity: Int = 2
    }

    enum AutoArrange {
        static let horizontalGap: Int = 2
        static let verticalGap: Int = 3
        static let zoneMargin: Int = 1
        static let smallFarmThresholdW: Int = 70
        static let smallFarmThresholdH: Int = 35
        static let smallHorizontalGap: Int = 1
        static let smallVerticalGap: Int = 2
        static let neighborhoodUtilityFraction: Double = 0.2
        static let maxNeighborhoods: Int = 4
    }
}
```

### 5.2 `GameConfigBehavior.swift` (~150 lines) — NEW FILE

Split from `GameConfig.swift` to stay under 300 lines. Contains ~50 behavior AI constants.

```swift
extension GameConfig {
    enum Behavior {
        // Separation thresholds
        static let separationBothMoving: Double = 1.0
        static let separationOneMoving: Double = 2.0
        static let minPigDistance: Double = 3.0
        // Movement blocking
        static let blockingDefault: Double = 2.5
        static let blockingBothMoving: Double = 1.5
        static let blockingFacilityUse: Double = 1.5
        static let separationFacilityUse: Double = 1.0
        // Facility interaction
        static let occupancyRadius: Double = 2.0
        static let facilityNearbyRadius: Double = 6.0
        static let facilityHeadingRadius: Double = 3.0
        static let crowdingPenalty: Double = 25.0
        static let facilityDistanceWeight: Double = 2.0
        static let scoringRandomVariance: Double = 3.0
        static let uncrowdedChance: Double = 0.3
        // Blocked behavior
        static let blockedTimeAlternative: Double = 2.0
        static let blockedTimeGiveUp: Double = 5.0
        static let failedCooldownCycles: Int = 3
        // Decision thresholds
        static let energySleepThreshold: Int = 40
        static let emergencyWakeEnergy: Int = 15
        static let boredomPlayThreshold: Int = 30
        static let boredomKeepPlaying: Int = 20
        // Resource consumption
        static let resourceConsumeRate: Double = 0.15
        static let facilityBonusScale: Double = 10.0
        // Personality probabilities
        static let lazySleepChance: Double = 0.3
        static let playfulPlayChance: Double = 0.4
        static let socialSocializeChance: Double = 0.3
        static let wanderChance: Double = 0.8
        static let noPlayFacilityPlayChance: Double = 0.1
        // Wandering
        static let wanderAttempts: Int = 8
        static let wanderMaxDistance: Int = 30
        static let wanderDensityRadius: Double = 10.0
        static let wanderDensityPenalty: Double = 2.0
        static let simpleWanderMinSteps: Int = 6
        static let simpleWanderMaxSteps: Int = 14
        // Pathfinding limits
        static let maxFacilityPathfindDistance: Int = 100
        static let maxFacilityCandidates: Int = 4
        static let straightLineMaxDistance: Int = 6
        // Content pig throttle
        static let contentDecisionInterval: Double = 8.0
        // Critical retry
        static let criticalFailedCooldownCycles: Int = 1
        // Unreachable backoff
        static let unreachableBackoffCycles: Int = 5
        static let unreachableCriticalCycles: Int = 2
        // Biome affinity
        static let biomeAffinityPenalty: Double = 30.0
        // Room overcrowding
        static let roomOvercrowdingPenalty: Double = 10.0
        // Idle drift
        static let idleDriftRadius: Double = 5.0
        // Biome-aware wandering
        static let biomeWanderBiasOutside: Double = 3.0
        static let biomeWanderBiasInside: Double = 1.5
        static let biomeHomingChance: Double = 0.7
        // Courtship
        static let courtshipTogetherSeconds: Double = 4.0
        static let courtshipHappinessBoost: Double = 5.0
        // Movement modifiers
        static let tiredSpeedMult: Double = 0.5
        static let babySpeedMult: Double = 0.7
        static let dodgeMaxStep: Double = 1.0
        static let waypointReached: Double = 0.1
        // Overlap handling
        static let overlapEpsilon: Double = 0.01
        static let separationPadding: Double = 0.1
        static let pathVectorEpsilon: Double = 0.01
    }
}
```

### 5.3 `GameConfigTiers.swift` (~130 lines) — NEW FILE

Split from `GameConfig.swift`. Contains tier/room definitions and `GameSpeed`.

```swift
enum GameSpeed: Int, Codable, CaseIterable, Sendable {
    case paused = 0
    case normal = 3
    case fast = 6
    case faster = 15
    case fastest = 60
    case debug = 300
    case debugFast = 900

    var displayLabel: String {
        switch self {
        case .paused: "0x"
        case .normal: "1x"
        case .fast: "2x"
        case .faster: "5x"
        case .fastest: "20x"
        case .debug: "100x"
        case .debugFast: "300x"
        }
    }
}

struct TierUpgrade: Codable, Sendable {
    let name: String
    let tier: Int
    let cost: Int
    let requiredPigsBorn: Int
    let requiredPigdex: Int
    let requiredContracts: Int
    let maxRooms: Int
    let roomWidth: Int
    let roomHeight: Int
    let capacityPerRoom: Int
}

let tierUpgrades: [TierUpgrade] = [
    TierUpgrade(name: "Starter",      tier: 1, cost: 0,     requiredPigsBorn: 0,  requiredPigdex: 0,  requiredContracts: 0,  maxRooms: 1, roomWidth: 62, roomHeight: 37, capacityPerRoom: 8),
    TierUpgrade(name: "Apprentice",   tier: 2, cost: 300,   requiredPigsBorn: 3,  requiredPigdex: 2,  requiredContracts: 0,  maxRooms: 2, roomWidth: 68, roomHeight: 40, capacityPerRoom: 10),
    TierUpgrade(name: "Expert",       tier: 3, cost: 1500,  requiredPigsBorn: 10, requiredPigdex: 8,  requiredContracts: 2,  maxRooms: 3, roomWidth: 76, roomHeight: 44, capacityPerRoom: 14),
    TierUpgrade(name: "Master",       tier: 4, cost: 5000,  requiredPigsBorn: 25, requiredPigdex: 18, requiredContracts: 5,  maxRooms: 6, roomWidth: 86, roomHeight: 50, capacityPerRoom: 18),
    TierUpgrade(name: "Grand Master", tier: 5, cost: 15000, requiredPigsBorn: 50, requiredPigdex: 30, requiredContracts: 10, maxRooms: 8, roomWidth: 96, roomHeight: 56, capacityPerRoom: 24),
]

func getTierUpgrade(tier: Int) -> TierUpgrade {
    tierUpgrades.first { $0.tier == tier } ?? tierUpgrades[0]
}

struct RoomCost: Codable, Sendable {
    let name: String
    let cost: Int
}

let roomCosts: [RoomCost] = [
    RoomCost(name: "Starter Hutch",      cost: 0),
    RoomCost(name: "Cozy Enclosure",     cost: 500),
    RoomCost(name: "Family Pen",         cost: 2000),
    RoomCost(name: "Guinea Grove",       cost: 8000),
    RoomCost(name: "Piggy Paradise",     cost: 25000),
    RoomCost(name: "Ultimate Farm",      cost: 100000),
    RoomCost(name: "Grand Estate",       cost: 300000),
    RoomCost(name: "Pig Empire",         cost: 800000),
]
```

### 5.4 `PigNames.swift` (~120 lines)

**Maps from:** `data/names.py` (121 lines)

```swift
enum PigNames {
    static let malePrefixes = ["Sir", "Mr.", "Duke", "Lord", "Baron", "Count", "King", "Prince"]
    static let femalePrefixes = ["Lady", "Ms.", "Princess", "Queen", "Duchess", "Baroness", "Countess"]
    static let neutralPrefixes = ["Professor", "Captain", "Dr.", "Chief"]

    static let cuteNames: [String] = [
        "Squeaky", "Patches", "Peanut", "Cinnamon", "Nutmeg", "Cookie", "Biscuit",
        "Caramel", "Mocha", "Cocoa", "Oreo", "Brownie", "Muffin", "Cupcake",
        "Butterscotch", "Toffee", "Marshmallow", "Ginger", "Pepper", "Clover",
        "Daisy", "Poppy", "Rosie", "Willow", "Maple", "Hazel", "Olive", "Basil",
        "Sage", "Thyme", "Parsley", "Mint", "Peaches", "Apricot", "Plum", "Cherry",
        "Mango", "Kiwi", "Coconut", "Almond", "Walnut", "Cashew", "Pistachio",
        "Pretzel", "Crumble", "Fudge", "Truffle", "Pudding", "Custard", "Waffle",
        "Pancake", "Noodle", "Dumpling", "Tofu", "Mochi", "Boba", "Sushi",
    ]

    static let foodNames: [String] = [ /* 20 names from Python */ ]
    static let colorNames: [String] = [ /* 31 names from Python */ ]
    static let personalityNames: [String] = [ /* 26 names from Python */ ]
    static let famousNames: [String] = [ /* 18 names from Python */ ]
    static let suffixes: [String] = [ /* 10 suffixes from Python */ ]

    static let allNames: [String] = cuteNames + foodNames + colorNames + personalityNames + famousNames

    /// Generate a random pig name with optional title and suffix.
    static func generateName(includeTitle: Bool = false, includeSuffix: Bool = false,
                             gender: Gender? = nil) -> String { ... }

    /// Generate a unique name not in the given set.
    static func generateUniqueName(existingNames: Set<String>,
                                   gender: Gender? = nil,
                                   maxAttempts: Int = 100) -> String { ... }
}
```

---

## 6. Engine/Economy/Simulation Data Types

These are data-only additions to existing stubs. Game logic (methods that mutate state, orchestrate ticks, etc.) is out of scope for Doc 02 — it belongs in Doc 04.

### 6.1 `Engine/GameState.swift` — Data types only

Add these structs to the file. The `GameState` class itself (properties and methods) is Doc 04 scope.

```swift
struct GameTime: Codable, Sendable {
    var day: Int = 1
    var hour: Int = 8
    var minute: Int = 0
    var lastUpdate: Date = Date()
    var totalGameMinutes: Double = 0.0

    var isDaytime: Bool { 6 <= hour && hour < 20 }
    var timeOfDay: String { ... }
    var displayTime: String { ... }

    mutating func advance(minutes: Double) { ... }

    enum CodingKeys: String, CodingKey {
        case day, hour, minute
        case lastUpdate = "last_update"
        case totalGameMinutes = "total_game_minutes"
    }
}

struct EventLog: Codable, Sendable {
    let timestamp: Date
    let gameDay: Int
    let message: String
    let eventType: String   // "info", "birth", "death", "sale", "purchase"

    enum CodingKeys: String, CodingKey {
        case timestamp
        case gameDay = "game_day"
        case message
        case eventType = "event_type"
    }
}

struct BreedingPair: Codable, Sendable {
    let maleId: UUID
    let femaleId: UUID

    enum CodingKeys: String, CodingKey {
        case maleId = "male_id"
        case femaleId = "female_id"
    }
}
```

### 6.2 `Engine/FarmGrid.swift` — Corrected CellType + Cell

```swift
enum CellType: String, Codable, CaseIterable, Sendable {
    case floor, bedding, grass, wall     // NOT empty/facility/tunnel
}

struct Cell: Codable, Sendable {
    var cellType: CellType = .floor
    var facilityId: UUID?
    var isWalkable: Bool = true
    var areaId: UUID?
    var isTunnel: Bool = false
    var isCorner: Bool = false
    var isHorizontalWall: Bool = false

    enum CodingKeys: String, CodingKey {
        case cellType = "cell_type"
        case facilityId = "facility_id"
        case isWalkable = "is_walkable"
        case areaId = "area_id"
        case isTunnel = "is_tunnel"
        case isCorner = "is_corner"
        case isHorizontalWall = "is_horizontal_wall"
    }
}
```

### 6.3 `Economy/Contracts.swift` — Data types

```swift
enum ContractDifficulty: String, Codable, CaseIterable, Sendable {
    case easy, medium, hard, expert, legendary
}

struct BreedingContract: Identifiable, Codable, Sendable {
    let id: UUID
    var description: String = ""
    var requiredColor: BaseColor?
    var requiredPattern: Pattern?
    var requiredIntensity: ColorIntensity?
    var requiredRoan: RoanType?
    var requiredBiome: BiomeType?
    var difficulty: ContractDifficulty = .easy
    var reward: Int = 50
    var deadlineDay: Int = 0
    var createdDay: Int = 0
    var fulfilled: Bool = false

    func matchesPig(_ pig: GuineaPig, farm: FarmGrid?) -> Bool { ... }
    var breedingHint: String { ... }
    var requirementsText: String { ... }
}

struct ContractBoard: Codable, Sendable {
    var activeContracts: [BreedingContract] = []
    var completedContracts: Int = 0
    var totalContractEarnings: Int = 0
    var lastRefreshDay: Int = 0

    mutating func checkAndFulfill(_ pig: GuineaPig, farm: FarmGrid?) -> BreedingContract? { ... }
    mutating func removeFulfilled() { ... }
    mutating func checkExpiry(gameDay: Int) -> [BreedingContract] { ... }
    func needsRefresh(gameDay: Int) -> Bool { ... }
}
```

### 6.4 `Economy/Shop.swift` — Data types

```swift
enum ShopCategory: String, Codable, CaseIterable, Sendable {
    case facilities, perks, upgrades, decorations, adoption
}

struct ShopItem: Sendable {
    let id: String
    let name: String
    let description: String
    let cost: Int
    let category: ShopCategory
    let facilityType: FacilityType?
    var unlocked: Bool = true
    let requiredTier: Int
}

/// All 17 shop items. Populated from SHOP_ITEMS in Python.
let shopItems: [ShopItem] = [ /* 17 facility entries */ ]
```

### 6.5 `Economy/Upgrades.swift` — Data types

```swift
struct UpgradeDefinition: Sendable {
    let id: String
    let name: String
    let description: String
    let cost: Int
    let requiredTier: Int
    let category: String
    let implemented: Bool
}

/// All 24 upgrade definitions, keyed by ID.
let upgrades: [String: UpgradeDefinition] = [
    // Automation (3)
    "bulk_feeders":        UpgradeDefinition(id: "bulk_feeders", name: "Bulk Feeders", description: "All food/water facility capacity doubled.", cost: 350, requiredTier: 2, category: "Automation", implemented: true),
    "drip_system":         UpgradeDefinition(..., cost: 1800, requiredTier: 3, ...),
    "auto_feeders":        UpgradeDefinition(..., cost: 6000, requiredTier: 4, ...),
    // Breeding (4)
    "fertility_herbs":     UpgradeDefinition(..., cost: 400, requiredTier: 2, ...),
    "breeding_insight":    UpgradeDefinition(..., cost: 1200, requiredTier: 3, implemented: false),
    "litter_boost":        UpgradeDefinition(..., cost: 7000, requiredTier: 4, ...),
    "genetic_accelerator": UpgradeDefinition(..., cost: 20000, requiredTier: 5, ...),
    // Comfort (4)
    "premium_bedding":     UpgradeDefinition(..., cost: 250, requiredTier: 2, ...),
    "enrichment_program":  UpgradeDefinition(..., cost: 1000, requiredTier: 3, ...),
    "climate_control":     UpgradeDefinition(..., cost: 2000, requiredTier: 3, ...),
    "pig_spa":             UpgradeDefinition(..., cost: 5000, requiredTier: 4, ...),
    // Economy (4)
    "market_connections":  UpgradeDefinition(..., cost: 500, requiredTier: 2, ...),
    "premium_branding":    UpgradeDefinition(..., cost: 2500, requiredTier: 3, ...),
    "trade_network":       UpgradeDefinition(..., cost: 8000, requiredTier: 4, ...),
    "influencer_pig":      UpgradeDefinition(..., cost: 25000, requiredTier: 5, ...),
    // Movement (2)
    "paved_paths":         UpgradeDefinition(..., cost: 300, requiredTier: 2, ...),
    "express_lanes":       UpgradeDefinition(..., cost: 4000, requiredTier: 4, ...),
    // Quality of Life (7)
    "farm_bell":           UpgradeDefinition(..., cost: 200, requiredTier: 2, ...),
    "adoption_discount":   UpgradeDefinition(..., cost: 300, requiredTier: 2, ...),
    "speed_breeding":      UpgradeDefinition(..., cost: 1500, requiredTier: 3, ...),
    "contract_negotiator": UpgradeDefinition(..., cost: 1200, requiredTier: 3, ...),
    "lucky_clover":        UpgradeDefinition(..., cost: 5000, requiredTier: 4, ...),
    "vip_contracts":       UpgradeDefinition(..., cost: 15000, requiredTier: 5, ...),
    "talent_scout":        UpgradeDefinition(..., cost: 1500, requiredTier: 3, implemented: false),
]
```

### 6.6 `Economy/Market.swift` — Data types

```swift
struct SaleResult: Sendable {
    let baseValue: Int
    let contractBonus: Int
    let matchedContract: BreedingContract?

    var total: Int { baseValue + contractBonus }
}
```

### 6.7 `Economy/Currency.swift` — Functions

```swift
enum Currency {
    /// Format number for display: "1.5K", "2.3M", or plain number.
    static func formatMoney(_ amount: Int) -> String { ... }

    /// Format with "Sq" prefix: "Sq1.5K".
    static func formatCurrency(_ amount: Int) -> String { ... }
}
```

### 6.8 `Simulation/BreedingProgram.swift` — Data types

```swift
enum BreedingStrategy: String, Codable, CaseIterable, Sendable {
    case target      // Breed toward phenotype targets
    case diversity   // Maximize variety
    case money       // Maximize sale value
}

struct BreedingProgram: Codable, Sendable {
    var targetColors: Set<BaseColor> = []
    var targetPatterns: Set<Pattern> = []
    var targetIntensities: Set<ColorIntensity> = []
    var targetRoan: Set<RoanType> = []
    var keepCarriers: Bool = true
    var autoPair: Bool = true
    var strategy: BreedingStrategy = .target
    var stockLimit: Int = 6
    var enabled: Bool = false

    var hasTarget: Bool { ... }
    func shouldAutoPair() -> Bool { ... }

    enum CodingKeys: String, CodingKey {
        case targetColors = "target_colors"
        case targetPatterns = "target_patterns"
        case targetIntensities = "target_intensities"
        case targetRoan = "target_roan"
        case keepCarriers = "keep_carriers"
        case autoPair = "auto_pair"
        case strategy, stockLimit = "stock_limit", enabled
    }
}
```

---

## 7. New Files Required

| File | Purpose | Approx Lines |
|------|---------|------|
| `Models/GridPosition.swift` | Shared grid coordinate struct | 30 |
| `Models/GeneticsBreeding.swift` | Breeding, mutations, prediction functions | 200 |
| `Config/GameConfigBehavior.swift` | 50+ behavior AI constants (extension of GameConfig) | 150 |
| `Config/GameConfigTiers.swift` | GameSpeed, TierUpgrade, RoomCost + data tables | 130 |

### `Models/GridPosition.swift`

```swift
/// Integer grid coordinate, replacing Python's tuple[int, int].
struct GridPosition: Codable, Sendable, Hashable {
    let x: Int
    let y: Int

    /// Manhattan distance to another grid position.
    func manhattanDistance(to other: GridPosition) -> Int {
        abs(x - other.x) + abs(y - other.y)
    }
}
```

After adding new files, run `xcodegen generate` to regenerate the project.

---

## 8. Testing Plan

All tests use Swift Testing framework (`@Test`, `#expect`).

### 8.1 `GeneticsTests.swift`

| Test | What It Verifies |
|------|-----------------|
| `testPhenotypeFromGenotype` | Each E/B/D combination → correct BaseColor |
| `testPatternFromSLocus` | SS=solid, Ss=dutch, ss=dalmatian |
| `testIntensityFromCLocus` | CC=full, Cch=chinchilla, chch=himalayan |
| `testRoanFromRLocus` | R present=roan, rr=none |
| `testRarityCalculation` | Point totals → correct Rarity tier |
| `testLethalRRReroll` | RR genotype never produced by `breed()` |
| `testBreedInheritance` | Alleles come from parents |
| `testMutationRate` | ~2% mutations over 10,000 breeds |
| `testDirectionalMutation` | Biome-targeted mutations push correct direction |
| `testCarrierSummary` | Heterozygous loci correctly listed |
| `testPredictOffspring` | Monte Carlo probabilities sum to ~1.0 |
| `testTargetProbability` | Analytical matches Monte Carlo within 5% |

### 8.2 `ConfigTests.swift`

| Test | What It Verifies |
|------|-----------------|
| `testTimingDefaults` | `ticksPerSecond == 10` |
| `testNeedsThresholds` | `critical < low < high < satisfaction` |
| `testBreedingAgeRange` | `minAgeDays < maxAgeDays < maxAge` |
| `testEconomyValues` | `startingMoney > 0`, multipliers ordered |
| `testTierUpgradeProgression` | Tiers increase in cost and requirements |
| `testRoomCosts` | Costs strictly increase |
| `testGameSpeedValues` | All 7 speeds have correct raw values |
| `testBiomeInfoComplete` | All 8 BiomeTypes have entries in `biomes` |
| `testFacilityInfoComplete` | All 17 FacilityTypes have entries |
| `testBloodlineComplete` | All 7 BloodlineTypes have entries |

### 8.3 `ModelTests.swift`

| Test | What It Verifies |
|------|-----------------|
| `testPositionDistance` | Euclidean distance calculation |
| `testPositionGridPos` | Double→Int grid conversion |
| `testNeedsClamping` | Values stay in 0–100 range |
| `testAgeGroups` | Days→AgeGroup thresholds correct |
| `testFacilityCells` | Cells computed from position + size |
| `testFacilityInteractionPoint` | Correct front-center cell |
| `testAllelePairContains` | Contains/count/homozygous methods |
| `testGridPositionManhattan` | Manhattan distance |
| `testPigdexMilestones` | Milestone thresholds at 25/50/75/100% |
| `testFarmAreaInterior` | Interior bounds = wall bounds ± 1 |
| `testBreedingProgram` | hasTarget, shouldAutoPair logic |

### 8.4 `PigNamesTests.swift`

| Test | What It Verifies |
|------|-----------------|
| `testNameGeneration` | Returns non-empty string |
| `testUniqueNameGeneration` | 100 names are all unique |
| `testAllNamesArray` | Combined array = sum of sub-arrays |
| `testGenderPrefixes` | Male/female prefixes are distinct sets |

---

## 9. Implementation Order

Dependency-ordered sequence. Each step should compile and all prior tests pass.

| Step | File(s) | Depends On | Notes |
|------|---------|-----------|-------|
| 1 | `GridPosition.swift` | — | New file, no dependencies |
| 2 | `Genetics.swift` (enums only) | — | 6 corrected enums + `AllelePair` |
| 3 | `Genetics.swift` (structs) | Step 2 | `Genotype`, `Phenotype`, `calculatePhenotype`, `calculateRarity` |
| 4 | `GeneticsBreeding.swift` | Step 3 | `breed()`, mutations, predictions |
| 5 | `GuineaPig.swift` | Steps 2-3 | Corrected enums, `Position`, `Needs`, `GuineaPig` |
| 6 | `Facility.swift` | Step 1 | `FacilityType`, `FacilitySize`, `FacilityInfo`, `Facility` |
| 7 | `BiomeType.swift` | Step 2 | Corrected enum, `BiomeInfo`, `biomes` table |
| 8 | `Bloodline.swift` | Steps 2-3 | Corrected types, `bloodlines` table |
| 9 | `Pigdex.swift` | Steps 2-3 | `Pigdex` struct + free functions |
| 10 | `FarmArea.swift` | Step 1 | `FarmArea`, `TunnelConnection` |
| 11 | `GameConfigTiers.swift` | — | New file: `GameSpeed`, `TierUpgrade`, `RoomCost` |
| 12 | `GameConfig.swift` | — | All config namespaces except Behavior |
| 13 | `GameConfigBehavior.swift` | — | New file: `Behavior` extension |
| 14 | `PigNames.swift` | Step 5 | Name arrays + generation functions |
| 15 | `FarmGrid.swift` (data types) | Steps 1, 10 | Corrected `CellType`, `Cell` |
| 16 | `GameState.swift` (data types) | Steps 5, 9, 11 | `GameTime`, `EventLog`, `BreedingPair` |
| 17 | `Contracts.swift` (data types) | Steps 2, 7 | `ContractDifficulty`, `BreedingContract`, `ContractBoard` |
| 18 | `Economy stubs` | Steps 6, 17 | `ShopItem`, `UpgradeDefinition`, `SaleResult`, `Currency` |
| 19 | `BreedingProgram.swift` | Step 2 | `BreedingStrategy`, `BreedingProgram` |

After all steps: run `xcodegen generate`, then run all tests.

---

## 10. Dependencies — What Doc 02 Enables

| Downstream Doc | What It Gets From Doc 02 |
|----------------|--------------------------|
| **04 — Game Engine** | `GameState` fields, `FarmGrid`/`Cell`, `GameTime`, pathfinding types, economy data types |
| **05 — Behavior AI** | `BehaviorState`, `Personality`, `Needs`, `Position`, all `GameConfig.Behavior` constants |
| **06 — Farm Scene** | `BiomeType`, `FacilityType`, `FacilitySize`, `CellType`, `Position`, pig/facility structs for rendering |
| **07 — SwiftUI Screens** | `ShopItem`, `UpgradeDefinition`, `BreedingContract`, `Pigdex`, `Bloodline`, `Currency` |
| **08 — Persistence** | All `Codable` conformances, `CodingKeys` with snake_case mapping |

Doc 02 is the foundation layer — every other doc depends on the types defined here. Getting these right means the rest of the implementation is straightforward translation of game logic.
