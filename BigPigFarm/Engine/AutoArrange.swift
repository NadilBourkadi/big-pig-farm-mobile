/// AutoArrange — Zone-based automatic facility layout with shelf packing.
/// Maps from: game/auto_arrange.py
import Foundation

// MARK: - Zone

/// A rectangular area within the farm used to group facilities by category.
struct Zone: Sendable {
    let name: String
    let x1: Int
    let y1: Int
    let x2: Int
    let y2: Int
    var width: Int { x2 - x1 + 1 }
    var height: Int { y2 - y1 + 1 }
}

// MARK: - Placement

/// A computed destination for a facility during auto-arrange.
struct Placement: Sendable {
    let facility: Facility
    let newX: Int
    let newY: Int
}

// MARK: - AutoArrange

/// Zone-based automatic facility layout. Three modes: small farm, neighborhood, multi-area.
/// Maps from: game/auto_arrange.py
enum AutoArrange {

    // MARK: - Internal Support Types (accessible from AutoArrangeLayout.swift extension)

    enum FacilityZone {
        case feeding, hydration, rest, play, utility
    }

    enum EssentialNeed: CaseIterable {
        case food, water, rest, play
    }

    struct ShelfItem {
        let facility: Facility
        let x: Int
        let width: Int
        let height: Int
    }

    // MARK: - Facility Zone and Need Maps

    static let facilityZoneMap: [FacilityType: FacilityZone] = [
        .foodBowl: .feeding, .hayRack: .feeding, .veggieGarden: .feeding,
        .waterBottle: .hydration,
        .hideout: .rest,
        .exerciseWheel: .play, .tunnel: .play, .playArea: .play,
        .breedingDen: .utility, .nursery: .utility, .groomingStation: .utility,
        .geneticsLab: .utility, .feastTable: .utility, .campfire: .utility,
        .therapyGarden: .utility, .hotSpring: .utility, .stage: .utility,
    ]

    static let facilityNeedMap: [FacilityType: EssentialNeed?] = [
        .foodBowl: .food, .hayRack: .food, .veggieGarden: .food,
        .waterBottle: .water,
        .hideout: .rest,
        .exerciseWheel: .play, .tunnel: .play, .playArea: .play,
        .breedingDen: nil, .nursery: nil, .groomingStation: nil,
        .geneticsLab: nil, .feastTable: nil, .campfire: nil,
        .therapyGarden: nil, .hotSpring: nil, .stage: nil,
    ]

    static func zoneForFacility(_ type: FacilityType, mergeSmall: Bool) -> FacilityZone {
        let zone = facilityZoneMap[type] ?? .utility
        guard mergeSmall else { return zone }
        if zone == .hydration { return .feeding }
        if zone == .play { return .rest }
        return zone
    }

    static func needForFacility(_ type: FacilityType) -> EssentialNeed? {
        facilityNeedMap[type] ?? nil
    }

    // MARK: - Public API

    /// Compute new positions for all facilities without mutating state.
    @MainActor
    static func computeArrangement(state: GameState) -> ([Placement], [Facility]) {
        let facilities = state.getFacilitiesList()
        guard !facilities.isEmpty else { return ([], []) }
        let farm = state.farm
        if farm.areas.count > 1 {
            return computeMultiAreaArrangement(facilities: facilities, farm: farm)
        } else if isSmallFarm(farm) {
            return computeSmallFarmArrangement(facilities: facilities, farm: farm)
        } else {
            return computeNeighborhoodArrangement(facilities: facilities, farm: farm)
        }
    }

    /// Apply computed placements: remove all facilities and re-place at new positions.
    @MainActor
    static func applyArrangement(
        state: GameState, placements: [Placement], overflow: [Facility]
    ) {
        var saved: [UUID: Facility] = [:]
        for facilityId in Array(state.facilities.keys) {
            if let removed = state.removeFacility(facilityId) {
                saved[removed.id] = removed
            }
        }
        for placement in placements {
            guard var facility = saved[placement.facility.id] else { continue }
            facility.positionX = placement.newX
            facility.positionY = placement.newY
            facility.areaId = state.farm.getAreaAt(placement.newX, placement.newY)?.id
            _ = state.addFacility(facility)
        }
        for overflowFacility in overflow {
            guard var facility = saved[overflowFacility.id] else { continue }
            if let pos = findGridPosition(for: facility, in: state.farm) {
                facility.positionX = pos.x
                facility.positionY = pos.y
                facility.areaId = state.farm.getAreaAt(pos.x, pos.y)?.id
                _ = state.addFacility(facility)
            }
        }
    }

    /// Reset all pig navigation state after facility rearrangement.
    @MainActor
    static func clearPigNavigation(state: GameState) {
        for pigId in Array(state.guineaPigs.keys) {
            guard var pig = state.guineaPigs[pigId] else { continue }
            pig.path = []
            pig.targetPosition = nil
            pig.targetFacilityId = nil
            pig.targetDescription = nil
            pig.behaviorState = .idle
            let gridPos = pig.position.gridPosition
            if !state.farm.isWalkable(gridPos.x, gridPos.y) {
                if let newPos = state.farm.findNearestWalkable(gridPos) {
                    pig.position.x = Double(newPos.x)
                    pig.position.y = Double(newPos.y)
                }
            }
            state.updateGuineaPig(pig)
        }
    }

