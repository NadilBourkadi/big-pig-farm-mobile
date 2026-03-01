// ContentViewTests — Tests for FarmSceneCoordinator and setupNewGame bootstrapping.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - FarmSceneCoordinator Tests

@Suite("FarmSceneCoordinator")
@MainActor
struct FarmSceneCoordinatorTests {

    let state = GameState()
    var coord: FarmSceneCoordinator { FarmSceneCoordinator(gameState: state) }
    var scene: FarmScene { FarmScene(gameState: state) }

    @Test("Pig selected triggers onPigSelected callback with correct ID")
    func pigSelectedCallbackFired() {
        let coordinator = coord
        let farmScene = scene
        var capturedID: UUID?
        coordinator.onPigSelected = { capturedID = $0 }
        let testID = UUID()
        coordinator.farmScene(farmScene, didSelectPig: testID)
        #expect(capturedID == testID)
    }

    @Test("Pig deselected triggers onPigDeselected callback")
    func pigDeselectedCallbackFired() {
        let coordinator = coord
        let farmScene = scene
        var called = false
        coordinator.onPigDeselected = { called = true }
        coordinator.farmSceneDidDeselectPig(farmScene)
        #expect(called)
    }

    @Test("Pig selected with no callback registered does not crash")
    func pigSelectedNoCallbackNoCrash() {
        coord.farmScene(scene, didSelectPig: UUID())
    }

    @Test("Pig deselected with no callback registered does not crash")
    func pigDeselectedNoCallbackNoCrash() {
        coord.farmSceneDidDeselectPig(scene)
    }

    @Test("Facility selected does not crash (edit mode — no sheet)")
    func facilitySelectedDoesNotCrash() {
        coord.farmScene(scene, didSelectFacility: UUID())
    }

    @Test("Removing facility that exists refunds its cost")
    func facilityRemovedRefundsCost() {
        let initialMoney = state.money
        let facility = Facility.create(type: .foodBowl, x: 3, y: 3)
        _ = state.addFacility(facility)
        let coordinator = FarmSceneCoordinator(gameState: state)

        coordinator.farmScene(scene, didRemoveFacility: facility.id)

        let refund = Shop.getFacilityCost(facilityType: .foodBowl)
        #expect(state.money == initialMoney + refund)
        #expect(state.facilities[facility.id] == nil)
    }

    @Test("Removing facility logs event")
    func facilityRemovedLogsEvent() {
        let facility = Facility.create(type: .foodBowl, x: 3, y: 3)
        _ = state.addFacility(facility)
        let coordinator = FarmSceneCoordinator(gameState: state)

        coordinator.farmScene(scene, didRemoveFacility: facility.id)

        #expect(state.events.contains { $0.eventType == "purchase" && $0.message.contains("Removed") })
    }

    @Test("Removing facility that does not exist is a no-op")
    func facilityRemovedNotFoundIsNoOp() {
        let initialMoney = state.money
        coord.farmScene(scene, didRemoveFacility: UUID())
        #expect(state.money == initialMoney)
    }
}

// MARK: - SetupNewGame Tests

@Suite("SetupNewGame Bootstrapping")
@MainActor
struct SetupNewGameTests {

    @Test("New game starts with exactly two pigs")
    func newGameHasTwoPigs() {
        let state = GameState()
        setupNewGame(state: state)
        #expect(state.guineaPigs.count == 2)
    }

    @Test("New game has exactly one male and one female")
    func newGameHasOneMaleOneFemale() {
        let state = GameState()
        setupNewGame(state: state)
        let pigs = state.getPigsList()
        let males = pigs.filter { $0.gender == .male }
        let females = pigs.filter { $0.gender == .female }
        #expect(males.count == 1)
        #expect(females.count == 1)
    }

    @Test("New game pigs start as young adults (age >= adultAgeDays)")
    func newGamePigsAreAdults() {
        let state = GameState()
        setupNewGame(state: state)
        let adultAge = Double(GameConfig.Simulation.adultAgeDays)
        for pig in state.getPigsList() {
            #expect(pig.ageDays >= adultAge, "Pig \(pig.name) should be adult, age=\(pig.ageDays)")
        }
    }

    @Test("New game places at least three starter facilities")
    func newGamePlacesStarterFacilities() {
        let state = GameState()
        setupNewGame(state: state)
        #expect(state.facilities.count >= 3)
    }

    @Test("New game includes a food bowl facility")
    func newGameHasFoodBowl() {
        let state = GameState()
        setupNewGame(state: state)
        let foodBowls = state.getFacilitiesByType(.foodBowl)
        #expect(!foodBowls.isEmpty)
    }

    @Test("New game includes a water bottle facility")
    func newGameHasWaterBottle() {
        let state = GameState()
        setupNewGame(state: state)
        let waterBottles = state.getFacilitiesByType(.waterBottle)
        #expect(!waterBottles.isEmpty)
    }

    @Test("New game logs a welcome event")
    func newGameLogsWelcomeEvent() {
        let state = GameState()
        setupNewGame(state: state)
        #expect(state.events.contains { $0.message.contains("Welcome") })
    }

    @Test("New game pig names are unique")
    func newGamePigNamesAreUnique() {
        let state = GameState()
        setupNewGame(state: state)
        let names = state.getPigsList().map(\.name)
        #expect(Set(names).count == names.count)
    }
}
