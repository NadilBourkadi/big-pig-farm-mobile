/// FacilityManagerTests — Path cache, failure tracking, area populations, and candidate ranking.
import Foundation
import Testing
@testable import BigPigFarmCore

@MainActor
struct FacilityManagerTests {

    // MARK: - Helpers

    // swiftlint:disable:next large_tuple
    func makeManager() -> (FacilityManager, GameState, BehaviorController) {
        let state = makeGameState()
        let controller = makeController(state: state)
        return (controller.facilityManager, state, controller)
    }

    func placeFacility(type: FacilityType, x: Int, y: Int, state: GameState) -> Facility {
        let facility = Facility.create(type: type, x: x, y: y)
        let success = state.addFacility(facility)
        precondition(success, "Failed to place \(type) at (\(x), \(y))")
        guard let placed = state.getFacility(facility.id) else {
            preconditionFailure("Facility missing after placement")
        }
        return placed
    }

    func pigAt(x: Double, y: Double, state: BehaviorState = .idle) -> GuineaPig {
        var pig = GuineaPig.create(name: "Test", gender: .female)
        pig.position = Position(x: x, y: y)
        pig.behaviorState = state
        return pig
    }

    // MARK: - OrderedPathCache Tests

    @Test("OrderedPathCache hit returns cached path")
    func testPathCacheHitReturnsCachedResult() {
        let cache = OrderedPathCache()
        let key = PathCacheKey(start: GridPosition(x: 0, y: 0), goal: GridPosition(x: 1, y: 1), generation: 0)
        let path = [GridPosition(x: 0, y: 0), GridPosition(x: 1, y: 1)]
        cache.set(key, path: path)
        let result = cache.get(key)
        #expect(result == path)
    }

    @Test("OrderedPathCache miss returns nil for unknown key")
    func testPathCacheMissReturnsNil() {
        let cache = OrderedPathCache()
        let key = PathCacheKey(start: GridPosition(x: 0, y: 0), goal: GridPosition(x: 5, y: 5), generation: 0)
        #expect(cache.get(key) == nil)
    }

    @Test("OrderedPathCache evicts oldest entry when over capacity")
    func testPathCacheEvictsOldestWhenFull() {
        let cache = OrderedPathCache(maxSize: 2)
        let key1 = PathCacheKey(start: GridPosition(x: 0, y: 0), goal: GridPosition(x: 1, y: 0), generation: 0)
        let key2 = PathCacheKey(start: GridPosition(x: 1, y: 0), goal: GridPosition(x: 2, y: 0), generation: 0)
        let key3 = PathCacheKey(start: GridPosition(x: 2, y: 0), goal: GridPosition(x: 3, y: 0), generation: 0)
        cache.set(key1, path: [GridPosition(x: 0, y: 0)])
        cache.set(key2, path: [GridPosition(x: 1, y: 0)])
        cache.set(key3, path: [GridPosition(x: 2, y: 0)])
        #expect(cache.get(key1) == nil)  // oldest evicted
        #expect(cache.get(key2) != nil)
        #expect(cache.get(key3) != nil)
    }

    @Test("OrderedPathCache keys with different generation miss")
    func testPathCacheInvalidatesOnGridGenerationChange() {
        let cache = OrderedPathCache()
        let key1 = PathCacheKey(start: GridPosition(x: 0, y: 0), goal: GridPosition(x: 3, y: 0), generation: 0)
        let key2 = PathCacheKey(start: GridPosition(x: 0, y: 0), goal: GridPosition(x: 3, y: 0), generation: 1)
        cache.set(key1, path: [GridPosition(x: 0, y: 0)])
        #expect(cache.get(key2) == nil)
    }

    // MARK: - cachedFindPath Tests

    @Test("cachedFindPath from A to A returns single-element path")
    func testCachedFindPathSameStartGoal() {
        let (manager, unusedState, unusedController) = makeManager()
        let pos = GridPosition(x: 5, y: 5)
        let result = manager.cachedFindPath(from: pos, to: pos)
        #expect(result == [pos])
    }

