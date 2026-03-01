/// TouchHandlingTests — Unit tests for tap hit-test algorithm and selection state transitions.
/// Tests the nearestIndex algorithm (expanded frame + closest center distance) and
/// the handleTap routing logic (pig selection, deselection, edit mode routing).
import Testing
import SpriteKit
@testable import BigPigFarm

// MARK: - Hit-Test Algorithm

/// Tests the nearestIndex algorithm that underpins pig tap detection.
/// The algorithm: expand each frame by tapTolerance, then pick the candidate
/// whose center is closest to the tap point among all that qualify.
@Suite("Pig Hit-Test Algorithm")
struct NearestIndexTests {

    // A small frame centered at the origin: (-8, -4, 16, 8).
    private let singleFrame = CGRect(x: -8, y: -4, width: 16, height: 8)
    private let singleCenter = CGPoint(x: 0, y: 0)

    @Test("No candidates returns nil")
    func noCandidatesReturnsNil() {
        let result = FarmScene.nearestIndex(at: .zero, frames: [], centers: [])
        #expect(result == nil)
    }

    @Test("Tap exactly at center selects the candidate")
    func tapAtCenterSelects() {
        let result = FarmScene.nearestIndex(
            at: singleCenter,
            frames: [singleFrame],
            centers: [singleCenter]
        )
        #expect(result == 0)
    }

    @Test("Tap within original frame (no expansion needed) selects candidate")
    func tapInsideOriginalFrame() {
        let result = FarmScene.nearestIndex(
            at: CGPoint(x: 4, y: 2),        // inside the 16×8 frame
            frames: [singleFrame],
            centers: [singleCenter]
        )
        #expect(result == 0)
    }

    @Test("Tap just outside original frame but within 16pt expansion selects candidate")
    func tapInExpandedZoneSelects() {
        // The frame ends at x=8; tap at x=20 is 12pt outside → within 16pt tolerance.
        let result = FarmScene.nearestIndex(
            at: CGPoint(x: 20, y: 0),
            frames: [singleFrame],
            centers: [singleCenter]
        )
        #expect(result == 0)
    }

    @Test("Tap just inside expanded boundary selects candidate")
    func tapJustInsideExpandedEdgeSelects() {
        // Frame right edge is at x=8; tapTolerance=16 → expanded right edge at x=24.
        // CGRect.contains uses an exclusive maxX, so x=23.9 is inside, x=24 is outside.
        let result = FarmScene.nearestIndex(
            at: CGPoint(x: 23.9, y: 0),
            frames: [singleFrame],
            centers: [singleCenter]
        )
        #expect(result == 0)
    }

    @Test("Tap exactly at expanded maxX boundary (exclusive) returns nil")
    func tapAtExpandedMaxXReturnsNil() {
        // CGRectContainsPoint: point.x < maxX (exclusive upper bound).
        // Expanded frame right edge is at x=24; tap at x=24 is NOT contained.
        let result = FarmScene.nearestIndex(
            at: CGPoint(x: 24, y: 0),
            frames: [singleFrame],
            centers: [singleCenter]
        )
        #expect(result == nil)
    }

    @Test("Tap beyond expanded boundary returns nil")
    func tapBeyondExpansionReturnsNil() {
        // x=25 is 17pt outside the frame edge — beyond the 16pt expansion.
        let result = FarmScene.nearestIndex(
            at: CGPoint(x: 25, y: 0),
            frames: [singleFrame],
            centers: [singleCenter]
        )
        #expect(result == nil)
    }

    @Test("Custom tapTolerance of zero uses exact frame bounds")
    func zeroToleranceUsesExactBounds() {
        // Just inside the exact frame → selects.
        let inside = FarmScene.nearestIndex(
            at: CGPoint(x: 7.9, y: 0),
            frames: [singleFrame],
            centers: [singleCenter],
            tapTolerance: 0
        )
        #expect(inside == 0)

        // Just outside → nil.
        let outside = FarmScene.nearestIndex(
            at: CGPoint(x: 8.1, y: 0),
            frames: [singleFrame],
            centers: [singleCenter],
            tapTolerance: 0
        )
        #expect(outside == nil)
    }

