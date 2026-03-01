/// SaveMigration — Post-load migration passes for save file compatibility.
/// Maps from: Spec 08 Section 8.
import Foundation

// MARK: - FarmGrid Migration Extension

extension FarmGrid {
    /// Resize grid canvas to fit all areas at their current positions, then re-stamp area cells.
    /// Called by SaveMigration after repositioning areas to new coordinates.
    mutating func rebuildGridFromAreas() {
        var requiredWidth = width
        var requiredHeight = height
        for area in areas {
            requiredWidth = max(requiredWidth, area.x2 + 1)
            requiredHeight = max(requiredHeight, area.y2 + 1)
        }
        if requiredWidth > width || requiredHeight > height {
            GridExpansion.expandGrid(&self, newWidth: requiredWidth, newHeight: requiredHeight)
        }
        AreaManager.repairAreaCells(&self)
    }
}

// MARK: - SaveMigration

/// Migration passes applied to loaded game state before handing it to the engine.
/// Caseless enum — cannot be instantiated.
enum SaveMigration {

    /// Run all migration passes in order.
    @MainActor
    static func migrateIfNeeded(_ state: GameState) {
        if state.farm.areas.isEmpty {
            state.farm.createLegacyStarterArea()
        }
        let didRelayout = relayoutAreas(state)
        if !didRelayout {
            AreaManager.repairAreaCells(&state.farm)
            AreaManager.rebuildTunnels(&state.farm)
        }
        state.farm.tier = state.farmTier
        resizeAllRooms(state, tier: state.farmTier)
    }

    // MARK: - Area Relayout

    /// Ensure areas use the 2-column grid layout.
    /// Assigns gridCol/gridRow slots and repositions any misplaced areas.
    /// Returns true if any area was repositioned.
    @MainActor
    @discardableResult
    static func relayoutAreas(_ state: GameState) -> Bool {
        guard !state.farm.areas.isEmpty else { return false }
        for i in state.farm.areas.indices {
            state.farm.areas[i].gridCol = i % 2
            state.farm.areas[i].gridRow = i / 2
        }
        let origins = GridExpansion.computeGridLayout(state.farm)
        guard areasNeedRelayout(state.farm.areas, origins: origins) else { return false }
        let deltas = computeAreaDeltas(state.farm.areas, origins: origins)
        let facilityList = state.getFacilitiesList()
        for facility in facilityList { state.farm.removeFacility(facility) }
        movePigsBy(deltas, in: state)
        let moved = computeMovedFacilities(facilityList, areaDeltas: deltas, farm: state.farm)
        applyOrigins(origins, to: &state.farm)
        rebuildAndReplace(&state.farm, movedFacilities: moved, state: state)
        clampOrphanedPigs(state)
        return true
    }

    // MARK: - Room Resize

    /// Ensure all rooms match the current tier's room dimensions.
    /// Returns true if any room was resized.
    @MainActor
    @discardableResult
    static func resizeAllRooms(_ state: GameState, tier: Int) -> Bool {
        let tierInfo = getTierUpgrade(tier: tier)
        guard roomsNeedResize(state.farm.areas, targetWidth: tierInfo.roomWidth,
                              targetHeight: tierInfo.roomHeight) else { return false }
        let facilityList = state.getFacilitiesList()
        for facility in facilityList { state.farm.removeFacility(facility) }
        for i in state.farm.areas.indices {
            state.farm.areas[i].x2 = state.farm.areas[i].x1 + tierInfo.roomWidth - 1
            state.farm.areas[i].y2 = state.farm.areas[i].y1 + tierInfo.roomHeight - 1
            state.farm.areaLookup[state.farm.areas[i].id] = state.farm.areas[i]
        }
        state.farm.rebuildGridFromAreas()
        for facility in facilityList {
            state.updateFacility(facility)
            _ = state.farm.placeFacility(facility)
        }
        AreaManager.rebuildTunnels(&state.farm)
        clampOrphanedPigs(state)
        return true
    }

    // MARK: - Orphan Clamping

