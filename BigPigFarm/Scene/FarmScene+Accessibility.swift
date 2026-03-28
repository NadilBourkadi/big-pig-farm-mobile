/// FarmScene+Accessibility — VoiceOver support for pig and facility sprites.
/// Creates UIAccessibilityElement wrappers so VoiceOver users can discover,
/// navigate, and interact with on-screen game objects.
import SpriteKit
import UIKit

extension FarmScene {

    // MARK: - Accessibility Element Sync

    /// Rebuild the SKView's accessibilityElements from current pig and facility nodes.
    ///
    /// Called from `update(_:)` at a throttled rate (every 5 ticks / 0.5s).
    /// Only builds elements when VoiceOver is active to avoid unnecessary work.
    func syncAccessibilityElements() {
        guard UIAccessibility.isVoiceOverRunning else {
            if view?.accessibilityElements != nil {
                view?.accessibilityElements = nil
            }
            return
        }

        let currentTick = gameState.simulationTick
        guard currentTick >= lastAccessibilitySyncTick + Self.accessibilitySyncInterval else {
            return
        }
        lastAccessibilitySyncTick = currentTick

        guard let view = self.view else { return }

        var elements: [UIAccessibilityElement] = []

        let sortedPigs = gameState.guineaPigs.values.sorted { $0.name < $1.name }
        for pig in sortedPigs {
            guard let pigNode = pigNodes[pig.id] else { continue }

            let element = UIAccessibilityElement(accessibilityContainer: view)
            element.accessibilityLabel = pigAccessibilityLabel(for: pig)
            element.accessibilityValue = pigAccessibilityValue(for: pig)
            element.accessibilityFrame = accessibilityFrame(
                position: pigNode.position,
                size: pigNode.size
            )
            element.accessibilityTraits = [.button]
            element.accessibilityHint = pig.id == selectedPigID
                ? "Double-tap to deselect"
                : "Double-tap to select and follow"
            elements.append(element)
        }

        let sortedFacilities = gameState.facilities.values.sorted {
            $0.facilityType.displayName < $1.facilityType.displayName
        }
        for facility in sortedFacilities {
            guard let facilityNode = facilityNodes[facility.id] else { continue }

            let element = UIAccessibilityElement(accessibilityContainer: view)
            element.accessibilityLabel = facilityAccessibilityLabel(for: facility)
            element.accessibilityValue = facilityAccessibilityValue(for: facility)
            element.accessibilityFrame = accessibilityFrame(
                position: facilityNode.position,
                size: facilityNode.size
            )
            element.accessibilityTraits = isEditMode ? [.button] : [.staticText]
            if isEditMode {
                element.accessibilityHint = "Double-tap to select for editing"
            }
            elements.append(element)
        }

        view.accessibilityElements = elements
    }

    // MARK: - Pig Labels

    /// Build the accessibility label for a pig.
    ///
    /// Format: "Butterscotch, golden female, baby, eating, health low, pregnant"
    func pigAccessibilityLabel(for pig: GuineaPig) -> String {
        var parts: [String] = [pig.name]

        let colorName = pig.phenotype.baseColor.rawValue
        let gender = pig.gender.displayLabel.lowercased()
        parts.append("\(colorName) \(gender)")

        if pig.isBaby {
            parts.append("baby")
        } else if pig.isSenior {
            parts.append("senior")
        }

        parts.append(behaviorLabel(for: pig.behaviorState))

        let low = Double(GameConfig.Needs.lowThreshold)
        if pig.needs.health < low { parts.append("health low") }
        if pig.needs.hunger < low { parts.append("hungry") }
        if pig.needs.thirst < low { parts.append("thirsty") }
        if pig.isPregnant { parts.append("pregnant") }

        return parts.joined(separator: ", ")
    }

    /// Build the accessibility value for a pig (need percentages).
    ///
    /// Format: "Happiness 75%, Health 100%, Hunger 80%, Thirst 90%"
    func pigAccessibilityValue(for pig: GuineaPig) -> String {
        let h = Int(pig.needs.happiness)
        let hp = Int(pig.needs.health)
        let hu = Int(pig.needs.hunger)
        let t = Int(pig.needs.thirst)
        return "Happiness \(h)%, Health \(hp)%, Hunger \(hu)%, Thirst \(t)%"
    }

    // MARK: - Facility Labels

    /// Build the accessibility label for a facility.
    ///
    /// Format: "Food Bowl, level 2"
    func facilityAccessibilityLabel(for facility: Facility) -> String {
        var label = facility.facilityType.displayName
        if facility.level > 1 {
            label += ", level \(facility.level)"
        }
        return label
    }

    /// Build the accessibility value for a facility (fill percentage).
    ///
    /// Returns a fill string for consumable facilities (those with refillCost > 0),
    /// nil for non-consumable facilities.
    func facilityAccessibilityValue(for facility: Facility) -> String? {
        guard facility.info.refillCost > 0 else { return nil }
        if facility.isEmpty {
            return "Empty"
        }
        let percentage = Int(facility.fillPercentage)
        return "\(percentage)% full"
    }

    // MARK: - Coordinate Conversion

    /// Convert a scene-space node position and size to a screen-space CGRect
    /// suitable for `UIAccessibilityElement.accessibilityFrame`.
    func accessibilityFrame(position: CGPoint, size: CGSize) -> CGRect {
        guard let view = self.view else { return .zero }

        // convertPoint(toView:) accounts for camera position and scale.
        let viewCenter = convertPoint(toView: position)

        // Scale node size from scene units to view units.
        // Under aspectFill the scene is scaled so the larger dimension fills the view.
        let sceneW = self.size.width
        let sceneH = self.size.height
        guard sceneW > 0, sceneH > 0 else { return .zero }
        let displayScale = max(view.frame.width / sceneW, view.frame.height / sceneH)
        // Camera is always uniformly scaled (xScale == yScale).
        let cameraScale = camera?.xScale ?? 1.0
        guard cameraScale > 0 else { return .zero }

        let viewWidth = size.width * displayScale / cameraScale
        let viewHeight = size.height * displayScale / cameraScale

        let viewRect = CGRect(
            x: viewCenter.x - viewWidth / 2,
            y: viewCenter.y - viewHeight / 2,
            width: viewWidth,
            height: viewHeight
        )

        return view.convert(viewRect, to: nil)
    }

    // MARK: - Helpers

    private func behaviorLabel(for state: BehaviorState) -> String {
        switch state {
        case .idle: "idle"
        case .wandering: "wandering"
        case .eating: "eating"
        case .drinking: "drinking"
        case .playing: "playing"
        case .sleeping: "sleeping"
        case .socializing: "socializing"
        case .courting: "courting"
        }
    }
}
