/// PigNodeSmoothMoveTests — Verifies smoothMove(factor:) interpolation at different factors.
import Testing
import SpriteKit
@testable import BigPigFarm

@Suite("PigNode smoothMove")
@MainActor
struct PigNodeSmoothMoveTests {

    private func makeScene() -> FarmScene { FarmScene(gameState: GameState()) }

    private func makePig(at gridX: Double = 0, gridY: Double = 0) -> GuineaPig {
        var pig = GuineaPig.create(name: "Test", gender: .female)
        pig.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        pig.position = Position(x: gridX, y: gridY)
        return pig
    }

    @Test("Factor 1.0 snaps position to target")
    func snapAtFullFactor() {
        let scene = makeScene()
        let pig = makePig()
        let node = PigNode(pig: pig, scene: scene)

        // Move target by updating pig position
        var movedPig = pig
        movedPig.position = Position(x: 5, y: 5)
        node.update(from: movedPig, in: scene)

        node.smoothMove(factor: 1.0)

        #expect(abs(node.position.x - node.targetPosition.x) < 0.01)
        #expect(abs(node.position.y - node.targetPosition.y) < 0.01)
    }

    @Test("Factor 0.25 partially closes gap")
    func partialMoveAtQuarterFactor() {
        let scene = makeScene()
        let pig = makePig()
        let node = PigNode(pig: pig, scene: scene)
        let startPos = node.position

        var movedPig = pig
        movedPig.position = Position(x: 5, y: 3)
        node.update(from: movedPig, in: scene)

        let expectedDx = (node.targetPosition.x - startPos.x) * 0.25
        let expectedDy = (node.targetPosition.y - startPos.y) * 0.25
        node.smoothMove(factor: 0.25)

        #expect(abs(node.position.x - (startPos.x + expectedDx)) < 0.01,
                "Should move 25% of the X gap")
        #expect(abs(node.position.y - (startPos.y + expectedDy)) < 0.01,
                "Should move 25% of the Y gap")
    }

    @Test("Sleeping pig snaps position instead of lerping")
    func sleepingPigSnaps() {
        let scene = makeScene()
        let pig = makePig()
        let node = PigNode(pig: pig, scene: scene)

        var sleepingPig = pig
        sleepingPig.position = Position(x: 5, y: 5)
        sleepingPig.behaviorState = .sleeping
        node.update(from: sleepingPig, in: scene)

        // Even with a partial factor, sleeping pig should snap to target
        node.smoothMove(factor: 0.25)

        #expect(abs(node.position.x - node.targetPosition.x) < 0.01,
                "Sleeping pig should snap X to target")
        #expect(abs(node.position.y - node.targetPosition.y) < 0.01,
                "Sleeping pig should snap Y to target")
    }

    @Test("Pig resumes interpolation after waking from sleep")
    func resumesLerpAfterWaking() {
        let scene = makeScene()
        let pig = makePig()
        let node = PigNode(pig: pig, scene: scene)

        // Put pig to sleep at a new position
        var sleepingPig = pig
        sleepingPig.position = Position(x: 3, y: 3)
        sleepingPig.behaviorState = .sleeping
        node.update(from: sleepingPig, in: scene)
        node.smoothMove(factor: 1.0) // snap to sleep position

        // Wake up and move to a different position
        var awakePig = sleepingPig
        awakePig.position = Position(x: 8, y: 8)
        awakePig.behaviorState = .idle
        node.update(from: awakePig, in: scene)

        let beforeMove = node.position
        node.smoothMove(factor: 0.25)

        // Should NOT have snapped — should have partially interpolated
        let fullDx = node.targetPosition.x - beforeMove.x
        let expectedX = beforeMove.x + fullDx * 0.25
        #expect(abs(node.position.x - expectedX) < 0.01,
                "Awake pig should lerp X, not snap")
        let fullDy = node.targetPosition.y - beforeMove.y
        let expectedY = beforeMove.y + fullDy * 0.25
        #expect(abs(node.position.y - expectedY) < 0.01,
                "Awake pig should lerp Y, not snap")
    }

    @Test("Snaps when distance squared is below threshold")
    func snapsAtSmallDistance() {
        let scene = makeScene()
        let pig = makePig()
        let node = PigNode(pig: pig, scene: scene)

        // Target is already at position (init sets both equal)
        // so smoothMove should be a no-op snap
        let before = node.position
        node.smoothMove(factor: 0.25)
        #expect(node.position.x == before.x)
        #expect(node.position.y == before.y)
    }
}
