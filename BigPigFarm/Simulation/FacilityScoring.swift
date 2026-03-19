/// FacilityScoring — Facility ranking, occupancy detection, and interaction point search.
/// Maps from: simulation/facility_manager.py (rank_facilities_by_spread, find_open_interaction_point)
import Foundation

// MARK: - Biome Affinity Helper

/// Check if a pig's base color matches a biome's signature color.
func pigColorMatchesBiome(_ pig: GuineaPig, biomeString: String) -> Bool {
    guard let signature = biomeSignatureColors[biomeString] else { return false }
    return pig.phenotype.baseColor == signature
}

// MARK: - FacilityManager Scoring Extension

extension FacilityManager {

    // MARK: - Candidate Ranking

    /// Filtered and ranked facility candidates for a pig — no A* calls.
    /// Callers iterate and call `findOpenInteractionPoint` until one succeeds.
    func getCandidateFacilitiesRanked(pig: GuineaPig, facilityType: FacilityType) -> [Facility] {
        var facilities = gameState.getFacilitiesByType(facilityType)
        if facilities.isEmpty { return [] }

        // Filter empty consumables
        let consumableTypes: Set<FacilityType> = [.foodBowl, .waterBottle, .hayRack, .feastTable]
        if consumableTypes.contains(facilityType) {
            facilities = facilities.filter { !$0.isEmpty }
        }

        // Filter recently failed facilities for this pig
        let failed = getFailedFacilities(pig.id)
        if !failed.isEmpty {
            facilities = facilities.filter { !failed.contains($0.id) }
        }

        if facilities.isEmpty { return [] }

        // Manhattan distance pre-filter — skip facilities too far away
        let start = pig.position.gridPosition
        let maxDist = GameConfig.Behavior.maxFacilityPathfindDistance
        facilities = facilities.filter { facility in
            facility.interactionPoints.contains { point in
                abs(start.x - point.x) + abs(start.y - point.y) <= maxDist
            }
        }
        if facilities.isEmpty { return [] }

        // Same-area priority: prefer same-area facilities when not overcrowded
        let pigArea = pig.currentAreaId
        var sameAreaFacilities: [Facility]?
        if let areaId = pigArea {
            let population = areaPopulations[areaId] ?? 0
            let capacity = areaCapacities[areaId] ?? 0
            if population <= capacity {
                let sameArea = facilities.filter { $0.areaId == areaId }
                if !sameArea.isEmpty {
                    sameAreaFacilities = sameArea
                }
            }
        }

        // Rank by spread score (Manhattan + crowding, no A*)
        let toRank = sameAreaFacilities ?? facilities
        var ranked = rankFacilitiesBySpread(pig: pig, facilities: toRank)

        // Append cross-area facilities as fallback
        if let sameArea = sameAreaFacilities, sameArea.count < facilities.count {
            let crossArea = facilities.filter { $0.areaId != pigArea }
            if !crossArea.isEmpty {
                ranked.append(contentsOf: rankFacilitiesBySpread(pig: pig, facilities: crossArea))
            }
        }

        return ranked
    }

    // MARK: - Spread Ranking

