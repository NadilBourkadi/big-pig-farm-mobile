/// ContentView — SpriteView root with SwiftUI HUD overlay and sheet wiring.
/// Maps from: ui/screens/main_game.py (MainGameScreen)
import SwiftUI
import SpriteKit

// MARK: - FarmSceneCoordinator

/// Bridges FarmScene delegate callbacks to SwiftUI state in ContentView.
///
/// FarmScene holds a weak reference to its delegate. Since ContentView is
/// a struct, this coordinator class acts as the intermediary. It uses
/// closure callbacks (not a back-reference to ContentView, which is a struct
/// and cannot be held weakly) to forward events to ContentView's @State.
///
/// Maps from: main_game.py event handlers (on_pig_tapped, on_facility_removed, etc.)
@MainActor
final class FarmSceneCoordinator: FarmSceneDelegate {
    private let gameState: GameState

    /// Called when the player taps a pig in the scene.
    var onPigSelected: ((UUID) -> Void)?

    /// Called when the player deselects a pig (tap on empty area).
    var onPigDeselected: (() -> Void)?

    /// Called when the player selects or deselects a facility in edit mode.
    /// Passes the selected facility's UUID, or nil when deselected.
    var onFacilitySelected: ((UUID?) -> Void)?

    init(gameState: GameState) {
        self.gameState = gameState
    }

    func farmScene(_ scene: FarmScene, didSelectPig pigID: UUID) {
        onPigSelected?(pigID)
    }

    func farmSceneDidDeselectPig(_ scene: FarmScene) {
        onPigDeselected?()
    }

    func farmScene(_ scene: FarmScene, didSelectFacility facilityID: UUID) {
        onFacilitySelected?(facilityID)
    }

    func farmSceneDidDeselectFacility(_ scene: FarmScene) {
        onFacilitySelected?(nil)
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
}

// MARK: - ContentView

/// Root view of the app. Embeds the SpriteKit farm scene and overlays
/// SwiftUI HUD elements. Menu screens are presented as .sheet modifiers.
///
/// Maps from: ui/screens/main_game.py (MainGameScreen)
///
/// Architecture: SpriteView displays FarmScene. StatusInfoRow is pinned at
/// the top and StatusToolbar at the bottom. Shop, PigList, Breeding, etc.
/// are presented via .sheet when triggered by toolbar button taps.
struct ContentView: View {
    /// The shared game state, created by BigPigFarmApp.
    @State var gameState: GameState

    /// The game engine managing the tick loop.
    @State var engine: GameEngine

    /// The farm scene displayed in SpriteView.
    @State private var farmScene: FarmScene

    /// Coordinator that bridges FarmScene delegate callbacks to SwiftUI state.
    @State private var coordinator: FarmSceneCoordinator

    // MARK: - Sheet Presentation State

    @State private var showShop = false
    @State private var showPigList = false
    @State private var showBreeding = false
    @State private var showAlmanac = false
    /// The pig currently selected for detail view. Non-nil while the detail sheet is presented.
    @State private var selectedPig: GuineaPig?

    /// Whether edit mode is currently active.
    @State private var isEditMode = false

    // MARK: - Edit Mode Panel State

    /// The facility currently selected in edit mode, mirrored from scene delegate callbacks.
    @State private var editModeSelectedFacilityID: UUID?

    /// True while the user is actively dragging a facility to a new position.
    @State private var editModeIsMovingFacility = false

    /// Controls visibility of the remove-facility confirmation dialog.
    @State private var showRemoveConfirmation = false

    // MARK: - Init

