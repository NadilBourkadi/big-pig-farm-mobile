/// ReduceMotionTests — Verifies the MotionSettings testing seam and the
/// scene-level reduce-motion guards (treat bounce). Particle and PigNode
/// reduce-motion behaviour is covered alongside their existing tests in
/// TreatInteractionTests.swift and PigNodeSmoothMoveTests.swift.
import Testing
import SpriteKit
@testable import BigPigFarm

@Suite("MotionSettings")
@MainActor
struct MotionSettingsTests {

    @Test("Override forces isReduced to true")
    func overrideForcesTrue() {
        MotionSettings.overrideForTesting = true
        defer { MotionSettings.overrideForTesting = nil }
        #expect(MotionSettings.isReduced == true)
    }

    @Test("Override forces isReduced to false")
    func overrideForcesFalse() {
        MotionSettings.overrideForTesting = false
        defer { MotionSettings.overrideForTesting = nil }
        #expect(MotionSettings.isReduced == false)
    }

    @Test("Resetting override returns to system value")
    func resetReturnsToSystem() {
        MotionSettings.overrideForTesting = true
        MotionSettings.overrideForTesting = nil
        // After reset, isReduced reads UIAccessibility.isReduceMotionEnabled.
        // We don't assert a specific value (it depends on the test host's
        // accessibility settings), only that the read does not crash.
        _ = MotionSettings.isReduced
    }
}

@Suite("PigNode treat bounce — reduce motion")
@MainActor
struct PigNodeTreatBounceReduceMotionTests {

    private func makeScene() -> FarmScene { FarmScene(gameState: GameState()) }

    private func makePig() -> GuineaPig {
        var pig = GuineaPig.create(name: "Test", gender: .female)
        pig.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        return pig
    }

    @Test("startTreatBounce registers an action when reduce motion is off")
    func bounceRegistersWhenMotionAllowed() {
        MotionSettings.overrideForTesting = false
        defer { MotionSettings.overrideForTesting = nil }

        let scene = makeScene()
        let node = PigNode(pig: makePig(), scene: scene)

        node.startTreatBounce()
        #expect(node.action(forKey: "treatBounce") != nil)
    }

    @Test("startTreatBounce is a no-op when reduce motion is on")
    func bounceNoOpWhenReduced() {
        MotionSettings.overrideForTesting = true
        defer { MotionSettings.overrideForTesting = nil }

        let scene = makeScene()
        let node = PigNode(pig: makePig(), scene: scene)

        node.startTreatBounce()
        #expect(node.action(forKey: "treatBounce") == nil)
    }
}
