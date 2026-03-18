/// EditModeActionPanelTests — Tests for edit mode action panel logic, callbacks,
/// and the drag/remove/auto-arrange call sequences.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Coordinator Facility Selection Callbacks

@Suite("FarmSceneCoordinator facility callbacks")
@MainActor
struct CoordinatorFacilityCallbackTests {

    let state = GameState()
    var coord: FarmSceneCoordinator { FarmSceneCoordinator(gameState: state) }
    var scene: FarmScene { FarmScene(gameState: state) }

    @Test("Selecting a facility fires onFacilitySelected with its ID")
    func facilitySelectedFiresCallback() {
        let coordinator = coord
        var capturedID: UUID?
        coordinator.onFacilitySelected = { capturedID = $0 }
        let facilityID = UUID()
        coordinator.farmScene(scene, didSelectFacility: facilityID)
        #expect(capturedID == facilityID)
    }

    @Test("Deselecting a facility fires onFacilitySelected with nil")
    func facilityDeselectedFiresCallbackWithNil() {
        let coordinator = coord
        var capturedID: UUID? = UUID()   // start non-nil
        coordinator.onFacilitySelected = { capturedID = $0 }
        coordinator.farmSceneDidDeselectFacility(scene)
        #expect(capturedID == nil)
    }

    @Test("No onFacilitySelected callback registered does not crash on select")
    func facilitySelectedNoCallbackNoCrash() {
        coord.farmScene(scene, didSelectFacility: UUID())
    }

    @Test("No onFacilitySelected callback registered does not crash on deselect")
    func facilityDeselectedNoCallbackNoCrash() {
        coord.farmSceneDidDeselectFacility(scene)
    }
}

// MARK: - FarmScene Drag State

@Suite("FarmScene drag state")
@MainActor
struct FarmSceneDragStateTests {

    let state: GameState = {
        let gameState = GameState()
        gameState.farm = FarmGrid.createStarter()
        return gameState
    }()

    @Test("beginDraggingFacility sets both selectedFacilityID and draggedFacilityID")
    func beginDraggingSetsState() {
        let farmScene = FarmScene(gameState: state)
        let facility = Facility.create(type: .foodBowl, x: 2, y: 2)
        _ = state.addFacility(facility)
        farmScene.beginDraggingFacility(facility.id)
        #expect(farmScene.selectedFacilityID == facility.id)
        #expect(farmScene.draggedFacilityID == facility.id)
    }

    @Test("beginDraggingFacility fires onFacilityDragBegan callback")
    func beginDraggingFiresCallback() {
        let farmScene = FarmScene(gameState: state)
        var capturedID: UUID?
        farmScene.onFacilityDragBegan = { capturedID = $0 }
        let facility = Facility.create(type: .foodBowl, x: 2, y: 2)
        _ = state.addFacility(facility)
        farmScene.beginDraggingFacility(facility.id)
        #expect(capturedID == facility.id)
    }

    @Test("confirmFacilityPlacement clears draggedFacilityID")
    func confirmPlacementClearsDrag() {
        let farmScene = FarmScene(gameState: state)
        let facility = Facility.create(type: .foodBowl, x: 2, y: 2)
        _ = state.addFacility(facility)
        farmScene.beginDraggingFacility(facility.id)
        farmScene.confirmFacilityPlacement()
        #expect(farmScene.draggedFacilityID == nil)
    }

    @Test("confirmFacilityPlacement calls onFacilityMoveEnded")
    func confirmPlacementCallsClosure() {
        let farmScene = FarmScene(gameState: state)
        var called = false
        farmScene.onFacilityMoveEnded = { called = true }
        farmScene.draggedFacilityID = UUID()
        farmScene.confirmFacilityPlacement()
        #expect(called == true)
    }

    @Test("confirmFacilityPlacement without closure registered does not crash")
    func confirmPlacementNoClosureNoCrash() {
        let farmScene = FarmScene(gameState: state)
        farmScene.onFacilityMoveEnded = nil
        farmScene.draggedFacilityID = UUID()
        farmScene.confirmFacilityPlacement()
    }

