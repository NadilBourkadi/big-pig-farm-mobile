/// FarmScene+EditMode — Facility placement and removal in edit mode.
import SpriteKit

extension FarmScene {

    func handleEditModeTap(at location: CGPoint) {
        for node in nodes(at: location) {
            if let facilityNode = node as? FacilityNode {
                let tappedID = facilityNode.facilityID
                selectedFacilityID = (selectedFacilityID == tappedID) ? nil : tappedID
                if let id = selectedFacilityID {
                    sceneDelegate?.farmScene(self, didSelectFacility: id)
                }
                return
            }
        }
        selectedFacilityID = nil
    }

    func startMovingSelectedFacility() {
        guard selectedFacilityID != nil else { return }
        isMovingFacility = true
    }

    /// Move the selected facility to a new origin aligned to the grid.
    /// If the new position is invalid, the facility is restored to its prior location.
    func moveSelectedFacility(to scenePoint: CGPoint) {
        guard isMovingFacility,
              let facilityID = selectedFacilityID,
              var facility = gameState.getFacility(facilityID) else { return }

        let gridPos = sceneToGrid(scenePoint)
        let newX = max(0, Int(gridPos.x))
        let newY = max(0, Int(gridPos.y))

        let oldX = facility.positionX
        let oldY = facility.positionY

        // Remove from old cells, try new cells.
        gameState.farm.removeFacility(facility)
        facility.positionX = newX
        facility.positionY = newY

        if gameState.farm.placeFacility(facility) {
            gameState.updateFacility(facility)
        } else {
            // Restore original position.
            facility.positionX = oldX
            facility.positionY = oldY
            _ = gameState.farm.placeFacility(facility)
            gameState.updateFacility(facility)
        }
    }

    func confirmFacilityPlacement() {
        isMovingFacility = false
    }

    func removeSelectedFacility() {
        guard let facilityID = selectedFacilityID else { return }
        sceneDelegate?.farmScene(self, didRemoveFacility: facilityID)
        _ = gameState.removeFacility(facilityID)
        selectedFacilityID = nil
        isMovingFacility = false
    }
}
