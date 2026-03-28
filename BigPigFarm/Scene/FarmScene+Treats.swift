/// FarmScene+Treats — Treat placement touch handling and active treat tracking.
import SpriteKit

extension FarmScene {

    /// Handle a tap in treat placement mode.
    /// Calls TreatManager backend (applies stat boosts + sets behavior target),
    /// spawns a TreatNode, and registers it for pickup animation on pig arrival.
    func handleTreatPlacement(at scenePoint: CGPoint) {
        let grid = sceneToGrid(scenePoint)
        let target = Position(x: Double(grid.x), y: Double(grid.y))

        let fedPigIDs = TreatManager.deliverTreat(
            type: selectedTreatType,
            at: target,
            state: gameState
        )

        guard !fedPigIDs.isEmpty else {
            HapticManager.error()
            return
        }

        // Spawn treat sprite
        let treatNode = TreatNode(
            type: selectedTreatType,
            scenePosition: scenePoint,
            gridPosition: target
        )
        treatLayer.addChild(treatNode)
        treatNode.animateSpawn()

        HapticManager.treatPlaced()

        // Register treat for pickup animation when pigs arrive via behavior AI
        activeTreats[target] = (node: treatNode, pendingPigIDs: Set(fedPigIDs))

        // Notify SwiftUI of count change
        onTreatCountChanged?()

        // Auto-exit if treats exhausted
        if gameState.remainingTreatsThisVisit <= 0 {
            onTreatsExhausted?()
        }
    }

    /// Called from syncPigs when a pig transitions to .eating — check if it
    /// arrived at an active treat and trigger pickup animation.
    func checkTreatArrival(pigID: UUID, pigNode: PigNode) {
        for (pos, var treatInfo) in activeTreats {
            guard treatInfo.pendingPigIDs.contains(pigID) else { continue }
            treatInfo.pendingPigIDs.remove(pigID)

            pigNode.playHeartParticle()
            HapticManager.treatConsumed()

            let isLast = treatInfo.node.animatePickup {}

            if isLast || treatInfo.pendingPigIDs.isEmpty {
                activeTreats.removeValue(forKey: pos)
            } else {
                activeTreats[pos] = treatInfo
            }
            return
        }
    }
}
