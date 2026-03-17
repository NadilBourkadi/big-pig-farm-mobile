/// AutoArrangeIntegrationTests — Apply arrangement, pig navigation, multi-area, and full cycles.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Farm State Helper

@MainActor
private func makeArrangeFarmState(tier: Int) -> GameState {
    let tierInfo = getTierUpgrade(tier: tier)
    let state = GameState()
    var farm = FarmGrid(width: tierInfo.roomWidth, height: tierInfo.roomHeight, tier: tier)
    let area = FarmArea(
        id: UUID(), name: "Room", biome: .meadow,
        x1: 0, y1: 0, x2: tierInfo.roomWidth - 1, y2: tierInfo.roomHeight - 1,
        isStarter: true
    )
    farm.addArea(area)
    state.farm = farm
    return state
}

@MainActor
private func addArrangeFacility(_ state: GameState, type: FacilityType, x: Int = 5, y: Int = 3) {
    _ = state.addFacility(Facility.create(type: type, x: x, y: y))
}

// MARK: - Apply Arrangement Tests

@Test @MainActor func applyArrangementPreservesFacilityState() {
    let state = makeArrangeFarmState(tier: 1)
    addArrangeFacility(state, type: .foodBowl)
    let originalFacility = state.getFacilitiesList()[0]
    let originalAmount = originalFacility.currentAmount
    let originalLevel = originalFacility.level
    let (placements, overflow) = AutoArrange.computeArrangement(state: state)
    AutoArrange.applyArrangement(state: state, placements: placements, overflow: overflow)
    let movedFacility = state.getFacility(originalFacility.id)
    #expect(movedFacility != nil)
    #expect(movedFacility?.currentAmount == originalAmount)
    #expect(movedFacility?.level == originalLevel)
}

@Test @MainActor func applyArrangementGridIsConsistent() {
    let state = makeArrangeFarmState(tier: 2)
    addArrangeFacility(state, type: .foodBowl)
    addArrangeFacility(state, type: .waterBottle)
    addArrangeFacility(state, type: .hideout)
    let (placements, overflow) = AutoArrange.computeArrangement(state: state)
    AutoArrange.applyArrangement(state: state, placements: placements, overflow: overflow)
    for facility in state.getFacilitiesList() {
        for cell in facility.cells {
            let gridCell = state.farm.getCell(cell.x, cell.y)
            #expect(
                gridCell?.facilityId == facility.id,
                "Grid cell at \(cell) not registered to \(facility.name)"
            )
        }
    }
}

@Test @MainActor func applyArrangementNoOverlapOnGrid() {
    let state = makeArrangeFarmState(tier: 3)
    for _ in 0..<6 {
        addArrangeFacility(state, type: .foodBowl)
    }
    addArrangeFacility(state, type: .hideout)
    addArrangeFacility(state, type: .waterBottle)
    let (placements, overflow) = AutoArrange.computeArrangement(state: state)
    AutoArrange.applyArrangement(state: state, placements: placements, overflow: overflow)
    var seen = Set<GridPosition>()
    for facility in state.getFacilitiesList() {
        for cell in facility.cells {
            #expect(!seen.contains(cell), "Grid overlap at \(cell) for \(facility.name)")
            seen.insert(cell)
        }
    }
}

// MARK: - Pig Navigation Tests

@Test @MainActor func clearPigNavigationResetsPaths() {
    let state = makeArrangeFarmState(tier: 1)
    var pig = GuineaPig.create(name: "Piggy", gender: .female)
    pig.position = Position(x: 5.0, y: 5.0)
    pig.behaviorState = .eating
    pig.path = [GridPosition(x: 3, y: 3), GridPosition(x: 4, y: 4)]
    pig.targetDescription = "some food"
    state.addGuineaPig(pig)
    AutoArrange.clearPigNavigation(state: state)
    let updatedPig = state.guineaPigs[pig.id]
    #expect(updatedPig?.path.isEmpty == true)
    #expect(updatedPig?.targetPosition == nil)
    #expect(updatedPig?.targetFacilityId == nil)
    #expect(updatedPig?.targetDescription == nil)
    #expect(updatedPig?.behaviorState == .idle)
}

@Test @MainActor func clearPigNavigationRelocatesPigOnFacilityCell() {
    let state = makeArrangeFarmState(tier: 1)
    addArrangeFacility(state, type: .hideout)
    let facility = state.getFacilitiesList()[0]
    var pig = GuineaPig.create(name: "Trapped", gender: .male)
    pig.position = Position(x: Double(facility.positionX), y: Double(facility.positionY))
    state.addGuineaPig(pig)
    AutoArrange.clearPigNavigation(state: state)
    let movedPig = state.guineaPigs[pig.id]
    let gridPos = movedPig?.position.gridPosition
    if let gp = gridPos {
        #expect(state.farm.isWalkable(gp.x, gp.y), "Pig should be on walkable cell after clear")
    }
}

