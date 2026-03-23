/// FarmScene+Treats — Treat placement touch handling and pig dispatching.
import SpriteKit

extension FarmScene {

    /// Handle a tap in treat placement mode.
    /// Calls TreatManager backend, spawns a TreatNode, and dispatches nearby pigs.
    func handleTreatPlacement(at scenePoint: CGPoint) {
        let grid = sceneToGrid(scenePoint)
        let target = Position(x: Double(grid.x), y: Double(grid.y))

        let fedPigIDs = TreatManager.deliverTreat(
            type: .freshVeggies,
            at: target,
            state: gameState
        )

        guard !fedPigIDs.isEmpty else {
            HapticManager.error()
            return
        }

        // Spawn treat sprite
        let treatNode = TreatNode(
            type: .freshVeggies,
            scenePosition: scenePoint,
            gridPosition: target
        )
        treatLayer.addChild(treatNode)
        treatNode.animateSpawn()

        HapticManager.treatPlaced()

        // Dispatch pigs to treat
        dispatchPigsToTreat(treatNode, fedPigIDs: fedPigIDs)

        // Notify SwiftUI of count change
        onTreatCountChanged?()

        // Auto-exit if treats exhausted
        if gameState.remainingTreatsThisVisit <= 0 {
            onTreatsExhausted?()
        }
    }

    /// Animate pigs moving toward the treat and playing consumption effects.
    private func dispatchPigsToTreat(_ treatNode: TreatNode, fedPigIDs: [UUID]) {
        for pigID in fedPigIDs {
            guard let pigNode = pigNodes[pigID],
                  let pig = gameState.getGuineaPig(pigID) else { continue }

            let traits = pig.personality
            pigNode.moveToTreat(at: treatNode.position, traits: traits) { [weak treatNode] in
                pigNode.playHeartParticle()
                HapticManager.treatConsumed()
                _ = treatNode?.animatePickup {}
            }
        }
    }
}
