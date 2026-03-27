/// NewGameSetup — Place starter pigs and facilities in a fresh game state.
/// Extracted from BigPigFarmApp.swift so it is accessible from BigPigFarmCore
/// (used by GameEngine.farmReset).
import Foundation

/// Place two starter pigs and basic facilities in a fresh game state.
///
/// Maps from: app.py initial setup and new_game.py (Python source).
/// Called once when a new game is started — not on load.
@MainActor
func setupNewGame(state: GameState) {
    var existingNames: Set<String> = []

    for gender in [Gender.male, Gender.female] {
        let prefixGender: PigNames.PrefixGender = gender == .male ? .male : .female
        let name = PigNames.generateUniqueName(existingNames: existingNames, gender: prefixGender)
        existingNames.insert(name)

        let pos: Position
        if let walkable = state.farm.findRandomWalkable() {
            pos = Position(x: Double(walkable.x), y: Double(walkable.y))
        } else {
            pos = Position(x: 5.0, y: 5.0)
        }

        var pig = GuineaPig.create(name: name, gender: gender)
        pig.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        pig.position = pos
        // All starter pigs begin with elevated happiness so they can breed
        // from day 1. The slim default (75) decays below the 70 threshold
        // before the breeding program can pair them — especially on post-
        // prestige farms where the Eager Learners booster was previously
        // the only source of this headroom.
        pig.needs.happiness = GameConfig.NewFarmer.eagerLearnersHappiness
        state.addGuineaPig(pig)
    }

    let food = Facility.create(type: .foodBowl, x: 5, y: 3)
    let water = Facility.create(type: .waterBottle, x: 10, y: 3)
    let hideout = Facility.create(type: .hideout, x: 14, y: 3)
    _ = state.addFacility(food)
    _ = state.addFacility(water)
    _ = state.addFacility(hideout)

    state.logEvent("Welcome to Big Pig Farm!", eventType: "info")
    state.lastSave = Date()
}
