/// AutoArrangeTests — Zone calculation, neighborhood count, and single-pass layout tests.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Farm State Helpers

@MainActor
private func makeFarmState(tier: Int) -> GameState {
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
private func addFacility(_ state: GameState, type: FacilityType, x: Int = 5, y: Int = 3) {
    let facility = Facility.create(type: type, x: x, y: y)
    _ = state.addFacility(facility)
}

// MARK: - Farm Classification Tests

@Test @MainActor func isSmallFarmTier1() {
    let tierInfo = getTierUpgrade(tier: 1)
    var farm = FarmGrid(width: tierInfo.roomWidth, height: tierInfo.roomHeight, tier: 1)
    farm.createLegacyStarterArea()
    #expect(AutoArrange.isSmallFarm(farm) == true)
}

@Test @MainActor func isSmallFarmTier2() {
    let tierInfo = getTierUpgrade(tier: 2)
    var farm = FarmGrid(width: tierInfo.roomWidth, height: tierInfo.roomHeight, tier: 2)
    let area = FarmArea(
        id: UUID(), name: "Room", biome: .meadow,
        x1: 0, y1: 0, x2: tierInfo.roomWidth - 1, y2: tierInfo.roomHeight - 1, isStarter: true
    )
    farm.addArea(area)
    #expect(AutoArrange.isSmallFarm(farm) == true)
}

@Test @MainActor func isLargeFarmTier3() {
    let tierInfo = getTierUpgrade(tier: 3)
    var farm = FarmGrid(width: tierInfo.roomWidth, height: tierInfo.roomHeight, tier: 3)
    let area = FarmArea(
        id: UUID(), name: "Room", biome: .meadow,
        x1: 0, y1: 0, x2: tierInfo.roomWidth - 1, y2: tierInfo.roomHeight - 1, isStarter: true
    )
    farm.addArea(area)
    #expect(AutoArrange.isSmallFarm(farm) == false)
}

// MARK: - Zone Calculation Tests

@Test @MainActor func smallFarmProduces3Zones() {
    let farm = FarmGrid.createStarter()
    let zones = AutoArrange.calculateZones(farm: farm)
    #expect(zones.count == 3)
    let names = Set(zones.map { $0.name })
    #expect(names.contains("feeding"))
    #expect(names.contains("rest"))
    #expect(names.contains("utility"))
}

@Test @MainActor func zonesWithinFarmBounds() {
    let farm = FarmGrid.createStarter()
    let zones = AutoArrange.calculateZones(farm: farm)
    for zone in zones {
        #expect(zone.x1 >= 1)
        #expect(zone.y1 >= 1)
        #expect(zone.x2 <= farm.width - 2)
        #expect(zone.y2 <= farm.height - 2)
    }
}

@Test @MainActor func zonesNoOverlap() {
    let farm = FarmGrid.createStarter()
    let zones = AutoArrange.calculateZones(farm: farm)
    for idx1 in 0..<zones.count {
        for idx2 in (idx1 + 1)..<zones.count {
            let zone1 = zones[idx1]
            let zone2 = zones[idx2]
            let xOverlap = zone1.x1 <= zone2.x2 && zone2.x1 <= zone1.x2
            let yOverlap = zone1.y1 <= zone2.y2 && zone2.y1 <= zone1.y2
            #expect(!(xOverlap && yOverlap), "Zones \(zone1.name) and \(zone2.name) overlap")
        }
    }
}

@Test @MainActor func neighborhoodZonesWithinBounds() {
    let tierInfo = getTierUpgrade(tier: 3)
    var farm = FarmGrid(width: tierInfo.roomWidth, height: tierInfo.roomHeight, tier: 3)
    let area = FarmArea(
        id: UUID(), name: "Room", biome: .meadow,
        x1: 0, y1: 0, x2: tierInfo.roomWidth - 1, y2: tierInfo.roomHeight - 1, isStarter: true
    )
    farm.addArea(area)
    let zones = AutoArrange.calculateNeighborhoodZones(farm: farm, numNeighborhoods: 2)
    for zone in zones {
        #expect(zone.x1 >= 1)
        #expect(zone.y1 >= 1)
        #expect(zone.x2 <= farm.width - 2)
        #expect(zone.y2 <= farm.height - 2)
    }
}

@Test @MainActor func neighborhoodZonesNoOverlap() {
    let tierInfo = getTierUpgrade(tier: 4)
    var farm = FarmGrid(width: tierInfo.roomWidth, height: tierInfo.roomHeight, tier: 4)
    let area = FarmArea(
        id: UUID(), name: "Room", biome: .meadow,
        x1: 0, y1: 0, x2: tierInfo.roomWidth - 1, y2: tierInfo.roomHeight - 1, isStarter: true
    )
    farm.addArea(area)
    let zones = AutoArrange.calculateNeighborhoodZones(farm: farm, numNeighborhoods: 4)
    for idx1 in 0..<zones.count {
        for idx2 in (idx1 + 1)..<zones.count {
            let zone1 = zones[idx1]
            let zone2 = zones[idx2]
            let xOverlap = zone1.x1 <= zone2.x2 && zone2.x1 <= zone1.x2
            let yOverlap = zone1.y1 <= zone2.y2 && zone2.y1 <= zone1.y2
            #expect(!(xOverlap && yOverlap), "Zones \(zone1.name) and \(zone2.name) overlap")
        }
    }
}

@Test @MainActor func neighborhoodZoneCountEqualsNeighborhoodsPlusUtility() {
    let tierInfo = getTierUpgrade(tier: 5)
    var farm = FarmGrid(width: tierInfo.roomWidth, height: tierInfo.roomHeight, tier: 5)
    let area = FarmArea(
        id: UUID(), name: "Room", biome: .meadow,
        x1: 0, y1: 0, x2: tierInfo.roomWidth - 1, y2: tierInfo.roomHeight - 1, isStarter: true
    )
    farm.addArea(area)
    for numNeighborhoods in 1...4 {
        let zones = AutoArrange.calculateNeighborhoodZones(farm: farm, numNeighborhoods: numNeighborhoods)
        #expect(
            zones.count == numNeighborhoods + 1,
            "Expected \(numNeighborhoods + 1) zones for \(numNeighborhoods) neighborhoods"
        )
    }
}

