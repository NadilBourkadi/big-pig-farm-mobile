/// PigNodeSmoothMoveTests — Verifies smoothMove(factor:) interpolation at different factors.
import Testing
import SpriteKit
@testable import BigPigFarm

@Suite("PigNode smoothMove")
@MainActor
struct PigNodeSmoothMoveTests {

    private func makeScene() -> FarmScene { FarmScene(gameState: GameState()) }

    private func makePig(at gridX: Int = 0, gridY: Int = 0) -> GuineaPig {
        var pig = GuineaPig.create(name: "Test", gender: .female)
        pig.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        pig.position = GridPosition(x: gridX, y: gridY)
        return pig
    }

    @Test("Factor 1.0 snaps position to target")
    func snapAtFullFactor() {
        let scene = makeScene()
        let pig = makePig()
        let node = PigNode(pig: pig, scene: scene)

        // Move target by updating pig position
        var movedPig = pig
        movedPig.position = GridPosition(x: 5, y: 5)
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
        movedPig.position = GridPosition(x: 5, y: 3)
        node.update(from: movedPig, in: scene)

        let expectedDx = (node.targetPosition.x - startPos.x) * 0.25
        let expectedDy = (node.targetPosition.y - startPos.y) * 0.25
        node.smoothMove(factor: 0.25)

        #expect(abs(node.position.x - (startPos.x + expectedDx)) < 0.01,
                "Should move 25% of the X gap")
        #expect(abs(node.position.y - (startPos.y + expectedDy)) < 0.01,
                "Should move 25% of the Y gap")
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
