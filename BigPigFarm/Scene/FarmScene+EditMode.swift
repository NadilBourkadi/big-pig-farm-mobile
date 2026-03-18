/// FarmScene+EditMode — Facility selection, drag-to-move, and removal in edit mode.
import SpriteKit

extension FarmScene {

    // MARK: - Tap Selection

    func handleEditModeTap(at location: CGPoint) {
        for node in nodes(at: location) {
            if let facilityNode = node as? FacilityNode {
                let tappedID = facilityNode.facilityID
                selectedFacilityID = (selectedFacilityID == tappedID) ? nil : tappedID
                if let id = selectedFacilityID {
                    sceneDelegate?.farmScene(self, didSelectFacility: id)
                } else {
                    sceneDelegate?.farmSceneDidDeselectFacility(self)
                }
                return
            }
        }
        selectedFacilityID = nil
        sceneDelegate?.farmSceneDidDeselectFacility(self)
    }

    // MARK: - Hit Test

    /// Returns the facility ID at a scene point, or nil if no facility is there.
    func facilityIDAtPoint(_ scenePoint: CGPoint) -> UUID? {
        for node in nodes(at: scenePoint) {
            if let facilityNode = node as? FacilityNode {
                return facilityNode.facilityID
            }
        }
        return nil
    }

    // MARK: - Drag-to-Move

    /// Begin dragging a facility. Called by CameraController when a pan gesture
    /// starts on a facility in edit mode.
    func beginDraggingFacility(_ facilityID: UUID) {
        selectedFacilityID = facilityID
        draggedFacilityID = facilityID
        sceneDelegate?.farmScene(self, didSelectFacility: facilityID)
        onFacilityDragBegan?(facilityID)
    }

    /// Move the dragged facility to a new origin aligned to the grid.
    /// If the new position is invalid, the facility is restored to its prior location.
    func moveSelectedFacility(to scenePoint: CGPoint) {
        guard let facilityID = draggedFacilityID,
              var facility = gameState.getFacility(facilityID) else { return }

        let gridPos = sceneToGrid(scenePoint)
        let newX = max(0, Int(gridPos.x))
        let newY = max(0, Int(gridPos.y))

        let oldX = facility.positionX
        let oldY = facility.positionY

        gameState.farm.removeFacility(facility)
        facility.positionX = newX
        facility.positionY = newY

        if gameState.farm.placeFacility(facility) {
            gameState.updateFacility(facility)
        } else {
            facility.positionX = oldX
            facility.positionY = oldY
            _ = gameState.farm.placeFacility(facility)
            gameState.updateFacility(facility)
            HapticManager.error()
        }
    }

    /// End the current drag gesture. `selectedFacilityID` is intentionally retained
    /// so the user can immediately Remove the just-placed facility without tapping again.
    func confirmFacilityPlacement() {
        guard draggedFacilityID != nil else { return }
        draggedFacilityID = nil
        onFacilityMoveEnded?()
    }

    // MARK: - Remove

    func removeSelectedFacility() {
        guard let facilityID = selectedFacilityID else { return }
        sceneDelegate?.farmScene(self, didRemoveFacility: facilityID)
        _ = gameState.removeFacility(facilityID)
        selectedFacilityID = nil
        draggedFacilityID = nil
    }
}