// MARK: - Neighborhood Count Tests

@Test @MainActor func neighborhoodCountMinAcrossCategories() {
    let facilities: [Facility] = [
        Facility.create(type: .foodBowl, x: 1, y: 1),
        Facility.create(type: .foodBowl, x: 5, y: 1),
        Facility.create(type: .foodBowl, x: 9, y: 1),
        Facility.create(type: .waterBottle, x: 1, y: 5),
        Facility.create(type: .waterBottle, x: 5, y: 5),
        Facility.create(type: .hideout, x: 1, y: 9),
        Facility.create(type: .exerciseWheel, x: 5, y: 9),
        Facility.create(type: .exerciseWheel, x: 9, y: 9),
    ]
    // food=3, water=2, rest=1, play=2 → min=1
    #expect(AutoArrange.determineNeighborhoodCount(facilities: facilities) == 1)
}

@Test @MainActor func neighborhoodCountBalanced() {
    let facilities: [Facility] = [
        Facility.create(type: .foodBowl, x: 1, y: 1),
        Facility.create(type: .foodBowl, x: 5, y: 1),
        Facility.create(type: .waterBottle, x: 1, y: 5),
        Facility.create(type: .waterBottle, x: 5, y: 5),
        Facility.create(type: .hideout, x: 1, y: 9),
        Facility.create(type: .hideout, x: 5, y: 9),
        Facility.create(type: .exerciseWheel, x: 1, y: 13),
        Facility.create(type: .exerciseWheel, x: 5, y: 13),
    ]
    // food=2, water=2, rest=2, play=2 → min=2
    #expect(AutoArrange.determineNeighborhoodCount(facilities: facilities) == 2)
}