    /// Rank facilities by a heuristic: closer and less crowded rank first.
    /// A 30% chance shuffles an uncrowded facility to the front for variety.
    func rankFacilitiesBySpread(pig: GuineaPig, facilities: [Facility]) -> [Facility] {
        if facilities.isEmpty { return [] }

        // Pre-compute crowd counts (avoid repeated spatial lookups)
        let crowdCounts: [UUID: Int] = facilities.reduce(into: [:]) { result, facility in
            result[facility.id] = countPigsNearOrHeadingTo(pig: pig, facility: facility)
        }

        // Biome affinity: color-derived biome takes priority over preferred_biome
        let pigBiome: String? = colorToBiome[pig.phenotype.baseColor] ?? pig.preferredBiome
        let facilityBiomes: [UUID: String?] = pigBiome != nil
            ? facilities.reduce(into: [:]) { $0[$1.id] = getFacilityBiome($1) }
            : [:]

        // Pre-compute area overcrowding penalties
        var areaOvercrowding: [UUID: Double] = [:]
        for facility in facilities {
            if let areaId = facility.areaId, areaOvercrowding[areaId] == nil {
                let population = areaPopulations[areaId] ?? 0
                let capacity = areaCapacities[areaId] ?? 0
                let overage = max(0, population - capacity)
                areaOvercrowding[areaId] = Double(overage) * GameConfig.Behavior.roomOvercrowdingPenalty
            }
        }

        func score(_ facility: Facility) -> Double {
            let point = facility.interactionPoint
            let dist = pig.position.distanceTo(Position(x: Double(point.x), y: Double(point.y)))
            var total = dist * GameConfig.Behavior.facilityDistanceWeight
                + Double(crowdCounts[facility.id] ?? 0) * GameConfig.Behavior.crowdingPenalty
                + Double.random(in: 0..<GameConfig.Behavior.scoringRandomVariance)
            // Biome affinity penalty (reduced if pig color matches facility biome)
            if let pigBiomeStr = pigBiome,
               let facilityBiomeOpt = facilityBiomes[facility.id],
               let facilityBiomeStr = facilityBiomeOpt,
               facilityBiomeStr != pigBiomeStr {
                var penalty = GameConfig.Behavior.biomeAffinityPenalty
                if pigColorMatchesBiome(pig, biomeString: facilityBiomeStr) {
                    penalty *= (1.0 - GameConfig.Biome.colorMatchAffinityReduction)
                }
                total += penalty
            }
            if let areaId = facility.areaId {
                total += areaOvercrowding[areaId] ?? 0.0
            }
            return total
        }

        var ranked = facilities.sorted { score($0) < score($1) }

        // 30% chance to shuffle an uncrowded facility to the front
        let uncrowded = ranked.filter { (crowdCounts[$0.id] ?? 0) == 0 }
        if !uncrowded.isEmpty && Double.random(in: 0..<1) < GameConfig.Behavior.uncrowdedChance {
            guard let pick = uncrowded.randomElement() else {
                preconditionFailure("Uncrowded array must not be empty after isEmpty check")
            }
            ranked.removeAll { $0.id == pick.id }
            ranked.insert(pick, at: 0)
        }

        return ranked
    }

    // MARK: - Crowd Counting

    /// Count pigs near or heading to a facility (excluding the given pig).
    func countPigsNearOrHeadingTo(pig: GuineaPig, facility: Facility) -> Int {
        let point = facility.interactionPoint
        let facilityPos = Position(x: Double(point.x), y: Double(point.y))
        var countedIds: Set<UUID> = []
        var count = 0

        // Proximity via spatial grid
        for other in collision.spatialGrid.getNearby(
            x: Double(point.x), y: Double(point.y), pigs: pigs
        ) {
            if other.id == pig.id { continue }
            let dist = other.position.distanceTo(facilityPos)
            if dist < GameConfig.Behavior.facilityNearbyRadius {
                count += 1
                countedIds.insert(other.id)
            } else if other.targetFacilityId == facility.id {
                count += 1
                countedIds.insert(other.id)
            } else if let tp = other.targetPosition,
                      tp.distanceTo(facilityPos) < GameConfig.Behavior.facilityHeadingRadius {
                count += 1
                countedIds.insert(other.id)
            }
        }

        // Distant pigs targeting this facility by ID (outside spatial neighborhood)
        for pid in collision.getPigsTargetingFacility(facility.id) {
            if pid != pig.id && !countedIds.contains(pid) {
                count += 1
            }
        }

        return count
    }

    /// Count pigs currently using a facility (within occupancyRadius of any interaction point).
    func countPigsUsingFacility(_ facility: Facility, excludePig: GuineaPig?) -> Int {
        let usingStates: Set<BehaviorState> = [.eating, .drinking, .sleeping, .playing, .socializing]
        var counted: Set<UUID> = []
        let excludeId = excludePig?.id

        for point in facility.interactionPoints {
            for other in collision.spatialGrid.getNearby(
                x: Double(point.x), y: Double(point.y), pigs: pigs
            ) {
                if other.id == excludeId || counted.contains(other.id) { continue }
                let dist = other.position.distanceTo(Position(x: Double(point.x), y: Double(point.y)))
                if dist < GameConfig.Behavior.occupancyRadius && usingStates.contains(other.behaviorState) {
                    counted.insert(other.id)
                }
            }
        }
        return counted.count
    }

