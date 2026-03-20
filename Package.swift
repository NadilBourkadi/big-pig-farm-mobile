// swift-tools-version: 6.0
import PackageDescription

/// BigPigFarmCore — platform-agnostic game logic extracted for fast testing.
///
/// This package compiles the subset of source files that have zero UIKit/SpriteKit/SwiftUI
/// dependencies. Tests run via `swift test` on macOS without a simulator (~1s vs ~30s).
///
/// The Xcode project (project.yml) continues to compile ALL source files as the `BigPigFarm`
/// module — this package is a parallel build system, not a replacement.
let package = Package(
    name: "BigPigFarmCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BigPigFarmCore", targets: ["BigPigFarmCore"]),
    ],
    targets: [
        .target(
            name: "BigPigFarmCore",
            path: "BigPigFarm",
            sources: [
                // Config (4 of 6 — PigPalettes + UIColorHex need UIKit)
                "Config/GameConfig.swift",
                "Config/GameConfigBehavior.swift",
                "Config/GameConfigTiers.swift",
                "Config/PigNames.swift",
                // Economy (all 6)
                "Economy",
                // Engine (14 of 15 — HapticManager needs UIKit)
                "Engine/AreaManager.swift",
                "Engine/AutoArrange.swift",
                "Engine/AutoArrangeLayout.swift",
                "Engine/FarmGrid.swift",
                "Engine/GameEngine.swift",
                "Engine/GameState.swift",
                "Engine/GameState+Codable.swift",
                "Engine/GridExpansion.swift",
                "Engine/NotificationManager.swift",
                "Engine/Pathfinding.swift",
                "Engine/Protocols.swift",
                "Engine/SaveManager.swift",
                "Engine/SaveMigration.swift",
                "Engine/Tunnels.swift",
                // Models (18 of 19 — NotificationCategory+Color needs SwiftUI)
                "Models/BiomeType.swift",
                "Models/Bloodline.swift",
                "Models/BreedingPair.swift",
                "Models/EventLog.swift",
                "Models/Facility.swift",
                "Models/FarmArea.swift",
                "Models/GameTime.swift",
                "Models/Genetics.swift",
                "Models/GeneticsBreeding.swift",
                "Models/GeneticsPrediction.swift",
                "Models/GridPosition.swift",
                "Models/GuineaPig.swift",
                "Models/NotificationCategory.swift",
                "Models/NotificationPreferences.swift",
                "Models/NotificationPreset.swift",
                "Models/Pigdex.swift",
                "Models/PigPair.swift",
                "Models/SpriteTypes.swift",
                "Models/ToastItem.swift",
                // Scene (2 of 15 — only platform-agnostic data files)
                "Scene/AnimationData.swift",
                "Scene/SpriteFurMaps.swift",
                // Simulation (all 23)
                "Simulation",
            ]
        ),
        .testTarget(
            name: "BigPigFarmCoreTests",
            dependencies: ["BigPigFarmCore"],
            path: "BigPigFarmCoreTests"
        ),
    ]
)