// MARK: - Full Cycle Integration Tests

@Test @MainActor func fullCycleTier1NoOverlap() {
    let state = makeArrangeFarmState(tier: 1)
    addArrangeFacility(state, type: .foodBowl)
    addArrangeFacility(state, type: .waterBottle)
    addArrangeFacility(state, type: .hideout)
    addArrangeFacility(state, type: .exerciseWheel)
    let (placements, overflow) = AutoArrange.computeArrangement(state: state)
    AutoArrange.applyArrangement(state: state, placements: placements, overflow: overflow)
    var seen = Set<GridPosition>()
    for facility in state.getFacilitiesList() {
        for cell in facility.cells {
            #expect(!seen.contains(cell), "Overlap at \(cell)")
            seen.insert(cell)
        }
    }
}

@Test @MainActor func fullCycleTier4MixedFacilities() {
    let state = makeArrangeFarmState(tier: 4)
    for _ in 0..<3 {
        addArrangeFacility(state, type: .foodBowl)
        addArrangeFacility(state, type: .waterBottle)
        addArrangeFacility(state, type: .hideout)
        addArrangeFacility(state, type: .exerciseWheel)
    }
    addArrangeFacility(state, type: .breedingDen)
    addArrangeFacility(state, type: .geneticsLab)
    let totalCount = state.getFacilitiesList().count
    let (placements, overflow) = AutoArrange.computeArrangement(state: state)
    AutoArrange.applyArrangement(state: state, placements: placements, overflow: overflow)
    #expect(placements.count + overflow.count == totalCount)
    var seen = Set<GridPosition>()
    for facility in state.getFacilitiesList() {
        for cell in facility.cells {
            #expect(!seen.contains(cell), "Overlap at \(cell) for \(facility.name)")
            seen.insert(cell)
        }
    }
}

// MARK: - Multi-Area Tests

@Test @MainActor func multiAreaArrangementAllFacilitiesAccountedFor() {
    var grid = makeTwoRoomGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    grid.tunnels.append(contentsOf: tunnels)
    let state = GameState()
    state.farm = grid
    for _ in 0..<4 {
        addArrangeFacility(state, type: .foodBowl)
        addArrangeFacility(state, type: .waterBottle)
        addArrangeFacility(state, type: .hideout)
        addArrangeFacility(state, type: .exerciseWheel)
    }
    addArrangeFacility(state, type: .breedingDen)
    let totalCount = state.getFacilitiesList().count
    let (placements, overflow) = AutoArrange.computeArrangement(state: state)
    #expect(placements.count + overflow.count == totalCount)
}

@Test @MainActor func multiAreaArrangementNoOverlap() {
    var grid = makeTwoRoomGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    grid.tunnels.append(contentsOf: tunnels)
    let state = GameState()
    state.farm = grid
    for _ in 0..<4 {
        addArrangeFacility(state, type: .foodBowl)
        addArrangeFacility(state, type: .waterBottle)
        addArrangeFacility(state, type: .hideout)
        addArrangeFacility(state, type: .exerciseWheel)
    }
    let (placements, overflow) = AutoArrange.computeArrangement(state: state)
    AutoArrange.applyArrangement(state: state, placements: placements, overflow: overflow)
    var seen = Set<GridPosition>()
    for facility in state.getFacilitiesList() {
        for cell in facility.cells {
            #expect(!seen.contains(cell), "Overlap at \(cell) for \(facility.name)")
            seen.insert(cell)
        }
    }
}

// MARK: - Facility Preservation Tests

@Test @MainActor func applyArrangementNeverLosesFacilities() {
    let state = makeArrangeFarmState(tier: 1)
    // Pack a small tier-1 farm (18x18) with many facilities including large ones
    addArrangeFacility(state, type: .foodBowl, x: 1, y: 1)
    addArrangeFacility(state, type: .waterBottle, x: 3, y: 1)
    addArrangeFacility(state, type: .hideout, x: 5, y: 1)
    addArrangeFacility(state, type: .exerciseWheel, x: 9, y: 1)
    addArrangeFacility(state, type: .feastTable, x: 1, y: 5)
    addArrangeFacility(state, type: .campfire, x: 7, y: 5)
    addArrangeFacility(state, type: .breedingDen, x: 1, y: 11)
    let countBefore = state.getFacilitiesList().count
    let idsBefore = Set(state.facilities.keys)
    let (placements, overflow) = AutoArrange.computeArrangement(state: state)
    AutoArrange.applyArrangement(state: state, placements: placements, overflow: overflow)
    let countAfter = state.getFacilitiesList().count
    let idsAfter = Set(state.facilities.keys)
    #expect(countAfter == countBefore, "Facilities lost: \(countBefore) → \(countAfter)")
    #expect(idsAfter == idsBefore, "Facility IDs changed after auto-arrange")
}

