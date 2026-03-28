/// ContentViewModelTests — Tests for ContentViewModel delegate and action methods.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Helper

@MainActor
private func makeViewModel(
    gameState: GameState? = nil,
    onResetFarm: @escaping () -> Void = {}
) -> ContentViewModel {
    let state = gameState ?? GameState()
    let engine = GameEngine(state: state)
    let scene = FarmScene(gameState: state)
    return ContentViewModel(
        gameState: state, engine: engine, scene: scene, onResetFarm: onResetFarm
    )
}

// MARK: - Delegate: Pig Selection

@Suite("ContentViewModel — Pig selection delegate")
@MainActor
struct ContentViewModelPigSelectionTests {

    @Test("Selecting a pig sets selectedPig")
    func pigSelectedSetsState() {
        let state = GameState()
        let pig = GuineaPig.create(name: "Biscuit", gender: .female)
        state.addGuineaPig(pig)
        let vm = makeViewModel(gameState: state)

        vm.farmScene(vm.scene, didSelectPig: pig.id)
        #expect(vm.selectedPig?.id == pig.id)
    }

    @Test("Deselecting a pig clears selectedPig")
    func pigDeselectedClearsState() {
        let vm = makeViewModel()
        vm.selectedPig = GuineaPig.create(name: "Test", gender: .male)
        vm.farmSceneDidDeselectPig(vm.scene)
        #expect(vm.selectedPig == nil)
    }

    @Test("Selecting nonexistent pig sets selectedPig to nil")
    func pigSelectedNotFoundSetsNil() {
        let vm = makeViewModel()
        vm.farmScene(vm.scene, didSelectPig: UUID())
        #expect(vm.selectedPig == nil)
    }
}

// MARK: - Delegate: Facility Selection

@Suite("ContentViewModel — Facility selection delegate")
@MainActor
struct ContentViewModelFacilitySelectionTests {

    @Test("Selecting a facility sets editModeSelectedFacilityID")
    func facilitySelectedSetsID() {
        let vm = makeViewModel()
        let facilityID = UUID()
        vm.farmScene(vm.scene, didSelectFacility: facilityID)
        #expect(vm.editModeSelectedFacilityID == facilityID)
    }

    @Test("Deselecting a facility clears editModeSelectedFacilityID")
    func facilityDeselectedClearsID() {
        let vm = makeViewModel()
        vm.editModeSelectedFacilityID = UUID()
        vm.farmSceneDidDeselectFacility(vm.scene)
        #expect(vm.editModeSelectedFacilityID == nil)
    }
}

// MARK: - Delegate: Facility Removal

@Suite("ContentViewModel — Facility removal delegate")
@MainActor
struct ContentViewModelFacilityRemovalTests {

    @Test("Removing existing facility refunds its cost")
    func facilityRemovedRefundsCost() {
        let state = GameState()
        let initialMoney = state.money
        let facility = Facility.create(type: .foodBowl, x: 3, y: 3)
        _ = state.addFacility(facility)
        let vm = makeViewModel(gameState: state)

        vm.farmScene(vm.scene, didRemoveFacility: facility.id)

        let refund = Shop.getFacilityCost(facilityType: .foodBowl)
        #expect(state.money == initialMoney + refund)
        #expect(state.facilities[facility.id] == nil)
    }

    @Test("Removing facility logs purchase event")
    func facilityRemovedLogsEvent() {
        let state = GameState()
        let facility = Facility.create(type: .foodBowl, x: 3, y: 3)
        _ = state.addFacility(facility)
        let vm = makeViewModel(gameState: state)

        vm.farmScene(vm.scene, didRemoveFacility: facility.id)

        #expect(state.events.contains { $0.eventType == "purchase" && $0.message.contains("Removed") })
    }

    @Test("Removing nonexistent facility is a no-op")
    func facilityRemovedNotFoundIsNoOp() {
        let state = GameState()
        let initialMoney = state.money
        let vm = makeViewModel(gameState: state)
        vm.farmScene(vm.scene, didRemoveFacility: UUID())
        #expect(state.money == initialMoney)
    }
}

// MARK: - Actions: Shop & Sheets

@Suite("ContentViewModel — Sheet and shop actions")
@MainActor
struct ContentViewModelSheetTests {

    @Test("openShop sets tab and showShop flag")
    func openShopSetsState() {
        let vm = makeViewModel()
        vm.openShop(tab: .perks)
        #expect(vm.showShop == true)
        #expect(vm.shopInitialTab == .perks)
    }

    @Test("handleFollowPig clears selection and pig list sheet")
    func handleFollowPigClearsState() {
        let vm = makeViewModel()
        vm.selectedPig = GuineaPig.create(name: "Test", gender: .male)
        vm.showPigList = true

        vm.handleFollowPig(UUID())

        #expect(vm.selectedPig == nil)
        #expect(vm.showPigList == false)
    }
}

// MARK: - Actions: Edit Mode

@Suite("ContentViewModel — Edit mode actions")
@MainActor
struct ContentViewModelEditModeTests {

