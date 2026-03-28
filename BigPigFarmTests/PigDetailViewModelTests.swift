/// PigDetailViewModelTests — Tests for PigDetailViewModel domain lookups.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Basic Info

@Suite("PigDetailViewModel — Basic Info")
@MainActor
struct PigDetailViewModelBasicInfoTests {

    @Test("valueBreakdown returns a total greater than zero for adult pig")
    func valueBreakdownReturnsTotal() {
        let state = makeGameState()
        var pig = GuineaPig.create(name: "Biscuit", gender: .female)
        pig.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        state.addGuineaPig(pig)
        let vm = PigDetailViewModel(gameState: state, pig: pig)
        #expect(vm.valueBreakdown.total > 0)
    }

    @Test("hasGeneticsLab returns false when no lab exists")
    func hasGeneticsLabFalse() {
        let state = makeGameState()
        let pig = GuineaPig.create(name: "Biscuit", gender: .female)
        let vm = PigDetailViewModel(gameState: state, pig: pig)
        #expect(vm.hasGeneticsLab == false)
    }

    @Test("hasGeneticsLab returns true when lab exists")
    func hasGeneticsLabTrue() {
        let state = makeGameState()
        _ = state.addFacility(Facility.create(type: .geneticsLab, x: 2, y: 2))
        let pig = GuineaPig.create(name: "Biscuit", gender: .female)
        let vm = PigDetailViewModel(gameState: state, pig: pig)
        #expect(vm.hasGeneticsLab == true)
    }

    @Test("ageDescription includes age group label")
    func ageDescriptionIncludesGroup() {
        let state = makeGameState()
        var pig = GuineaPig.create(name: "Biscuit", gender: .female)
        pig.ageDays = 5.0
        let vm = PigDetailViewModel(gameState: state, pig: pig)
        #expect(vm.ageDescription.contains("Baby"))
    }

    @Test("ageDescription shows Adult for adult pig")
    func ageDescriptionAdult() {
        let state = makeGameState()
        var pig = GuineaPig.create(name: "Biscuit", gender: .female)
        pig.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        let vm = PigDetailViewModel(gameState: state, pig: pig)
        #expect(vm.ageDescription.contains("Adult"))
    }
}

// MARK: - Area Names

@Suite("PigDetailViewModel — Area Names")
@MainActor
struct PigDetailViewModelAreaTests {

    @Test("areaName returns Unknown when pig has no area")
    func areaNameUnknown() {
        let state = makeGameState()
        let pig = GuineaPig.create(name: "Biscuit", gender: .female)
        let vm = PigDetailViewModel(gameState: state, pig: pig)
        #expect(vm.areaName == "Unknown")
    }

    @Test("areaName returns area name when pig has valid area")
    func areaNameValid() {
        let state = makeGameState()
        var pig = GuineaPig.create(name: "Biscuit", gender: .female)
        pig.currentAreaId = state.farm.areas.first?.id
        let vm = PigDetailViewModel(gameState: state, pig: pig)
        #expect(vm.areaName != "Unknown")
    }

    @Test("birthAreaName returns Unknown when pig has no birth area")
    func birthAreaNameUnknown() {
        let state = makeGameState()
        let pig = GuineaPig.create(name: "Biscuit", gender: .female)
        let vm = PigDetailViewModel(gameState: state, pig: pig)
        #expect(vm.birthAreaName == "Unknown")
    }
}

// MARK: - Parent Names

@Suite("PigDetailViewModel — Parent Names")
@MainActor
struct PigDetailViewModelParentTests {

    @Test("parentName returns adopted label for nil ID")
    func parentNameNilID() {
        let state = makeGameState()
        let pig = GuineaPig.create(name: "Biscuit", gender: .female)
        let vm = PigDetailViewModel(gameState: state, pig: pig)
        #expect(vm.parentName(id: nil) == "Unknown (adopted/starter)")
    }

    @Test("parentName returns parent name when found")
    func parentNameFound() {
        let state = makeGameState()
        let mom = GuineaPig.create(name: "Mama", gender: .female)
        state.addGuineaPig(mom)
        let pig = GuineaPig.create(name: "Baby", gender: .male)
        let vm = PigDetailViewModel(gameState: state, pig: pig)
        #expect(vm.parentName(id: mom.id) == "Mama")
    }

    @Test("parentName returns not-on-farm label for unknown ID")
    func parentNameNotFound() {
        let state = makeGameState()
        let pig = GuineaPig.create(name: "Biscuit", gender: .female)
        let vm = PigDetailViewModel(gameState: state, pig: pig)
        #expect(vm.parentName(id: UUID()) == "Unknown (no longer on farm)")
    }
}

// MARK: - Live Log

@Suite("PigDetailViewModel — Live Log")
@MainActor
struct PigDetailViewModelLiveLogTests {

    @Test("liveLog returns pig behavior log when pig exists in state")
    func liveLogFromState() {
        let state = makeGameState()
        var pig = GuineaPig.create(name: "Biscuit", gender: .female)
        pig.behaviorLog = ["Ate food", "Drank water"]
        state.addGuineaPig(pig)
        let vm = PigDetailViewModel(gameState: state, pig: pig)
        #expect(vm.liveLog.count == 2)
    }

    @Test("liveLog falls back to pig's own log when not in state")
    func liveLogFallback() {
        let state = makeGameState()
        var pig = GuineaPig.create(name: "Ghost", gender: .male)
        pig.behaviorLog = ["Old entry"]
        // Don't add pig to state — simulates pig removed after detail opened
        let vm = PigDetailViewModel(gameState: state, pig: pig)
        #expect(vm.liveLog == ["Old entry"])
    }
}
