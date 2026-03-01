/// AutoArrangeLayout — Layout mode implementations for AutoArrange.
/// Three modes: small farm (3 zones), neighborhood (grid+utility), multi-area (per-area 3 zones).
/// Maps from: game/auto_arrange.py
import Foundation

// MARK: - PackingContext

/// Shared packing state: immutable config + mutable occupied-cell set.
/// Passed `inout` so the occupied set is updated across all zone passes.
struct PackingContext {
    let hGap: Int
    let vGap: Int
    let farmHeight: Int
    var occupied: Set<GridPosition>
}

// MARK: - FacilityZone → Zone Name

extension AutoArrange.FacilityZone {
    /// Maps zone enum to the 3-zone layout's zone name string.
    var zoneName: String {
        switch self {
        case .feeding, .hydration: return "feeding"
        case .rest, .play: return "rest"
        case .utility: return "utility"
        }
    }
}

// MARK: - Layout Modes

extension AutoArrange {

    // MARK: Small Farm

    /// Three-zone type-grouped layout. Hydration merges into feeding, play into rest.
    static func computeSmallFarmArrangement(
        facilities: [Facility], farm: FarmGrid
    ) -> ([Placement], [Facility]) {
        let zones = calculateZones(farm: farm)
        guard !zones.isEmpty else { return ([], facilities) }
        var context = PackingContext(
            hGap: GameConfig.AutoArrange.smallHorizontalGap,
            vGap: GameConfig.AutoArrange.smallVerticalGap,
            farmHeight: farm.height,
            occupied: []
        )
        var zoneMap = zoneNameMap(zones: zones)
        for facility in facilities {
            let name = zoneForFacility(facility.facilityType, mergeSmall: true).zoneName
            if zoneMap[name] != nil {
                zoneMap[name, default: []].append(facility)
            } else {
                zoneMap[zones[zones.count - 1].name, default: []].append(facility)
            }
        }
        return packAllZones(zones: zones, zoneMap: &zoneMap, context: &context)
    }

    // MARK: Neighborhood

    /// Grid-of-neighborhoods + utility zone layout for large single-area farms.
    static func computeNeighborhoodArrangement(
        facilities: [Facility], farm: FarmGrid
    ) -> ([Placement], [Facility]) {
        var context = PackingContext(
            hGap: GameConfig.AutoArrange.horizontalGap,
            vGap: GameConfig.AutoArrange.verticalGap,
            farmHeight: farm.height,
            occupied: []
        )
        let (essential, utilityFacilities) = classifyFacilities(facilities)
        let numNeighborhoods = determineNeighborhoodCount(facilities: facilities)
        let zones = calculateNeighborhoodZones(farm: farm, numNeighborhoods: numNeighborhoods)
        let nhZones = Array(zones.dropLast())
        guard !nhZones.isEmpty else { return ([], facilities) }
        var zoneMap = zoneNameMap(zones: zones)
        for need in EssentialNeed.allCases {
            for (idx, facility) in (essential[need] ?? []).enumerated() {
                let zoneIdx = idx % numNeighborhoods
                zoneMap[nhZones[zoneIdx].name, default: []].append(facility)
            }
        }
        zoneMap["utility"] = utilityFacilities
        return packAllZones(zones: zones, zoneMap: &zoneMap, context: &context)
    }

    // MARK: Multi-Area

    /// Per-area 3-zone layout. Distributes facilities proportionally to area size.
    static func computeMultiAreaArrangement(
        facilities: [Facility], farm: FarmGrid
    ) -> ([Placement], [Facility]) {
        let totalSize = farm.areas.reduce(0) { $0 + $1.interiorWidth * $1.interiorHeight }
        guard totalSize > 0 else { return ([], facilities) }
        let (essential, utilityFacilities) = classifyFacilities(facilities)
        let areaFacilities = distributeToAreas(
            essential: essential, utility: utilityFacilities,
            areas: farm.areas, totalSize: totalSize
        )
        var allPlaced: [Placement] = []
        var allOverflow: [Facility] = []
        for area in farm.areas {
            let areaFacs = areaFacilities[area.id] ?? []
            guard !areaFacs.isEmpty else { continue }
            let (placed, overflow) = computeAreaArrangement(facilities: areaFacs, area: area, farm: farm)
            allPlaced.append(contentsOf: placed)
            allOverflow.append(contentsOf: overflow)
        }
        if !allOverflow.isEmpty {
            guard let biggest = farm.areas.max(
                by: { $0.interiorWidth * $0.interiorHeight < $1.interiorWidth * $1.interiorHeight }
            ) else { return (allPlaced, allOverflow) }
            let (placed, still) = computeAreaArrangement(facilities: allOverflow, area: biggest, farm: farm)
            allPlaced.append(contentsOf: placed)
            allOverflow = still
        }
        return (allPlaced, allOverflow)
    }
}

