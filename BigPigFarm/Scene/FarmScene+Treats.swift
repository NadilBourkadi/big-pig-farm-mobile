/// FarmScene+Treats — Treat placement touch handling and behavior-driven pig dispatching.
import SpriteKit

extension FarmScene {

    /// Handle a tap in treat placement mode.
    /// Calls TreatManager backend, spawns a TreatNode, and dispatches nearby pigs.
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

        // Dispatch pigs to treat via behavior AI
        dispatchPigsToTreat(treatNode, fedPigIDs: fedPigIDs)

        // Notify SwiftUI of count change
        onTreatCountChanged?()

        // Auto-exit if treats exhausted
        if gameState.remainingTreatsThisVisit <= 0 {
            onTreatsExhausted?()
        }
    }

    /// Set pig behavior states to seek the treat position.
    /// BehaviorController handles pathfinding and tick-based movement (pause-aware).
    private func dispatchPigsToTreat(_ treatNode: TreatNode, fedPigIDs: [UUID]) {
        let treatGridPos = treatNode.gridPosition.gridPosition
        for pigID in fedPigIDs {
            guard var pig = gameState.getGuineaPig(pigID) else { continue }
            // Skip sleeping/courting pigs — don't interrupt rest or active courtship
            if pig.behaviorState == .sleeping || pig.behaviorState == .courting { continue }
            pig.behaviorState = .seekingTreat
            pig.targetTreatGridPosition = treatGridPos
            pig.targetPosition = Position(x: Double(treatGridPos.x), y: Double(treatGridPos.y))
            pig.targetDescription = "going to treat"
            pig.path = [] // BehaviorController computes path on next tick
            pig.targetFacilityId = nil
            gameState.updateGuineaPig(pig)
            pendingTreatNodes[pigID] = treatNode
        }
    }

    /// Check pending treat-seeking pigs for arrivals and play visual effects.
    /// Called from syncPigs() once per simulation tick.
    func checkTreatArrivals() {
        guard !pendingTreatNodes.isEmpty else { return }
        for (pigID, treatNode) in pendingTreatNodes {
            guard let pig = gameState.getGuineaPig(pigID) else {
                // Pig died — clean up
                pendingTreatNodes.removeValue(forKey: pigID)
                continue
            }
            guard pig.behaviorState != .seekingTreat else { continue }
            // Pig is no longer seeking — check if it arrived (near treat) or was cancelled
            pendingTreatNodes.removeValue(forKey: pigID)
            let treatGridPos = treatNode.gridPosition.gridPosition
            let pigGridPos = pig.position.gridPosition
            if pigGridPos.manhattanDistance(to: treatGridPos) <= 2 {
                // Arrived — play visual effects
                if let pigNode = pigNodes[pigID] {
                    pigNode.playHeartParticle()
                }
                HapticManager.treatConsumed()
                _ = treatNode.animatePickup {}
            }
        }
    }
}