    // MARK: - Interaction Point Search

    /// Find an unoccupied interaction point and the path to it.
    /// Returns `(point, path)` where `path` excludes the pig's current position,
    /// or nil if no open reachable point exists.
    func findOpenInteractionPoint(
        pig: GuineaPig,
        facility: Facility
    ) -> (point: GridPosition, path: [GridPosition])? {
        let farmGrid = gameState.farm
        let start = pig.position.gridPosition

        // Early capacity check for play/social facilities.
        // Hideout is excluded: arrival handler allows overflow with a "sleep nearby" fallback.
        let capacityCheckedTypes: Set<FacilityType> = [
            .exerciseWheel, .tunnel, .playArea, .therapyGarden, .campfire, .stage
        ]
        if capacityCheckedTypes.contains(facility.facilityType) {
            let capacity = facility.info.capacity
            let targeting = collision.getPigsTargetingFacility(facility.id)
            let targetingCount = targeting.filter { $0 != pig.id }.count
            if targetingCount >= capacity { return nil }
        }

        let occupancyRadius = GameConfig.Behavior.blockingFacilityUse
        var candidates: [(point: GridPosition, path: [GridPosition])] = []

        for point in facility.interactionPoints {
            guard farmGrid.isValidPosition(point.x, point.y) else { continue }
            guard farmGrid.isWalkable(point.x, point.y) else { continue }
            guard !isInteractionPointOccupied(point: point, excludePig: pig, radius: occupancyRadius)
            else { continue }
            let path = cachedFindPath(from: start, to: point)
            if !path.isEmpty {
                candidates.append((point: point, path: path))
            }
        }

        if candidates.isEmpty { return nil }

        // Pick the closest unoccupied point by path length
        candidates.sort { $0.path.count < $1.path.count }
        let best = candidates[0]
        // Return path excluding current position (pig.path assignment convention)
        let trimmedPath = best.path.count > 1 ? Array(best.path.dropFirst()) : []
        return (point: best.point, path: trimmedPath)
    }

    /// True if another pig is physically using this point, or has been
    /// dispatched to this exact grid cell earlier in the same tick.
    ///
    /// Check 1 uses the spatial grid to find pigs already at the point and
    /// in a facility-using state (eating, drinking, etc.).
    ///
    /// Check 2 iterates all pigs because a pig dispatched earlier in the same
    /// tick is still at its old position — getNearby won't find it. Uses
    /// exact grid-position matching (not radius) to prevent cross-blocking
    /// adjacent interaction points on the same facility.
    private func isInteractionPointOccupied(
        point: GridPosition,
        excludePig: GuineaPig,
        radius: Double
    ) -> Bool {
        let usingStates: Set<BehaviorState> = [.eating, .drinking, .sleeping, .playing, .socializing]
        let pointPos = Position(x: Double(point.x), y: Double(point.y))

        // 1. Check pigs physically at the point and using a facility (spatial grid — fast).
        for other in collision.spatialGrid.getNearby(x: Double(point.x), y: Double(point.y), pigs: pigs) {
            if other.id == excludePig.id { continue }
            if usingStates.contains(other.behaviorState)
                && other.position.distanceTo(pointPos) < radius {
                return true
            }
        }

        // 2. Check pigs dispatched to this exact grid cell earlier in the same tick.
        // Uses exact grid-position matching to avoid cross-blocking adjacent
        // interaction points (e.g. a pig heading to a water bottle's front point
        // should not block its side points).
        for other in pigs.values {
            if other.id == excludePig.id { continue }
            if other.targetFacilityId != nil,
               let tp = other.targetPosition,
               Int(tp.x) == point.x && Int(tp.y) == point.y {
                return true
            }
        }

        return false
    }
}
