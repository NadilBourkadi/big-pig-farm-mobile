/// FarmScene+Touch — Tap handling and pig hit-test logic.
/// Receives taps from CameraController's UITapGestureRecognizer (which only fires
/// after the pan gesture fails), preventing accidental selection after camera drags.
import SpriteKit

extension FarmScene {

    /// Handle a confirmed tap at a scene-space location.
    func handleTap(at location: CGPoint) {
        if isEditMode {
            handleEditModeTap(at: location)
            return
        }

        if let pigNode = pigNodeAt(location) {
            if selectedPigID == pigNode.pigID {
                selectedPigID = nil
                sceneDelegate?.farmSceneDidDeselectPig(self)
            } else {
                selectedPigID = pigNode.pigID
                sceneDelegate?.farmScene(self, didSelectPig: pigNode.pigID)
            }
        } else {
            selectedPigID = nil
            sceneDelegate?.farmSceneDidDeselectPig(self)
        }
    }

    /// Find the closest PigNode within an expanded 16pt hit area.
    ///
    /// Uses frame expansion + closest-center-distance selection, matching the
    /// Python pig_at_screen_pos() behavior for comfortable mobile tapping on small sprites.
    private func pigNodeAt(_ location: CGPoint) -> PigNode? {
        // PigNode uses the default SKSpriteNode anchor (0.5, 0.5), so node.position
        // is the frame center. nearestIndex relies on frame/center alignment being correct.
        let nodeList = Array(pigNodes.values)
        let frames = nodeList.map { $0.frame }
        let centers = nodeList.map { $0.position }
        guard let index = FarmScene.nearestIndex(at: location, frames: frames, centers: centers) else {
            return nil
        }
        return nodeList[index]
    }

    /// Core hit-test algorithm: expanded frame + closest center distance.
    ///
    /// Returns the index into `frames`/`centers` of the closest candidate within
    /// `tapTolerance` points of the frame edges, or nil if nothing qualifies.
    ///
    /// `nonisolated`: this is a pure function (value-type inputs only, no actor state),
    /// so it does not inherit `@MainActor` from `FarmScene`. This allows test code to
    /// call it without actor overhead or `await`.
    nonisolated internal static func nearestIndex(
        at location: CGPoint,
        frames: [CGRect],
        centers: [CGPoint],
        tapTolerance: CGFloat = 16.0
    ) -> Int? {
        var bestIndex: Int?
        var bestDistance: CGFloat = .infinity

        for i in 0..<frames.count {
            let expanded = frames[i].insetBy(dx: -tapTolerance, dy: -tapTolerance)
            guard expanded.contains(location) else { continue }
            let distance = hypot(location.x - centers[i].x, location.y - centers[i].y)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = i
            }
        }
        return bestIndex
    }

    func updateSelectionHighlight() {
        for (id, node) in pigNodes {
            node.isSelected = (id == selectedPigID)
        }
    }

    /// Select a pig and immediately center the camera on it.
    /// Called from ContentView when the player taps "Follow" in PigList or PigDetail.
    func centerOnPig(_ pigID: UUID) {
        selectedPigID = pigID
        if let node = pigNodes[pigID] {
            cameraController.follow(node.position)
        }
    }
}