    @Test("Two overlapping candidates: tap selects the closer center")
    func twoOverlappingCandidatesSelectsCloser() {
        // Pig A centered at (0, 0), Pig B centered at (10, 0).
        // Both have the same frame size so both qualify for a tap at (6, 0).
        // Distance to A center = 6, distance to B center = 4 → B (index 1) wins.
        let frameA = CGRect(x: -8, y: -4, width: 16, height: 8)
        let frameB = CGRect(x: 2, y: -4, width: 16, height: 8)
        let result = FarmScene.nearestIndex(
            at: CGPoint(x: 6, y: 0),
            frames: [frameA, frameB],
            centers: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)]
        )
        #expect(result == 1)
    }

    @Test("Two candidates: tap in expanded zone of only one selects that one")
    func tapInExpandedZoneOfOnlyOneCandidate() {
        // Pig A at (0, 0), Pig B far away at (200, 0).
        // Tap at (22, 0): 14pt beyond A's right edge → inside A's expansion.
        // 178pt from B's left edge → far outside B's expansion.
        let frameA = CGRect(x: -8, y: -4, width: 16, height: 8)
        let frameB = CGRect(x: 192, y: -4, width: 16, height: 8)
        let result = FarmScene.nearestIndex(
            at: CGPoint(x: 22, y: 0),
            frames: [frameA, frameB],
            centers: [CGPoint(x: 0, y: 0), CGPoint(x: 200, y: 0)]
        )
        #expect(result == 0)
    }

    @Test("Three candidates: tap selects the one with smallest center distance")
    func threeCandidatesSelectsSmallestCenterDistance() {
        // Three pigs in a row, tap at (30, 0).
        // A at (0, 0), B at (30, 0), C at (60, 0). Tap exactly at B → distances 30, 0, 30.
        let frames = [
            CGRect(x: -8, y: -4, width: 16, height: 8),
            CGRect(x: 22, y: -4, width: 16, height: 8),
            CGRect(x: 52, y: -4, width: 16, height: 8),
        ]
        let centers = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 30, y: 0),
            CGPoint(x: 60, y: 0),
        ]
        // With tapTolerance=16, expanded frames cover a large range.
        // A's expansion: (-24, -20, 48, 40) — contains (30, 0)? Left=−24, right=24. 30>24 → NO.
        // B's expansion: (6, -20, 48, 40) — contains (30, 0)? Left=6, right=54. YES.
        // C's expansion: (36, -20, 48, 40) — contains (30, 0)? Left=36. 30<36 → NO.
        // Only B qualifies → result is index 1.
        let result = FarmScene.nearestIndex(at: CGPoint(x: 30, y: 0), frames: frames, centers: centers)
        #expect(result == 1)
    }
}

// MARK: - Selection State Transitions

/// Tests handleTap routing and selectedPigID state transitions.
/// Does not require SpriteKit nodes — tests the pure logic paths.
@Suite("Touch Selection State")
@MainActor
struct TouchSelectionStateTests {

    private func makeScene() -> FarmScene {
        FarmScene(gameState: GameState())
    }

    @Test("handleTap on empty scene deselects a previously set selection")
    func tapEmptySceneDeselects() async throws {
        let scene = makeScene()
        let fakeID = UUID()
        scene.selectedPigID = fakeID          // manually set (no PigNode exists)

        scene.handleTap(at: CGPoint(x: 100, y: 100))

        // No pig nodes exist, so the tap hits nothing → deselects.
        #expect(scene.selectedPigID == nil)
    }

    @Test("handleTap on empty scene with no prior selection keeps nil")
    func tapEmptySceneKeepsNil() {
        let scene = makeScene()
        scene.handleTap(at: .zero)
        #expect(scene.selectedPigID == nil)
    }

    @Test("handleTap in edit mode does not change selectedPigID")
    func tapInEditModeDoesNotChangePigSelection() {
        let scene = makeScene()
        let fakeID = UUID()
        scene.selectedPigID = fakeID
        scene.isEditMode = true

        // handleEditModeTap iterates facilityNodes (empty in a fresh scene),
        // so selectedFacilityID stays nil. selectedPigID must remain unchanged.
        scene.handleTap(at: CGPoint(x: 50, y: 50))

        #expect(scene.selectedPigID == fakeID)
    }

    @Test("handleTap outside edit mode clears selectedPigID when no pig is nearby")
    func tapOutsideEditModeWithNoPig() {
        let scene = makeScene()
        scene.isEditMode = false
        scene.selectedPigID = UUID()

        scene.handleTap(at: CGPoint(x: 999, y: 999))

        #expect(scene.selectedPigID == nil)
    }
}

// MARK: - Delegate Firing

/// Verifies that handleTap fires the correct delegate callbacks.
@Suite("Touch Delegate Callbacks")
@MainActor
struct TouchDelegateTests {

    private class SpyDelegate: FarmSceneDelegate {
        var selectedPigIDs: [UUID] = []
        var deselectCallCount: Int = 0

        func farmScene(_ scene: FarmScene, didSelectPig pigID: UUID) {
            selectedPigIDs.append(pigID)
        }
        func farmSceneDidDeselectPig(_ scene: FarmScene) {
            deselectCallCount += 1
        }
        func farmScene(_ scene: FarmScene, didSelectFacility facilityID: UUID) {}
        func farmScene(_ scene: FarmScene, didRemoveFacility facilityID: UUID) {}
    }

    @Test("Tapping empty scene calls didDeselect exactly once")
    func tapEmptyCallsDeselect() {
        let scene = FarmScene(gameState: GameState())
        let spy = SpyDelegate()
        scene.sceneDelegate = spy

        scene.handleTap(at: .zero)

        #expect(spy.deselectCallCount == 1)
        #expect(spy.selectedPigIDs.isEmpty)
    }

    @Test("Tapping empty scene with prior selection calls didDeselect once")
    func tapEmptyWithPriorSelectionCallsDeselect() {
        let scene = FarmScene(gameState: GameState())
        let spy = SpyDelegate()
        scene.sceneDelegate = spy
        scene.selectedPigID = UUID()

        scene.handleTap(at: CGPoint(x: 500, y: 500))

        #expect(spy.deselectCallCount == 1)
        #expect(spy.selectedPigIDs.isEmpty)
    }

    @Test("Edit mode tap does not call pig delegate methods")
    func editModeTapNoPigDelegateCalled() {
        let scene = FarmScene(gameState: GameState())
        let spy = SpyDelegate()
        scene.sceneDelegate = spy
        scene.isEditMode = true

        scene.handleTap(at: .zero)

        #expect(spy.deselectCallCount == 0)
        #expect(spy.selectedPigIDs.isEmpty)
    }
}