// MARK: - Private Helpers

private extension AutoArrange {

    /// Single-area 3-zone arrangement (feeding | rest | utility). Used by multi-area layout.
    static func computeAreaArrangement(
        facilities: [Facility], area: FarmArea, farm: FarmGrid
    ) -> ([Placement], [Facility]) {
        let zones = zonesForInterior(
            x1: area.interiorX1, y1: area.interiorY1,
            x2: area.interiorX2, y2: area.interiorY2
        )
        guard !zones.isEmpty else { return ([], facilities) }
        let iw = area.interiorX2 - area.interiorX1 + 1
        let isSmall = iw < GameConfig.AutoArrange.smallFarmThresholdW
        var context = PackingContext(
            hGap: isSmall ? GameConfig.AutoArrange.smallHorizontalGap : GameConfig.AutoArrange.horizontalGap,
            vGap: isSmall ? GameConfig.AutoArrange.smallVerticalGap : GameConfig.AutoArrange.verticalGap,
            farmHeight: farm.height,
            occupied: []
        )
        var zoneMap = zoneNameMap(zones: zones)
        for facility in facilities {
            let name = zoneForFacility(facility.facilityType, mergeSmall: true).zoneName
            if zoneMap[name] != nil {
                zoneMap[name, default: []].append(facility)
            } else {
                zoneMap[zones[zones.count - 1].name, default: []].append(facility)
            }
        }
        return packAllZones(zones: zones, zoneMap: &zoneMap, context: &context)
    }

    /// Classify facilities into essential-need buckets and utility.
    static func classifyFacilities(
        _ facilities: [Facility]
    ) -> ([EssentialNeed: [Facility]], [Facility]) {
        var essential: [EssentialNeed: [Facility]] = [:]
        var utility: [Facility] = []
        for facility in facilities {
            if let need = needForFacility(facility.facilityType) {
                essential[need, default: []].append(facility)
            } else {
                utility.append(facility)
            }
        }
        return (essential, utility)
    }

    /// Distribute facilities to areas proportionally by interior area size.
    static func distributeToAreas(
        essential: [EssentialNeed: [Facility]],
        utility: [Facility],
        areas: [FarmArea],
        totalSize: Int
    ) -> [UUID: [Facility]] {
        let weights: [UUID: Double] = Dictionary(uniqueKeysWithValues: areas.map { area in
            (area.id, Double(area.interiorWidth * area.interiorHeight) / Double(totalSize))
        })
        var areaFacilities: [UUID: [Facility]] = Dictionary(
            uniqueKeysWithValues: areas.map { ($0.id, [Facility]()) }
        )
        var categories: [(isEssential: Bool, facilities: [Facility])] =
            EssentialNeed.allCases.map { (true, essential[$0] ?? []) }
        categories.append((false, utility))
        for (isEssential, catFacs) in categories where !catFacs.isEmpty {
            var counts: [UUID: Int] = Dictionary(uniqueKeysWithValues: areas.map { ($0.id, 0) })
            let targets: [UUID: Double] = Dictionary(uniqueKeysWithValues: areas.map { area in
                let base = (weights[area.id] ?? 0) * Double(catFacs.count)
                return (area.id, isEssential ? max(base, 1.0) : base)
            })
            for facility in catFacs {
                guard let best = areas.max(by: {
                    (targets[$0.id, default: 0] - Double(counts[$0.id, default: 0])) <
                    (targets[$1.id, default: 0] - Double(counts[$1.id, default: 0]))
                }) else { continue }
                areaFacilities[best.id, default: []].append(facility)
                counts[best.id, default: 0] += 1
            }
        }
        return areaFacilities
    }

    /// Create an empty zone-name → facility list map for a set of zones.
    static func zoneNameMap(zones: [Zone]) -> [String: [Facility]] {
        Dictionary(uniqueKeysWithValues: zones.map { ($0.name, [Facility]()) })
    }