    @Test("cachedFindPath increments cacheHits on repeated call")
    func testCachedFindPathIncrementsCacheHits() {
        let (manager, unusedState, unusedController) = makeManager()
        let start = GridPosition(x: 5, y: 5)
        let goal = GridPosition(x: 5, y: 6)
        manager.resetPerfCounters()
        _ = manager.cachedFindPath(from: start, to: goal)
        _ = manager.cachedFindPath(from: start, to: goal)
        #expect(manager.cacheHits >= 1)
    }

    // MARK: - tryStraightLine Tests

    @Test("tryStraightLine returns path between adjacent walkable cells")
    func testStraightLineAdjacentCells() {
        let (manager, unusedState, unusedController) = makeManager()
        let start = GridPosition(x: 5, y: 5)
        let goal = GridPosition(x: 5, y: 6)
        let result = manager.tryStraightLine(from: start, to: goal)
        #expect(result != nil)
        #expect(result?.last == goal)
    }

    // MARK: - Failure Tracking Tests

    @Test("addFailedFacility then getFailedFacilities returns the ID")
    func testAddFailedFacilityAndGet() {
        let (manager, unusedState, unusedController) = makeManager()
        let pigId = UUID()
        let facilityId = UUID()
        manager.addFailedFacility(pigId, facilityId)
        #expect(manager.getFailedFacilities(pigId).contains(facilityId))
    }

    @Test("clearFailedFacilities removes all entries for a pig")
    func testClearFailedFacilities() {
        let (manager, unusedState, unusedController) = makeManager()
        let pigId = UUID()
        manager.addFailedFacility(pigId, UUID())
        manager.clearFailedFacilities(pigId)
        #expect(manager.getFailedFacilities(pigId).isEmpty)
    }

    @Test("tickFailedCooldown clears failed list when cooldown expires")
    func testTickFailedCooldownClearsWhenExpired() {
        let (manager, unusedState, unusedController) = makeManager()
        let pigId = UUID()
        manager.addFailedFacility(pigId, UUID())
        manager.setFailedCooldown(pigId, 1)
        manager.tickFailedCooldown(pigId)
        #expect(manager.getFailedFacilities(pigId).isEmpty)
        #expect(manager.getFailedCooldown(pigId) == 0)
    }

    @Test("tickFailedCooldown decrements but keeps failed list when not expired")
    func testTickFailedCooldownDecrements() {
        let (manager, unusedState, unusedController) = makeManager()
        let pigId = UUID()
        let facilityId = UUID()
        manager.addFailedFacility(pigId, facilityId)
        manager.setFailedCooldown(pigId, 3)
        manager.tickFailedCooldown(pigId)
        #expect(manager.getFailedCooldown(pigId) == 2)
        #expect(manager.getFailedFacilities(pigId).contains(facilityId))
    }

    // MARK: - Lifecycle Tests

    @Test("cleanupPig removes all tracking state for that pig")
    func testCleanupPigRemovesAllTracking() {
        let (manager, unusedState, unusedController) = makeManager()
        let pigId = UUID()
        manager.addFailedFacility(pigId, UUID())
        manager.setFailedCooldown(pigId, 5)
        manager.cleanupPig(pigId)
        #expect(manager.getFailedFacilities(pigId).isEmpty)
        #expect(manager.getFailedCooldown(pigId) == 0)
    }

    @Test("resetAll clears path cache and all pig tracking")
    func testResetAllClearsEverything() {
        let (manager, unusedState, unusedController) = makeManager()
        let pigId = UUID()
        manager.addFailedFacility(pigId, UUID())
        manager.setFailedCooldown(pigId, 5)
        let key = PathCacheKey(start: GridPosition(x: 0, y: 0), goal: GridPosition(x: 1, y: 0), generation: 0)
        manager.pathCache.set(key, path: [GridPosition(x: 0, y: 0)])
        manager.resetAll()
        #expect(manager.getFailedFacilities(pigId).isEmpty)
        #expect(manager.getFailedCooldown(pigId) == 0)
        #expect(manager.pathCache.isEmpty)
    }