    /// Move pigs that land on non-walkable cells to the nearest walkable cell.
    @MainActor
    static func clampOrphanedPigs(_ state: GameState) {
        for pig in state.getPigsList() {
            let x = Int(pig.position.x)
            let y = Int(pig.position.y)
            guard !state.farm.isWalkable(x, y) else { continue }
            var moved = pig
            if let nearest = state.farm.findNearestWalkable(GridPosition(x: x, y: y), maxDistance: 20) {
                moved.position.x = Double(nearest.x)
                moved.position.y = Double(nearest.y)
            } else if let fallback = state.farm.areas.first {
                moved.position.x = Double(fallback.centerX)
                moved.position.y = Double(fallback.centerY)
            }
            moved.path = []
            state.updateGuineaPig(moved)
        }
    }
}

// MARK: - Private Helpers

private extension SaveMigration {
    static func areasNeedRelayout(_ areas: [FarmArea], origins: [Int: GridPosition]) -> Bool {
        for (i, area) in areas.enumerated() {
            guard let origin = origins[i] else { continue }
            if area.x1 != origin.x || area.y1 != origin.y { return true }
        }
        return false
    }

    static func roomsNeedResize(_ areas: [FarmArea], targetWidth: Int, targetHeight: Int) -> Bool {
        areas.contains { area in
            (area.x2 - area.x1 + 1) != targetWidth || (area.y2 - area.y1 + 1) != targetHeight
        }
    }

    static func computeAreaDeltas(
        _ areas: [FarmArea],
        origins: [Int: GridPosition]
    ) -> [UUID: GridPosition] {
        var deltas: [UUID: GridPosition] = [:]
        for (i, area) in areas.enumerated() {
            guard let origin = origins[i] else { continue }
            let dx = origin.x - area.x1
            let dy = origin.y - area.y1
            if dx != 0 || dy != 0 { deltas[area.id] = GridPosition(x: dx, y: dy) }
        }
        return deltas
    }

    @MainActor
    static func movePigsBy(_ deltas: [UUID: GridPosition], in state: GameState) {
        for pig in state.getPigsList() {
            let x = Int(pig.position.x)
            let y = Int(pig.position.y)
            guard let areaId = state.farm.getAreaAt(x, y)?.id,
                  let delta = deltas[areaId] else { continue }
            var moved = pig
            moved.position.x += Double(delta.x)
            moved.position.y += Double(delta.y)
            moved.path = []
            state.updateGuineaPig(moved)
        }
    }

    static func computeMovedFacilities(
        _ facilities: [Facility],
        areaDeltas: [UUID: GridPosition],
        farm: FarmGrid
    ) -> [Facility] {
        facilities.map { facility in
            guard let areaId = farm.getAreaAt(facility.positionX, facility.positionY)?.id,
                  let delta = areaDeltas[areaId] else { return facility }
            var moved = facility
            moved.positionX += delta.x
            moved.positionY += delta.y
            return moved
        }
    }

    static func applyOrigins(_ origins: [Int: GridPosition], to farm: inout FarmGrid) {
        for i in farm.areas.indices {
            guard let origin = origins[i] else { continue }
            let width = farm.areas[i].x2 - farm.areas[i].x1 + 1
            let height = farm.areas[i].y2 - farm.areas[i].y1 + 1
            farm.areas[i].x1 = origin.x
            farm.areas[i].y1 = origin.y
            farm.areas[i].x2 = origin.x + width - 1
            farm.areas[i].y2 = origin.y + height - 1
            farm.areaLookup[farm.areas[i].id] = farm.areas[i]
        }
    }

    @MainActor
    static func rebuildAndReplace(
        _ farm: inout FarmGrid,
        movedFacilities: [Facility],
        state: GameState
    ) {
        farm.rebuildGridFromAreas()
        for facility in movedFacilities {
            state.updateFacility(facility)
            _ = state.farm.placeFacility(facility)
        }
        AreaManager.rebuildTunnels(&state.farm)
    }
}