    /// Pack all zones from the map, then retry overflow in all zones.
    static func packAllZones(
        zones: [Zone],
        zoneMap: inout [String: [Facility]],
        context: inout PackingContext
    ) -> ([Placement], [Facility]) {
        var allPlaced: [Placement] = []
        var allOverflow: [Facility] = []
        for zone in zones {
            let facs = zoneMap[zone.name] ?? []
            guard !facs.isEmpty else { continue }
            let (placed, overflow) = placeFacilitiesInZone(facs, zone: zone, context: &context)
            allPlaced.append(contentsOf: placed)
            allOverflow.append(contentsOf: overflow)
        }
        for zone in zones {
            guard !allOverflow.isEmpty else { break }
            let (placed, still) = placeFacilitiesInZone(allOverflow, zone: zone, context: &context)
            allPlaced.append(contentsOf: placed)
            allOverflow = still
        }
        return (allPlaced, allOverflow)
    }

    /// Assign facilities to horizontal shelves (Phase 1 of shelf packing).
    static func buildShelves(_ facilities: [Facility], zone: Zone, hGap: Int) -> [[ShelfItem]] {
        let sorted = facilities.sorted { $0.width * $0.height > $1.width * $1.height }
        var shelves: [[ShelfItem]] = []
        var current: [ShelfItem] = []
        var cursorX = zone.x1
        for facility in sorted {
            let fw = facility.width
            guard fw <= zone.width else { continue }
            if !current.isEmpty && cursorX + fw - 1 > zone.x2 {
                shelves.append(current)
                current = []
                cursorX = zone.x1
            }
            current.append(ShelfItem(facility: facility, x: cursorX, width: fw, height: facility.height))
            cursorX += fw + hGap
        }
        if !current.isEmpty { shelves.append(current) }
        return shelves
    }

    /// Compute the y-position for each shelf, spread evenly through the zone height (Phase 2).
    static func shelfYPositions(shelves: [[ShelfItem]], zone: Zone, vGap: Int) -> [Int] {
        let heights = shelves.map { shelf in shelf.map { $0.height }.max() ?? 1 }
        let total = heights.reduce(0, +)
        let zoneH = zone.y2 - zone.y1 + 1
        if shelves.count == 1 { return [zone.y1 + (zoneH - heights[0]) / 2] }
        let remaining = zoneH - total
        var gap = remaining > 0 ? max(vGap, remaining / (shelves.count - 1)) : vGap
        if total + gap * (shelves.count - 1) > zoneH { gap = vGap }
        var ys: [Int] = []
        var y = zone.y1
        for sh in heights { ys.append(y); y += sh + gap }
        return ys
    }

    /// Place facilities in a zone using shelf packing. Updates `context.occupied` in-place.
    static func placeFacilitiesInZone(
        _ facilities: [Facility],
        zone: Zone,
        context: inout PackingContext
    ) -> ([Placement], [Facility]) {
        let shelves = buildShelves(facilities, zone: zone, hGap: context.hGap)
        let shelvedIDs = Set(shelves.flatMap { $0 }.map { $0.facility.id })
        var overflow = facilities.filter { !shelvedIDs.contains($0.id) }
        guard !shelves.isEmpty else { return ([], overflow) }
        let shelfYs = shelfYPositions(shelves: shelves, zone: zone, vGap: context.vGap)
        var placed: [Placement] = []
        for (idx, shelf) in shelves.enumerated() {
            let shelfY = shelfYs[idx]
            for item in shelf {
                guard shelfY + item.height - 1 <= zone.y2,
                      shelfY + item.height < context.farmHeight - 1 else {
                    overflow.append(item.facility)
                    continue
                }
                let fits = (0..<item.width).allSatisfy { dx in
                    (0..<item.height).allSatisfy { dy in
                        !context.occupied.contains(GridPosition(x: item.x + dx, y: shelfY + dy))
                    }
                }
                if fits {
                    placed.append(Placement(facility: item.facility, newX: item.x, newY: shelfY))
                    for dx in -1..<(item.width + context.hGap) {
                        for dy in -1..<(item.height + context.vGap) {
                            context.occupied.insert(GridPosition(x: item.x + dx, y: shelfY + dy))
                        }
                    }
                } else {
                    overflow.append(item.facility)
                }
            }
        }
        return (placed, overflow)
    }
}