    // MARK: - Area Population Tests

    @Test("updateAreaPopulations counts pigs in the same area correctly")
    func testUpdateAreaPopulationsCountsPigsPerArea() throws {
        let (manager, state, unusedController) = makeManager()
        let areaId = try #require(state.farm.areas.first?.id)

        var pig1 = pigAt(x: 5.0, y: 5.0)
        pig1.currentAreaId = areaId
        var pig2 = pigAt(x: 6.0, y: 6.0)
        pig2.currentAreaId = areaId
        state.addGuineaPig(pig1)
        state.addGuineaPig(pig2)

        manager.updateAreaPopulations()
        #expect(manager.areaPopulations[areaId] == 2)
    }

    // MARK: - getCandidateFacilitiesRanked Tests

    @Test("getCandidateFacilitiesRanked returns empty when facility type absent")
    func testGetCandidatesReturnsEmptyWhenNoFacilities() {
        let (manager, unusedState, unusedController) = makeManager()
        let pig = pigAt(x: 5.0, y: 5.0)
        let ranked = manager.getCandidateFacilitiesRanked(pig: pig, facilityType: .hotSpring)
        #expect(ranked.isEmpty)
    }

    @Test("getCandidateFacilitiesRanked omits pig's failed facilities")
    func testGetCandidatesFiltersFailedFacilities() {
        let (manager, state, unusedController) = makeManager()
        let facility = placeFacility(type: .foodBowl, x: 4, y: 9, state: state)
        let pig = pigAt(x: 5.0, y: 5.0)
        state.addGuineaPig(pig)
        manager.addFailedFacility(pig.id, facility.id)
        manager.updateAreaPopulations()
        let ranked = manager.getCandidateFacilitiesRanked(pig: pig, facilityType: .foodBowl)
        #expect(!ranked.contains { $0.id == facility.id })
    }

    // MARK: - findOpenInteractionPoint Tests

    @Test("findOpenInteractionPoint returns non-empty path when pig is at the point")
    func testFindOpenInteractionPointPigAtPoint() {
        let (manager, state, unusedController) = makeManager()
        let facility = placeFacility(type: .foodBowl, x: 5, y: 5, state: state)
        // Food bowl 2x1 at (5,5) → front interaction points: (5,6) and (6,6)
        let pig = pigAt(x: 5.0, y: 6.0)
        state.addGuineaPig(pig)

        let result = manager.findOpenInteractionPoint(pig: pig, facility: facility)

        #expect(result != nil)
        if let result {
            #expect(!result.path.isEmpty)
            #expect(result.point == GridPosition(x: 5, y: 6))
        }
    }

    @Test("findOpenInteractionPoint returns single-step path for adjacent pig")
    func testFindOpenInteractionPointPigOneStepAway() {
        let (manager, state, unusedController) = makeManager()
        let facility = placeFacility(type: .foodBowl, x: 5, y: 5, state: state)
        // Pig one cell south of front interaction point (5,6) → pig at (5,7)
        let pig = pigAt(x: 5.0, y: 7.0)
        state.addGuineaPig(pig)

        let result = manager.findOpenInteractionPoint(pig: pig, facility: facility)

        #expect(result != nil)
        if let result {
            #expect(!result.path.isEmpty)
            // Path should be just the interaction point (pig's start position trimmed)
            #expect(result.path.count == 1)
            #expect(result.path.first == GridPosition(x: 5, y: 6))
        }
    }

    @Test("getCandidateFacilitiesRanked omits empty consumable facilities")
    func testGetCandidatesFiltersEmptyConsumables() {
        let (manager, state, unusedController) = makeManager()
        var facility = placeFacility(type: .foodBowl, x: 4, y: 9, state: state)
        facility.currentAmount = 0
        state.facilities[facility.id] = facility
        let pig = pigAt(x: 5.0, y: 5.0)
        state.addGuineaPig(pig)
        manager.updateAreaPopulations()
        let ranked = manager.getCandidateFacilitiesRanked(pig: pig, facilityType: .foodBowl)
        #expect(ranked.isEmpty)
    }
}
