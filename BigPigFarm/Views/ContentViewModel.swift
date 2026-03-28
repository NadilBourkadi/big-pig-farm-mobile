/// ContentViewModel — Presentation logic and scene delegate for ContentView.
/// Replaces FarmSceneCoordinator and ContentView action methods.
/// Maps from: ui/screens/main_game.py (MainGameScreen)
import SwiftUI
import SpriteKit

@MainActor @Observable
final class ContentViewModel: FarmSceneDelegate {

    // MARK: - Dependencies

    let gameState: GameState
    let engine: GameEngine
    let scene: FarmScene
    private let resetFarmHandler: () -> Void

    // MARK: - Sheet Presentation

    var showShop = false
    var shopInitialTab: ShopTab = .facilities
    var showPigList = false
    var showBreeding = false
    var showAlmanac = false
    var showShowroom = false
    var showAtlas = false
    var selectedPig: GuineaPig?

    // MARK: - Mode State

    var isEditMode = false
    var isTreatMode = false
    var selectedTreatType: TreatType = .leafyGreens
    var coachMarkState = CoachMarkState.load()
    var showPigShow = false
    var pendingPrestigeBreakdown: RosetteBreakdown?

    // MARK: - Edit Mode Panel

    var editModeSelectedFacilityID: UUID?
    var isDraggingFacility = false
    var showRemoveConfirmation = false

    // MARK: - Init

    init(
        gameState: GameState,
        engine: GameEngine,
        scene: FarmScene,
        onResetFarm: @escaping () -> Void
    ) {
        self.gameState = gameState
        self.engine = engine
        self.scene = scene
        self.resetFarmHandler = onResetFarm
    }

    // MARK: - Scene Wiring

    /// Wire up scene delegate and closure callbacks, then start the engine.
    /// Called once from ContentView's onAppear.
    func start() {
        scene.sceneDelegate = self
        scene.onFacilityDragBegan = { [weak self] facilityID in
            self?.editModeSelectedFacilityID = facilityID
            self?.isDraggingFacility = true
        }
        scene.onFacilityMoveEnded = { [weak self] in
            self?.isDraggingFacility = false
        }
        scene.onFacilityLongPressed = { [weak self] facilityID in
            guard let self else { return }
            isEditMode = true
            scene.isEditMode = true
            editModeSelectedFacilityID = facilityID
            scene.selectedFacilityID = facilityID
            HapticManager.pigSelected()
        }
        scene.onTreatsExhausted = { [weak self] in
            self?.isTreatMode = false
        }
        engine.start()
    }

    // MARK: - FarmSceneDelegate

    func farmScene(_ scene: FarmScene, didSelectPig pigID: UUID) {
        selectedPig = gameState.getGuineaPig(pigID)
        scene.centerOnPig(pigID)
    }

    func farmSceneDidDeselectPig(_ scene: FarmScene) {
        selectedPig = nil
    }

    func farmScene(_ scene: FarmScene, didSelectFacility facilityID: UUID) {
        editModeSelectedFacilityID = facilityID
    }

    func farmSceneDidDeselectFacility(_ scene: FarmScene) {
        editModeSelectedFacilityID = nil
    }

    func farmScene(_ scene: FarmScene, didRemoveFacility facilityID: UUID) {
        if let facility = gameState.removeFacility(facilityID) {
            let refund = Shop.getFacilityCost(facilityType: facility.facilityType)
            gameState.addMoney(refund)
            gameState.logEvent(
                "Removed \(facility.name) (+\(Currency.formatCurrency(refund)))",
                eventType: "purchase"
            )
        }
    }

    // MARK: - Actions

    func openShop(tab: ShopTab) {
        shopInitialTab = tab
        showShop = true
    }

    /// Toggle the game pause state.
    /// Maps from: main_game.py action_toggle_pause()
    func togglePause() {
        _ = engine.togglePause()
    }

    /// Cycle the game speed setting.
    /// Maps from: main_game.py action_speed_up()
    func cycleSpeed() {
        _ = engine.cycleSpeed()
    }

    /// Toggle edit mode on the farm scene.
    /// Maps from: main_game.py action_toggle_edit()
    func toggleEditMode() {
        isEditMode.toggle()
        scene.isEditMode = isEditMode
        if !isEditMode {
            scene.selectedFacilityID = nil
            scene.draggedFacilityID = nil
            editModeSelectedFacilityID = nil
            isDraggingFacility = false
        }
    }

    func handleRemoveFacility() {
        showRemoveConfirmation = true
    }

    func confirmRemoveFacility() {
        scene.removeSelectedFacility()
        editModeSelectedFacilityID = nil
        isDraggingFacility = false
    }

    /// Compute and apply the auto-arrange layout, then reset pig navigation paths.
    /// Maps from: game/auto_arrange.py AutoArrange.apply_arrangement()
    func performAutoArrange() {
        let (placements, overflow) = AutoArrange.computeArrangement(state: gameState)
        AutoArrange.applyArrangement(
            state: gameState, placements: placements, overflow: overflow
        )
        AutoArrange.clearPigNavigation(state: gameState)
    }

    /// Follow a pig on the farm, dismissing any open sheet.
    /// Maps from: main_game.py _follow_pig(), pig_list.py action_follow_pig()
    func handleFollowPig(_ pigID: UUID) {
        selectedPig = nil
        showPigList = false
        scene.centerOnPig(pigID)
    }

    /// Dismiss all sheets, reset UI state, and perform the full farm reset.
    func handleResetFarm() {
        showAlmanac = false
        showShowroom = false
        showAtlas = false
        showShop = false
        showPigList = false
        showBreeding = false
        selectedPig = nil
        isEditMode = false
        isTreatMode = false
        selectedTreatType = .leafyGreens
        scene.isEditMode = false
        scene.isTreatPlacementMode = false
        scene.selectedFacilityID = nil
        scene.draggedFacilityID = nil
        editModeSelectedFacilityID = nil
        isDraggingFacility = false
        resetFarmHandler()
    }

    /// Pause engine when pig show opens.
    func openPigShow() {
        engine.pause()
    }

    /// Handle pig show dismissal — either trigger prestige or resume engine.
    func dismissPigShow() {
        if let breakdown = pendingPrestigeBreakdown {
            pendingPrestigeBreakdown = nil
            executePrestige(breakdown)
        } else {
            engine.resume()
        }
    }

    /// Execute the prestige reset with a SpriteKit transition animation.
    /// Flow: pause engine -> play parade animation -> triggerPrestige -> sunrise -> resume.
    func executePrestige(_ breakdown: RosetteBreakdown) {
        engine.pause()
        let newFarmNumber = gameState.prestigeState.farmCount + 1
        scene.playPrestigeTransition(farmNumber: newFarmNumber) { [weak self] in
            guard let self else { return }
            engine.triggerPrestige()
            engine.resume()
        }
    }

    // MARK: - Scene Sync

    /// Sync treat mode state to the scene. Called from onChange(of: isTreatMode).
    func syncTreatMode() {
        scene.isTreatPlacementMode = isTreatMode
        if isTreatMode && isEditMode {
            toggleEditMode()
        }
    }

    /// Sync treat type to the scene. Called from onChange(of: selectedTreatType).
    func syncTreatType() {
        scene.selectedTreatType = selectedTreatType
    }
}