    @Test("confirmFacilityPlacement does not call onFacilityMoveEnded when not dragging")
    func confirmPlacementGuardPreventsClosure() {
        let farmScene = FarmScene(gameState: state)
        var called = false
        farmScene.onFacilityMoveEnded = { called = true }
        farmScene.draggedFacilityID = nil
        farmScene.confirmFacilityPlacement()
        #expect(called == false)
    }
}

// MARK: - FarmScene Remove State

@Suite("FarmScene remove state")
@MainActor
struct FarmSceneRemoveStateTests {

    let state: GameState = {
        let gameState = GameState()
        gameState.farm = FarmGrid.createStarter()
        return gameState
    }()

    @Test("removeSelectedFacility with no selection does not crash")
    func removeWithNoSelectionNoCrash() {
        let farmScene = FarmScene(gameState: state)
        farmScene.selectedFacilityID = nil
        farmScene.removeSelectedFacility()
    }

    @Test("removeSelectedFacility clears selectedFacilityID and draggedFacilityID")
    func removeClearsSelectionState() {
        let farmScene = FarmScene(gameState: state)
        let facility = Facility.create(type: .foodBowl, x: 2, y: 2)
        _ = state.addFacility(facility)
        farmScene.selectedFacilityID = facility.id
        farmScene.draggedFacilityID = facility.id
        farmScene.removeSelectedFacility()
        #expect(farmScene.selectedFacilityID == nil)
        #expect(farmScene.draggedFacilityID == nil)
    }

    @Test("removeSelectedFacility removes the facility from game state")
    func removeClearsFromGameState() {
        let farmScene = FarmScene(gameState: state)
        let facility = Facility.create(type: .foodBowl, x: 2, y: 2)
        _ = state.addFacility(facility)
        farmScene.selectedFacilityID = facility.id
        farmScene.removeSelectedFacility()
        #expect(state.getFacility(facility.id) == nil)
    }
}

// MARK: - FarmScene Facility Hit Test

@Suite("Facility hit test")
@MainActor
struct FacilityHitTestTests {

    @Test("facilityIDAtPoint returns nil on empty scene")
    func hitTestEmptySceneReturnsNil() {
        let farmScene = FarmScene(gameState: GameState())
        #expect(farmScene.facilityIDAtPoint(.zero) == nil)
    }
}

// MARK: - Auto-Arrange Integration

@Suite("Auto-arrange via ContentView action")
@MainActor
struct AutoArrangeActionTests {

    private func makeStateWithFacilities() -> GameState {
        let gameState = GameState()
        gameState.farm = FarmGrid.createStarter()
        _ = gameState.addFacility(Facility.create(type: .foodBowl, x: 3, y: 3))
        _ = gameState.addFacility(Facility.create(type: .waterBottle, x: 5, y: 3))
        _ = gameState.addFacility(Facility.create(type: .hideout, x: 7, y: 3))
        return gameState
    }

    @Test("computeArrangement with no facilities returns empty placements")
    func computeArrangementEmptyFarm() {
        let gameState = GameState()
        gameState.farm = FarmGrid.createStarter()
        let (placements, overflow) = AutoArrange.computeArrangement(state: gameState)
        #expect(placements.isEmpty)
        #expect(overflow.isEmpty)
    }

    @Test("applyArrangement preserves facility count")
    func applyArrangementPreservesCount() {
        let gameState = makeStateWithFacilities()
        let initialCount = gameState.getFacilitiesList().count
        let (placements, overflow) = AutoArrange.computeArrangement(state: gameState)
        AutoArrange.applyArrangement(state: gameState, placements: placements, overflow: overflow)
        #expect(gameState.getFacilitiesList().count == initialCount)
    }

    @Test("clearPigNavigation with no pigs does not crash")
    func clearPigNavigationNoPigsNoCrash() {
        let gameState = GameState()
        gameState.farm = FarmGrid.createStarter()
        AutoArrange.clearPigNavigation(state: gameState)
    }
}
