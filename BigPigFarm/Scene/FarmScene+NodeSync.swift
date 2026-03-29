/// FarmScene+NodeSync — Pig and facility node synchronization and status indicators.
import SpriteKit

extension FarmScene {

    // MARK: - Pig Sync

    func syncPigs() {
        let currentIDs = Set(gameState.guineaPigs.keys)
        let existingIDs = Set(pigNodes.keys)

        for removedID in existingIDs.subtracting(currentIDs) {
            // Remove from tracking immediately so future syncs treat this pig as gone;
            // the scene-graph node removes itself after the fade-out animation completes.
            if let node = pigNodes.removeValue(forKey: removedID) {
                node.run(.sequence([
                    .group([.scale(to: 0, duration: 0.2), .fadeOut(withDuration: 0.2)]),
                    .removeFromParent()
                ]))
            }
            indicatorTimers.removeValue(forKey: removedID)
        }

        for (id, pig) in gameState.guineaPigs {
            if let node = pigNodes[id] {
                node.update(from: pig, in: self)
            } else {
                let node = PigNode(pig: pig, scene: self)
                node.zPosition = 10
                node.setScale(0)
                pigLayer.addChild(node)
                node.run(.sequence([
                    .scale(to: 1.1, duration: 0.15),
                    .scale(to: 1.0, duration: 0.1)
                ]))
                pigNodes[id] = node
            }
            if let node = pigNodes[id] {
                node.isSelected = (id == selectedPigID)
                updateIndicator(for: node, pig: pig)

                // Playful treat bounce: animate while seeking, stop otherwise
                if pig.behaviorState == .seekingTreat, pig.hasTrait(.playful) {
                    node.startTreatBounce()
                } else {
                    node.stopTreatBounce()
                }
            }
        }

        checkTreatArrivals()
    }

    // MARK: - Facility Sync

    func syncFacilities() {
        let currentIDs = Set(gameState.facilities.keys)
        let existingIDs = Set(facilityNodes.keys)

        for removedID in existingIDs.subtracting(currentIDs) {
            if let node = facilityNodes.removeValue(forKey: removedID) {
                node.run(.sequence([
                    .group([.scale(to: 0, duration: 0.2), .fadeOut(withDuration: 0.2)]),
                    .removeFromParent()
                ]))
            }
        }

        for (id, facility) in gameState.facilities {
            if let node = facilityNodes[id] {
                node.update(from: facility, in: self)
            } else {
                let node = FacilityNode(facility: facility, scene: self)
                node.zPosition = 5
                node.setScale(0)
                facilityLayer.addChild(node)
                node.run(.sequence([
                    .scale(to: 1.05, duration: 0.2),
                    .scale(to: 1.0, duration: 0.1)
                ]))
                facilityNodes[id] = node
            }
            if let node = facilityNodes[id] {
                if isEditMode {
                    if id == draggedFacilityID {
                        node.glowState = .moving
                    } else if id == selectedFacilityID {
                        node.glowState = .selected
                    } else {
                        node.glowState = .none
                    }
                } else {
                    node.glowState = .none
                }
            }
        }
    }

    // MARK: - Status Indicators

    /// Returns the highest-priority status indicator type for a pig, or nil if none.
    /// Marked internal so tests can call it directly.
    internal func indicatorType(for pig: GuineaPig) -> String? {
        let low = Double(GameConfig.Needs.lowThreshold)
        if pig.needs.health < low { return IndicatorType.health.rawValue }
        if pig.needs.hunger < low { return IndicatorType.hunger.rawValue }
        if pig.needs.thirst < low { return IndicatorType.thirst.rawValue }
        if pig.needs.energy < low { return IndicatorType.energy.rawValue }
        if pig.behaviorState == .courting { return IndicatorType.courting.rawValue }
        if pig.isPregnant { return IndicatorType.pregnant.rawValue }
        return nil
    }

    fileprivate func updateIndicator(for node: PigNode, pig: GuineaPig) {
        guard let indicatorName = indicatorType(for: pig) else {
            node.hideIndicator()
            return
        }
        // Pulse: bright for 2 s, dim for 1 s, at 10 TPS.
        let cycleFrames = UInt64(GameConfig.Simulation.ticksPerSecond * 3)
        let brightFrames = UInt64(GameConfig.Simulation.ticksPerSecond * 2)
        let isBright = (gameState.simulationTick % cycleFrames) < brightFrames
        node.showIndicator(type: indicatorName, bright: isBright)
    }
}