@Test @MainActor func neighborhoodCountCappedAt4() {
    var facilities: [Facility] = []
    for idx in 0..<6 {
        facilities.append(Facility.create(type: .foodBowl, x: idx * 3 + 1, y: 1))
        facilities.append(Facility.create(type: .waterBottle, x: idx * 3 + 1, y: 5))
        facilities.append(Facility.create(type: .hideout, x: idx * 3 + 1, y: 9))
        facilities.append(Facility.create(type: .exerciseWheel, x: idx * 3 + 1, y: 13))
    }
    // all categories have 6, min=6, capped at 4
    #expect(AutoArrange.determineNeighborhoodCount(facilities: facilities) == 4)
}

@Test @MainActor func utilityOnlyFacilitiesGiveOneNeighborhood() {
    let facilities: [Facility] = [
        Facility.create(type: .breedingDen, x: 1, y: 1),
        Facility.create(type: .nursery, x: 5, y: 1),
        Facility.create(type: .groomingStation, x: 9, y: 1),
    ]
    // no essential categories → 1
    #expect(AutoArrange.determineNeighborhoodCount(facilities: facilities) == 1)
}

// MARK: - Empty Farm Tests

@Test @MainActor func emptyFarmReturnsEmpty() {
    let state = makeFarmState(tier: 1)
    let (placements, overflow) = AutoArrange.computeArrangement(state: state)
    #expect(placements.isEmpty)
    #expect(overflow.isEmpty)
}

// MARK: - Single Facility Tests

@Test @MainActor func singleFacilityPlaced() {
    let state = makeFarmState(tier: 1)
    addFacility(state, type: .foodBowl)
    let (placements, overflow) = AutoArrange.computeArrangement(state: state)
    #expect(placements.count == 1)
    #expect(overflow.isEmpty)
}

@Test @MainActor func singleFacilityWithinFarmBounds() {
    let state = makeFarmState(tier: 1)
    addFacility(state, type: .hideout)
    let (placements, overflow) = AutoArrange.computeArrangement(state: state)
    let farm = state.farm
    for placement in placements {
        let facility = placement.facility
        #expect(placement.newX >= 1)
        #expect(placement.newY >= 1)
        #expect(placement.newX + facility.width - 1 <= farm.width - 2)
        #expect(placement.newY + facility.height < farm.height - 1)
    }
    _ = overflow
}

// MARK: - No Overlap Tests

@Test @MainActor func multipleFacilitiesNoOverlap() {
    let state = makeFarmState(tier: 1)
    for _ in 0..<5 {
        addFacility(state, type: .foodBowl)
    }
    let (placements, _) = AutoArrange.computeArrangement(state: state)
    var occupiedCells = Set<GridPosition>()
    for placement in placements {
        let facility = placement.facility
        for dy in 0..<facility.height {
            for dx in 0..<facility.width {
                let cell = GridPosition(x: placement.newX + dx, y: placement.newY + dy)
                #expect(!occupiedCells.contains(cell), "Facility overlap at \(cell)")
                occupiedCells.insert(cell)
            }
        }
    }
}

// MARK: - Total Conservation Tests

@Test @MainActor func totalPlacedPlusOverflowEqualsTotal() {
    let state = makeFarmState(tier: 1)
    for _ in 0..<10 {
        addFacility(state, type: .hideout)
    }
    let totalFacilities = state.getFacilitiesList().count
    let (placements, overflow) = AutoArrange.computeArrangement(state: state)
    #expect(placements.count + overflow.count == totalFacilities)
}

// MARK: - Zone Assignment Tests

@Test @MainActor func waterBottlePlacedInFeedingZoneOnSmallFarm() {
    let state = makeFarmState(tier: 1)
    addFacility(state, type: .waterBottle)
    let zones = AutoArrange.calculateZones(farm: state.farm)
    guard let feedingZone = zones.first(where: { $0.name == "feeding" }) else {
        Issue.record("No feeding zone found")
        return
    }
    let (placements, _) = AutoArrange.computeArrangement(state: state)
    for placement in placements where placement.facility.facilityType == .waterBottle {
        #expect(
            placement.newX >= feedingZone.x1 && placement.newX <= feedingZone.x2
                && placement.newY >= feedingZone.y1 && placement.newY <= feedingZone.y2,
            "Water bottle should be in feeding zone on small farm"
        )
    }
}