    @Test("toggleEditMode toggles isEditMode and syncs scene")
    func toggleEditModeSyncsScene() {
        let state = GameState()
        state.farm = FarmGrid.createStarter()
        let vm = makeViewModel(gameState: state)

        vm.toggleEditMode()
        #expect(vm.isEditMode == true)
        #expect(vm.scene.isEditMode == true)

        vm.toggleEditMode()
        #expect(vm.isEditMode == false)
        #expect(vm.scene.isEditMode == false)
    }

    @Test("toggleEditMode off clears facility selection and drag state")
    func toggleEditModeOffClearsSelection() {
        let state = GameState()
        state.farm = FarmGrid.createStarter()
        let vm = makeViewModel(gameState: state)
        vm.isEditMode = true
        vm.editModeSelectedFacilityID = UUID()
        vm.isDraggingFacility = true

        vm.toggleEditMode()

        #expect(vm.editModeSelectedFacilityID == nil)
        #expect(vm.isDraggingFacility == false)
    }

    @Test("handleRemoveFacility shows confirmation dialog")
    func handleRemoveFacilityShowsConfirmation() {
        let vm = makeViewModel()
        vm.handleRemoveFacility()
        #expect(vm.showRemoveConfirmation == true)
    }

    @Test("confirmRemoveFacility clears drag and selection state")
    func confirmRemoveFacilityClearsState() {
        let state = GameState()
        state.farm = FarmGrid.createStarter()
        let vm = makeViewModel(gameState: state)
        vm.editModeSelectedFacilityID = UUID()
        vm.isDraggingFacility = true

        vm.confirmRemoveFacility()

        #expect(vm.editModeSelectedFacilityID == nil)
        #expect(vm.isDraggingFacility == false)
    }
}

// MARK: - Actions: Auto-Arrange

@Suite("ContentViewModel — Auto-arrange action")
@MainActor
struct ContentViewModelAutoArrangeTests {

    @Test("performAutoArrange preserves facility count")
    func autoArrangePreservesFacilityCount() {
        let state = GameState()
        state.farm = FarmGrid.createStarter()
        _ = state.addFacility(Facility.create(type: .foodBowl, x: 3, y: 3))
        _ = state.addFacility(Facility.create(type: .waterBottle, x: 5, y: 3))
        let vm = makeViewModel(gameState: state)
        let initialCount = state.getFacilitiesList().count

        vm.performAutoArrange()

        #expect(state.getFacilitiesList().count == initialCount)
    }

    @Test("performAutoArrange with empty farm is a no-op")
    func autoArrangeEmptyFarmNoOp() {
        let state = GameState()
        state.farm = FarmGrid.createStarter()
        let vm = makeViewModel(gameState: state)
        vm.performAutoArrange()
        #expect(state.getFacilitiesList().isEmpty)
    }
}

// MARK: - Actions: Reset Farm

@Suite("ContentViewModel — Reset farm action")
@MainActor
struct ContentViewModelResetFarmTests {

    @Test("handleResetFarm clears all sheet and mode state")
    func handleResetFarmClearsAll() {
        var resetCalled = false
        let state = GameState()
        state.farm = FarmGrid.createStarter()
        let vm = makeViewModel(gameState: state, onResetFarm: { resetCalled = true })
        vm.showShop = true
        vm.showPigList = true
        vm.showBreeding = true
        vm.showAlmanac = true
        vm.isEditMode = true
        vm.isTreatMode = true
        vm.selectedPig = GuineaPig.create(name: "Test", gender: .male)

        vm.handleResetFarm()

        #expect(vm.showShop == false)
        #expect(vm.showPigList == false)
        #expect(vm.showBreeding == false)
        #expect(vm.showAlmanac == false)
        #expect(vm.isEditMode == false)
        #expect(vm.isTreatMode == false)
        #expect(vm.selectedPig == nil)
        #expect(vm.editModeSelectedFacilityID == nil)
        #expect(vm.isDraggingFacility == false)
        #expect(resetCalled)
    }
}

// MARK: - Scene Sync

@Suite("ContentViewModel — Scene sync")
@MainActor
struct ContentViewModelSceneSyncTests {

    @Test("syncTreatMode enables treat placement on scene")
    func syncTreatModeEnablesPlacement() {
        let state = GameState()
        state.farm = FarmGrid.createStarter()
        let vm = makeViewModel(gameState: state)
        vm.isTreatMode = true

        vm.syncTreatMode()

        #expect(vm.scene.isTreatPlacementMode == true)
    }

    @Test("syncTreatMode exits edit mode when entering treat mode")
    func syncTreatModeExitsEditMode() {
        let state = GameState()
        state.farm = FarmGrid.createStarter()
        let vm = makeViewModel(gameState: state)
        vm.isEditMode = true
        vm.isTreatMode = true

        vm.syncTreatMode()

        #expect(vm.isEditMode == false)
    }

    @Test("syncTreatType updates scene treat type")
    func syncTreatTypeUpdatesScene() {
        let state = GameState()
        state.farm = FarmGrid.createStarter()
        let vm = makeViewModel(gameState: state)
        vm.selectedTreatType = .carrotStick

        vm.syncTreatType()

        #expect(vm.scene.selectedTreatType == .carrotStick)
    }
}
