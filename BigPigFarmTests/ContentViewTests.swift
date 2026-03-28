// ContentViewTests — Tests for setupNewGame bootstrapping.
// FarmSceneCoordinator tests moved to ContentViewModelTests.swift.
import Testing
import Foundation
@testable import BigPigFarm

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