@Test @MainActor func applyArrangementPreservesLargeFacilitiesOnSmallFarm() {
    let state = makeArrangeFarmState(tier: 1)
    // Two 5x5 + one 6x6 on an 18x18 farm is very tight
    addArrangeFacility(state, type: .feastTable, x: 1, y: 1)
    addArrangeFacility(state, type: .campfire, x: 7, y: 1)
    addArrangeFacility(state, type: .hotSpring, x: 1, y: 7)
    let countBefore = state.getFacilitiesList().count
    let (placements, overflow) = AutoArrange.computeArrangement(state: state)
    AutoArrange.applyArrangement(state: state, placements: placements, overflow: overflow)
    let countAfter = state.getFacilitiesList().count
    #expect(countAfter == countBefore, "Large facilities lost: \(countBefore) → \(countAfter)")
}

@Test @MainActor func applyArrangementPreservesAllFacilitiesNearCapacity() {
    let state = makeArrangeFarmState(tier: 2)
    // Fill a tier-2 farm (21x21) with many small + large facilities
    for idx in 0..<6 {
        addArrangeFacility(state, type: .foodBowl, x: 1 + idx * 2, y: 1)
    }
    for idx in 0..<4 {
        addArrangeFacility(state, type: .waterBottle, x: 1 + idx * 2, y: 3)
    }
    addArrangeFacility(state, type: .feastTable, x: 1, y: 5)
    addArrangeFacility(state, type: .therapyGarden, x: 7, y: 5)
    addArrangeFacility(state, type: .hideout, x: 13, y: 5)
    addArrangeFacility(state, type: .exerciseWheel, x: 1, y: 11)
    addArrangeFacility(state, type: .breedingDen, x: 5, y: 11)
    let countBefore = state.getFacilitiesList().count
    let (placements, overflow) = AutoArrange.computeArrangement(state: state)
    AutoArrange.applyArrangement(state: state, placements: placements, overflow: overflow)
    let countAfter = state.getFacilitiesList().count
    #expect(countAfter == countBefore, "Facilities lost near capacity: \(countBefore) → \(countAfter)")
}

@Test @MainActor func findGridPositionUsesOpenCellCheck() {
    // Verify findGridPosition finds spots among facility-occupied cells
    let state = makeArrangeFarmState(tier: 1)
    // Place a facility to make some cells non-walkable but facility-occupied
    addArrangeFacility(state, type: .foodBowl, x: 2, y: 2)
    let target = Facility.create(type: .foodBowl, x: 0, y: 0)
    // Should find a position even though some cells are facility-occupied
    let pos = AutoArrange.findGridPosition(for: target, in: state.farm)
    #expect(pos != nil, "findGridPosition should find open cells near facility-occupied ones")
    if let pos {
        #expect(state.farm.isCellOpenForFacility(pos.x, pos.y))
    }
}

// MARK: - isCellOpenForFacility Tests

@Test @MainActor func isCellOpenForFacilityDistinguishesWallsFromFacilities() {
    var farm = FarmGrid.createStarter()
    let facility = Facility.create(type: .foodBowl, x: 3, y: 3)
    _ = farm.placeFacility(facility)
    // Wall cell: not open
    #expect(!farm.isCellOpenForFacility(0, 0))
    // Facility cell: not open
    #expect(!farm.isCellOpenForFacility(3, 3))
    // Empty interior cell: open
    #expect(farm.isCellOpenForFacility(5, 5))
    // Importantly: isWalkable is false for BOTH walls and facilities
    #expect(!farm.isWalkable(0, 0))
    #expect(!farm.isWalkable(3, 3))
}

// MARK: - findNearestWalkable Tests

@Test @MainActor func findNearestWalkableFindsAdjacentCell() {
    var farm = FarmGrid.createStarter()
    let pos = GridPosition(x: 3, y: 3)
    let facility = Facility.create(type: .foodBowl, x: 3, y: 3)
    _ = farm.placeFacility(facility)
    if let nearest = farm.findNearestWalkable(pos) {
        #expect(farm.isWalkable(nearest.x, nearest.y))
    }
}

@Test @MainActor func findNearestWalkableReturnsNilWhenMaxDistanceIsZero() {
    let farm = FarmGrid.createStarter()
    let result = farm.findNearestWalkable(GridPosition(x: 5, y: 5), maxDistance: 0)
    #expect(result == nil)
}