    init(gameState: GameState, engine: GameEngine) {
        let gs = gameState
        _gameState = State(initialValue: gs)
        _engine = State(initialValue: engine)
        _farmScene = State(initialValue: FarmScene(gameState: gs))
        _coordinator = State(initialValue: FarmSceneCoordinator(gameState: gs))
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // Farm scene — full screen, captures all touches not intercepted by HUD
            SpriteView(
                scene: farmScene,
                transition: nil,
                isPaused: false,
                preferredFramesPerSecond: 60,
                options: [],
                debugOptions: []
            )
            .ignoresSafeArea()

            // HUD overlay — StatusInfoRow pinned top, StatusToolbar pinned bottom.
            // EditModeActionPanel appears above the toolbar while edit mode is active.
            VStack {
                StatusInfoRow(gameState: gameState)
                Spacer()
                if isEditMode {
                    EditModeActionPanel(
                        selectedFacilityID: editModeSelectedFacilityID,
                        isMovingFacility: editModeIsMovingFacility,
                        onMove: { startMoveFacility() },
                        onRemove: { handleRemoveFacility() },
                        onAutoArrange: { performAutoArrange() }
                    )
                }
                StatusToolbar(
                    gameState: gameState,
                    isEditMode: $isEditMode,
                    onShopTapped: { showShop = true },
                    onPigListTapped: { showPigList = true },
                    onBreedingTapped: { showBreeding = true },
                    onAlmanacTapped: { showAlmanac = true },
                    onRefillTapped: { gameState.manualRefillAll() },
                    onEditTapped: { toggleEditMode() },
                    onPauseTapped: { togglePause() },
                    onSpeedTapped: { cycleSpeed() }
                )
            }
        }
        .sheet(isPresented: $showShop) {
            ShopView(gameState: gameState)
        }
        .sheet(isPresented: $showPigList) {
            PigListView(gameState: gameState, onFollowPig: handleFollowPig)
        }
        .sheet(isPresented: $showBreeding) {
            BreedingView(gameState: gameState)
        }
        .sheet(isPresented: $showAlmanac) {
            AlmanacView(gameState: gameState)
        }
        .sheet(item: $selectedPig) { pig in
            NavigationStack {
                PigDetailView(gameState: gameState, pig: pig)
                    .navigationTitle(pig.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { selectedPig = nil }
                        }
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Follow") {
                                farmScene.centerOnPig(pig.id)
                            }
                        }
                    }
            }
            .background(.clear)
            .presentationDetents([.fraction(0.45), .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.45)))
            .presentationContentInteraction(.scrolls)
            .presentationBackground(.ultraThinMaterial)
        }
        .confirmationDialog(
            "Remove Facility",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { confirmRemoveFacility() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The facility will be removed and its cost refunded.")
        }
        .onAppear {
            farmScene.sceneDelegate = coordinator
            coordinator.onPigSelected = { pigID in
                selectedPig = gameState.getGuineaPig(pigID)
                farmScene.centerOnPig(pigID)
            }
            coordinator.onPigDeselected = {
                selectedPig = nil
            }
            coordinator.onFacilitySelected = { facilityID in
                editModeSelectedFacilityID = facilityID
            }
            farmScene.onFacilityMoveEnded = {
                editModeIsMovingFacility = false
            }
            engine.start()
        }
    }
}

// MARK: - ContentView Actions

extension ContentView {

    /// Toggle the game pause state.
    ///
    /// Maps from: main_game.py action_toggle_pause()
    private func togglePause() {
        _ = engine.togglePause()
    }

    /// Cycle the game speed setting.
    ///
    /// Maps from: main_game.py action_speed_up()
    private func cycleSpeed() {
        _ = engine.cycleSpeed()
    }

    /// Toggle edit mode on the farm scene.
    ///
    /// Maps from: main_game.py action_toggle_edit()
    private func toggleEditMode() {
        isEditMode.toggle()
        farmScene.isEditMode = isEditMode
        if !isEditMode {
            if editModeIsMovingFacility {
                // endFacilityMove calls onFacilityMoveEnded, which resets editModeIsMovingFacility.
                farmScene.endFacilityMove()
            }
            farmScene.selectedFacilityID = nil
            editModeSelectedFacilityID = nil
        }
    }

    /// Start moving the currently selected facility.
    private func startMoveFacility() {
        farmScene.beginFacilityMove()
        editModeIsMovingFacility = true
    }

    /// Show the remove-facility confirmation dialog.
    private func handleRemoveFacility() {
        showRemoveConfirmation = true
    }

    /// Execute facility removal after the user confirms the destructive action.
    private func confirmRemoveFacility() {
        farmScene.removeSelectedFacility()
        editModeSelectedFacilityID = nil
        // Defensive reset: the Remove button is disabled during an active move,
        // but reset here in case the confirmation dialog outlives a move end.
        editModeIsMovingFacility = false
    }

    /// Compute and apply the auto-arrange layout, then reset pig navigation paths.
    ///
    /// Maps from: game/auto_arrange.py AutoArrange.apply_arrangement()
    private func performAutoArrange() {
        let (placements, overflow) = AutoArrange.computeArrangement(state: gameState)
        AutoArrange.applyArrangement(state: gameState, placements: placements, overflow: overflow)
        AutoArrange.clearPigNavigation(state: gameState)
    }

    /// Follow a pig on the farm, dismissing any open sheet.
    ///
    /// Maps from: main_game.py _follow_pig(), pig_list.py action_follow_pig()
    private func handleFollowPig(_ pigID: UUID) {
        selectedPig = nil
        showPigList = false
        farmScene.centerOnPig(pigID)
    }
}
