/// ContentView — SpriteView root with SwiftUI HUD overlay and sheet wiring.
/// Maps from: ui/screens/main_game.py (MainGameScreen)
import SwiftUI
import SpriteKit

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
    /// View model owning presentation state and domain actions.
    @State var viewModel: ContentViewModel

    /// Toast notification coordinator. Passed as `let` (not @State) because it's
    /// created once in BigPigFarmApp and never replaced. @Observable tracking works
    /// through ToastOverlayView's body reading visibleToasts — no wrapper needed.
    let notificationManager: NotificationManager

    /// Non-nil while the offline progress summary popup is presented.
    @Binding var offlineSummary: OfflineProgressSummary?

    // MARK: - Init

    init(
        gameState: GameState,
        engine: GameEngine,
        notificationManager: NotificationManager,
        offlineSummary: Binding<OfflineProgressSummary?>,
        onResetFarm: @escaping () -> Void
    ) {
        let scene = FarmScene(gameState: gameState)
        _viewModel = State(initialValue: ContentViewModel(
            gameState: gameState, engine: engine, scene: scene, onResetFarm: onResetFarm
        ))
        self.notificationManager = notificationManager
        _offlineSummary = offlineSummary
    }

    // MARK: - Body

    var body: some View {
        @Bindable var viewModel = viewModel
        ZStack(alignment: .top) {
            // Farm scene — full screen, captures all touches not intercepted by HUD
            SpriteView(
                scene: viewModel.scene,
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
                StatusInfoRow(gameState: viewModel.gameState)
                HStack(spacing: 8) {
                    StreakIndicator(streak: viewModel.gameState.prestigeState.visitStreak)
                    ReunionBoostIndicator(
                        boost: viewModel.gameState.prestigeState.activeReunionBoost
                    )
                    Spacer()
                }
                .padding(.horizontal, 8)
                if EmergencyBailout.isSoftLocked(state: viewModel.gameState) {
                    EmergencyBailoutBanner {
                        viewModel.openShop(tab: .pigs)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                ToastOverlayView(notificationManager: notificationManager)
                CoachMarkOverlayView(
                    gameState: viewModel.gameState, coachState: $viewModel.coachMarkState
                )
                if viewModel.isEditMode {
                    EditModeActionPanel(
                        selectedFacilityID: viewModel.editModeSelectedFacilityID,
                        isDragging: viewModel.isDraggingFacility,
                        onRemove: { viewModel.handleRemoveFacility() },
                        onAutoArrange: { viewModel.performAutoArrange() }
                    )
                }
                StatusToolbar(
                    gameState: viewModel.gameState,
                    isEditMode: $viewModel.isEditMode,
                    isTreatMode: $viewModel.isTreatMode,
                    selectedTreatType: $viewModel.selectedTreatType,
                    onShopTapped: { viewModel.openShop(tab: .facilities) },
                    onPigListTapped: { viewModel.showPigList = true },
                    onBreedingTapped: { viewModel.showBreeding = true },
                    onAlmanacTapped: { viewModel.showAlmanac = true },
                    onShowroomTapped: { viewModel.showShowroom = true },
                    onAtlasTapped: { viewModel.showAtlas = true },
                    onRefillTapped: { viewModel.gameState.manualRefillAll() },
                    onPigShowTapped: { viewModel.showPigShow = true },
                    onEditTapped: { viewModel.toggleEditMode() },
                    onPauseTapped: { viewModel.togglePause() },
                    onSpeedTapped: { viewModel.cycleSpeed() }
                )
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .sheet(isPresented: $viewModel.showShop) {
            ShopView(gameState: viewModel.gameState, initialTab: viewModel.shopInitialTab)
        }
        .sheet(isPresented: $viewModel.showPigList) {
            PigListView(gameState: viewModel.gameState, onFollowPig: viewModel.handleFollowPig)
        }
        .sheet(isPresented: $viewModel.showBreeding) {
            BreedingView(gameState: viewModel.gameState)
        }
        .sheet(isPresented: $viewModel.showAlmanac) {
            AlmanacView(
                gameState: viewModel.gameState, onResetFarm: viewModel.handleResetFarm
            )
        }
        .sheet(isPresented: $viewModel.showShowroom) {
            ShowroomView(gameState: viewModel.gameState)
        }
        .sheet(isPresented: $viewModel.showAtlas) {
            BiomeAtlasView(gameState: viewModel.gameState)
        }
        .pigDetailSheet(
            pig: $viewModel.selectedPig,
            gameState: viewModel.gameState,
            onFollow: { pigID in viewModel.scene.centerOnPig(pigID) }
        )
        .fullScreenCover(item: $offlineSummary) { summary in
            OfflineProgressView(summary: summary, onContinue: {
                offlineSummary = nil
                viewModel.engine.resume()
            })
        }
        .fullScreenCover(isPresented: $viewModel.showPigShow, onDismiss: {
            viewModel.dismissPigShow()
        }, content: {
            PigShowView(
                gameState: viewModel.gameState,
                onPrestigeConfirmed: { breakdown in
                    viewModel.pendingPrestigeBreakdown = breakdown
                    viewModel.showPigShow = false
                }
            )
        })
        .onChange(of: viewModel.showPigShow) { _, isShowing in
            if isShowing { viewModel.openPigShow() }
        }
        .confirmationDialog(
            "Remove Facility",
            isPresented: $viewModel.showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { viewModel.confirmRemoveFacility() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The facility will be removed and its cost refunded.")
        }
        .onAppear { viewModel.start() }
        .onChange(of: viewModel.isTreatMode) { _, _ in viewModel.syncTreatMode() }
        .onChange(of: viewModel.selectedTreatType) { _, _ in viewModel.syncTreatType() }
    }
}
