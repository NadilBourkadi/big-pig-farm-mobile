/// FarmScene+NodeSync — Pig and facility node synchronization and status indicators.
import SpriteKit

extension FarmScene {

    // MARK: - Pig Sync

    func syncPigs() {
        let currentIDs = Set(gameState.guineaPigs.keys)
        let existingIDs = Set(pigNodes.keys)

        for removedID in existingIDs.subtracting(currentIDs) {
            pigNodes[removedID]?.removeFromParent()
            pigNodes.removeValue(forKey: removedID)
            indicatorTimers.removeValue(forKey: removedID)
        }

        for (id, pig) in gameState.guineaPigs {
            if let node = pigNodes[id] {
                node.update(from: pig, in: self)
            } else {
                let node = PigNode(pig: pig, scene: self)
                node.zPosition = 10
                pigLayer.addChild(node)
                pigNodes[id] = node
            }
            if let node = pigNodes[id] {
                node.isSelected = (id == selectedPigID)
                updateIndicator(for: node, pig: pig)
            }
        }
    }

    // MARK: - Facility Sync

    func syncFacilities() {
        let currentIDs = Set(gameState.facilities.keys)
        let existingIDs = Set(facilityNodes.keys)

        for removedID in existingIDs.subtracting(currentIDs) {
            facilityNodes[removedID]?.removeFromParent()
            facilityNodes.removeValue(forKey: removedID)
        }

        for (id, facility) in gameState.facilities {
            if let node = facilityNodes[id] {
                node.update(from: facility, in: self)
            } else {
                let node = FacilityNode(facility: facility, scene: self)
                node.zPosition = 5
                facilityLayer.addChild(node)
                facilityNodes[id] = node
            }
            if let node = facilityNodes[id] {
                node.isSelectedInEditMode = (id == selectedFacilityID && isEditMode)
                node.isBeingMoved = (id == selectedFacilityID && isMovingFacility)
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

    func updateIndicator(for node: PigNode, pig: GuineaPig) {
        guard let indicatorName = indicatorType(for: pig) else {
            node.hideIndicator()
            return
        }
        // Pulse: bright for 2 s, dim for 1 s, at 10 TPS.
        let cycleFrames = GameConfig.Simulation.ticksPerSecond * 3
        let brightFrames = GameConfig.Simulation.ticksPerSecond * 2
        let isBright = (frameCount % cycleFrames) < brightFrames
        node.showIndicator(type: indicatorName, bright: isBright)
    }
}