    // MARK: - Farm Classification

    /// Returns true if the farm is below the small-farm size threshold.
    static func isSmallFarm(_ farm: FarmGrid) -> Bool {
        farm.width < GameConfig.AutoArrange.smallFarmThresholdW
            || farm.height < GameConfig.AutoArrange.smallFarmThresholdH
    }

    // MARK: - Zone Calculation

    /// Three-zone layout (feeding / rest / utility) for small or single-area farms.
    static func calculateZones(farm: FarmGrid) -> [Zone] {
        guard let area = farm.areas.first else { return [] }
        return zonesForInterior(
            x1: area.interiorX1, y1: area.interiorY1,
            x2: area.interiorX2, y2: area.interiorY2
        )
    }

    /// Neighborhood + utility zones for large single-area farms.
    static func calculateNeighborhoodZones(farm: FarmGrid, numNeighborhoods: Int) -> [Zone] {
        guard let area = farm.areas.first else { return [] }
        let margin = GameConfig.AutoArrange.zoneMargin
        let ix1 = area.interiorX1 + margin, iy1 = area.interiorY1 + margin
        let ix2 = area.interiorX2 - margin, iy2 = area.interiorY2 - margin
        let iw = ix2 - ix1 + 1, ih = iy2 - iy1 + 1
        let utilityH = max(1, Int(Double(ih) * GameConfig.AutoArrange.neighborhoodUtilityFraction))
        let neighborhoodH = ih - utilityH
        let utilityStartY = iy1 + neighborhoodH
        let utilityZone = Zone(name: "utility", x1: ix1, y1: utilityStartY, x2: ix2, y2: iy2)
        let (rows, cols) = neighborhoodGridLayout(
            count: numNeighborhoods, aspectRatio: Double(iw) / Double(max(1, neighborhoodH))
        )
        let cellW = iw / cols, cellH = neighborhoodH / rows
        var zones: [Zone] = []
        for row in 0..<rows {
            for col in 0..<cols {
                let index = row * cols + col
                guard index < numNeighborhoods else { break }
                let zx1 = ix1 + col * cellW, zy1 = iy1 + row * cellH
                let zx2 = col == cols - 1 ? ix2 : zx1 + cellW - 1
                let zy2 = row == rows - 1 ? iy1 + neighborhoodH - 1 : zy1 + cellH - 1
                zones.append(Zone(name: "neighborhood_\(index)", x1: zx1, y1: zy1, x2: zx2, y2: zy2))
            }
        }
        zones.append(utilityZone)
        return zones
    }

    /// Min count across essential categories, capped at maxNeighborhoods.
    static func determineNeighborhoodCount(facilities: [Facility]) -> Int {
        var counts: [EssentialNeed: Int] = [:]
        for facility in facilities {
            if let need = needForFacility(facility.facilityType) {
                counts[need, default: 0] += 1
            }
        }
        guard let minCount = counts.values.min() else { return 1 }
        return min(minCount, GameConfig.AutoArrange.maxNeighborhoods)
    }

    // MARK: - Private Utilities

    static func zonesForInterior(x1: Int, y1: Int, x2: Int, y2: Int) -> [Zone] {
        let margin = GameConfig.AutoArrange.zoneMargin
        let ix1 = x1 + margin, iy1 = y1 + margin, ix2 = x2 - margin, iy2 = y2 - margin
        let iw = ix2 - ix1 + 1, ih = iy2 - iy1 + 1
        guard iw > 0, ih > 0 else { return [] }
        let midX = ix1 + iw / 2 - 1
        let splitY = iy1 + Int(Double(ih) * 0.7) - 1
        return [
            Zone(name: "feeding", x1: ix1, y1: iy1, x2: midX, y2: splitY),
            Zone(name: "rest", x1: midX + 1, y1: iy1, x2: ix2, y2: splitY),
            Zone(name: "utility", x1: ix1, y1: splitY + 1, x2: ix2, y2: iy2),
        ]
    }

    static func findGridPosition(for facility: Facility, in farm: FarmGrid) -> GridPosition? {
        let sortedAreas = farm.areas.sorted {
            $0.interiorWidth * $0.interiorHeight > $1.interiorWidth * $1.interiorHeight
        }
        for area in sortedAreas {
            let maxX = area.interiorX2 - facility.width + 1
            let maxY = area.interiorY2 - facility.height + 1
            guard maxX >= area.interiorX1, maxY >= area.interiorY1 else { continue }
            for gridY in area.interiorY1...maxY {
                for gridX in area.interiorX1...maxX {
                    guard gridY + facility.height < farm.height - 1 else { continue }
                    let fits = (0..<facility.height).allSatisfy { dy in
                        (0..<facility.width).allSatisfy { dx in
                            farm.isWalkable(gridX + dx, gridY + dy)
                        }
                    }
                    if fits { return GridPosition(x: gridX, y: gridY) }
                }
            }
        }
        return nil
    }

    static func neighborhoodGridLayout(count: Int, aspectRatio: Double) -> (rows: Int, cols: Int) {
        switch count {
        case 1: return (1, 1)
        case 2: return aspectRatio >= 1.0 ? (1, 2) : (2, 1)
        case 3: return aspectRatio >= 1.0 ? (1, 3) : (3, 1)
        default: return (2, 2)
        }
    }
}
