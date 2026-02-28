/// FacilityManagerTests — Path cache, failure tracking, area populations, and candidate ranking.
import Foundation
import Testing
@testable import BigPigFarm

@MainActor
struct FacilityManagerTests {

    // MARK: - Helpers

    func makeManager() -> (FacilityManager, GameState) {
        let state = makeGameState()
        let controller = makeController(state: state)
        return (controller.facilityManager, state)
    }

    func placeFacility(type: FacilityType, x: Int, y: Int, state: GameState) -> Facility {
        let facility = Facility.create(type: type, x: x, y: y)
        let placed = state.addFacility(facility)
        precondition(placed, "Failed to place \(type) at (\(x), \(y))")
        return state.getFacility(facility.id)!
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
        let (manager, _) = makeManager()
        let pos = GridPosition(x: 5, y: 5)
        let result = manager.cachedFindPath(from: pos, to: pos)
        #expect(result == [pos])
    }

    @Test("cachedFindPath increments cacheHits on repeated call")
    func testCachedFindPathIncrementsCacheHits() {
        let (manager, _) = makeManager()
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
        let (manager, _) = makeManager()
        let start = GridPosition(x: 5, y: 5)
        let goal = GridPosition(x: 5, y: 6)
        let result = manager.tryStraightLine(from: start, to: goal)
        #expect(result != nil)
        #expect(result?.last == goal)
    }

    // MARK: - Failure Tracking Tests

    @Test("addFailedFacility then getFailedFacilities returns the ID")
    func testAddFailedFacilityAndGet() {
        let (manager, _) = makeManager()
        let pigId = UUID()
        let facilityId = UUID()
        manager.addFailedFacility(pigId, facilityId)
        #expect(manager.getFailedFacilities(pigId).contains(facilityId))
    }

    @Test("clearFailedFacilities removes all entries for a pig")
    func testClearFailedFacilities() {
        let (manager, _) = makeManager()
        let pigId = UUID()
        manager.addFailedFacility(pigId, UUID())
        manager.clearFailedFacilities(pigId)
        #expect(manager.getFailedFacilities(pigId).isEmpty)
    }

    @Test("tickFailedCooldown clears failed list when cooldown expires")
    func testTickFailedCooldownClearsWhenExpired() {
        let (manager, _) = makeManager()
        let pigId = UUID()
        manager.addFailedFacility(pigId, UUID())
        manager.setFailedCooldown(pigId, 1)
        manager.tickFailedCooldown(pigId)
        #expect(manager.getFailedFacilities(pigId).isEmpty)
        #expect(manager.getFailedCooldown(pigId) == 0)
    }

    @Test("tickFailedCooldown decrements but keeps failed list when not expired")
    func testTickFailedCooldownDecrements() {
        let (manager, _) = makeManager()
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
        let (manager, _) = makeManager()
        let pigId = UUID()
        manager.addFailedFacility(pigId, UUID())
        manager.setFailedCooldown(pigId, 5)
        manager.cleanupPig(pigId)
        #expect(manager.getFailedFacilities(pigId).isEmpty)
        #expect(manager.getFailedCooldown(pigId) == 0)
    }

    @Test("resetAll clears path cache and all pig tracking")
    func testResetAllClearsEverything() {
        let (manager, _) = makeManager()
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
    func testUpdateAreaPopulationsCountsPigsPerArea() {
        let (manager, state) = makeManager()
        let areaId = state.farm.areas.first?.id
        #expect(areaId != nil)

        var pig1 = pigAt(x: 5.0, y: 5.0)
        pig1.currentAreaId = areaId
        var pig2 = pigAt(x: 6.0, y: 6.0)
        pig2.currentAreaId = areaId
        state.addGuineaPig(pig1)
        state.addGuineaPig(pig2)

        manager.updateAreaPopulations()
        #expect(manager.areaPopulations[areaId!] == 2)
    }

    // MARK: - getCandidateFacilitiesRanked Tests

    @Test("getCandidateFacilitiesRanked returns empty when facility type absent")
    func testGetCandidatesReturnsEmptyWhenNoFacilities() {
        let (manager, _) = makeManager()
        let pig = pigAt(x: 5.0, y: 5.0)
        let ranked = manager.getCandidateFacilitiesRanked(pig: pig, facilityType: .hotSpring)
        #expect(ranked.isEmpty)
    }

    @Test("getCandidateFacilitiesRanked omits pig's failed facilities")
    func testGetCandidatesFiltersFailedFacilities() {
        let (manager, state) = makeManager()
        let facility = placeFacility(type: .foodBowl, x: 4, y: 9, state: state)
        let pig = pigAt(x: 5.0, y: 5.0)
        state.addGuineaPig(pig)
        manager.addFailedFacility(pig.id, facility.id)
        manager.updateAreaPopulations()
        let ranked = manager.getCandidateFacilitiesRanked(pig: pig, facilityType: .foodBowl)
        #expect(!ranked.contains { $0.id == facility.id })
    }

    @Test("getCandidateFacilitiesRanked omits empty consumable facilities")
    func testGetCandidatesFiltersEmptyConsumables() {
        let (manager, state) = makeManager()
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
