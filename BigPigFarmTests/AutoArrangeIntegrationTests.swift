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
