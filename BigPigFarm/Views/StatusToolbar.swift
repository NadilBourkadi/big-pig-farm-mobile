/// StatusToolbar — HUD action strip with navigation and control buttons.
/// Extracted from StatusBarView; positioned at the bottom of the screen.
import SwiftUI

// MARK: - StatusToolbar

/// Bottom-of-screen HUD toolbar exposing game navigation and control actions.
///
/// All mutations are delegated back to the caller via action closures.
/// Edit-mode highlighting state is read from the `isEditMode` binding.
struct StatusToolbar: View {
    let gameState: GameState

    /// Two-way binding to ContentView's edit-mode state.
    @Binding var isEditMode: Bool

    /// Two-way binding to ContentView's treat-placement mode state.
    @Binding var isTreatMode: Bool

    /// Two-way binding to ContentView's selected treat type.
    @Binding var selectedTreatType: TreatType

    // MARK: - Action Callbacks

    var onShopTapped: () -> Void
    var onPigListTapped: () -> Void
    var onBreedingTapped: () -> Void
    var onAlmanacTapped: () -> Void
    var onShowroomTapped: () -> Void
    var onAtlasTapped: () -> Void
    var onRefillTapped: () -> Void
    var onPigShowTapped: (() -> Void)?
    var onEditTapped: () -> Void
    var onPauseTapped: () -> Void
    var onSpeedTapped: () -> Void

    /// Whether the Pig Show button should be visible (lifetime + current run Squeaks >= threshold).
    private var isPigShowEligible: Bool {
        let lifetime = gameState.prestigeState.lifetimeStats.totalSqueaksEarned
        let current = gameState.totalEarnings
        return lifetime + current >= GameConfig.Prestige.pigShowLifetimeSqueaksThreshold
    }

    var body: some View {
        VStack(spacing: 0) {
            gameActionRow
                .padding(.top, 6)
                .padding(.bottom, 4)

            Divider()
                .opacity(0.3)

            systemControlRow
                .padding(.top, 4)
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Sub-views

private extension StatusToolbar {
    var gameActionRow: some View {
        HStack(spacing: 6) {
            HUDButton(systemImage: "cart.fill", label: "Shop", action: onShopTapped)
            HUDButton(systemImage: "list.bullet", label: "Pigs", action: onPigListTapped)
            HUDButton(systemImage: "heart.fill", label: "Breed", action: onBreedingTapped)
            HUDButton(systemImage: "books.vertical.fill", label: "Almanac", action: onAlmanacTapped)
            HUDButton(systemImage: "rosette", label: "Showroom", action: onShowroomTapped)
            HUDButton(systemImage: "map.fill", label: "Atlas", action: onAtlasTapped)

            refillButton
            TreatHUDButton(
                gameState: gameState,
                isTreatMode: $isTreatMode,
                selectedTreatType: $selectedTreatType
            )

            if isPigShowEligible, let onPigShowTapped {
                HUDButton(systemImage: "trophy.fill", label: "Show", action: onPigShowTapped)
            }
        }
        .frame(maxWidth: .infinity)
    }

    var systemControlRow: some View {
        HStack(spacing: 12) {
            Spacer()
            HUDButton(
                systemImage: isEditMode ? "pencil.slash" : "pencil",
                label: "Edit",
                isActive: isEditMode,
                action: onEditTapped
            )
            HUDButton(
                systemImage: gameState.isPaused ? "play.fill" : "pause.fill",
                label: gameState.isPaused ? "Play" : "Pause",
                action: onPauseTapped
            )
            HUDButton(
                systemImage: "forward.fill",
                label: gameState.speed.displayLabel,
                isDisabled: gameState.isPaused,
                action: onSpeedTapped
            )
        }
    }

    var refillButton: some View {
        Button(action: onRefillTapped) {
            VStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 16))
                if gameState.hasFacilitiesToRefill {
                    Text(Currency.formatCurrency(gameState.totalRefillCost))
                        .font(.system(size: 9))
                        .foregroundStyle(gameState.canAffordRefill ? .green : .red)
                } else {
                    Text("Refill")
                        .font(.system(size: 9))
                }
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(!gameState.isRefillEnabled)
        .opacity(gameState.isRefillEnabled ? 1.0 : 0.4)
    }
}

// MARK: - Preview

private struct StatusToolbarPreview: View {
    @State private var editMode = false
    @State private var treatMode = false
    @State private var treatType: TreatType = .freshVeggies
    private let state: GameState = {
        let previewState = GameState()
        previewState.farm = FarmGrid.createStarter()
        return previewState
    }()

    var body: some View {
        StatusToolbar(
            gameState: state,
            isEditMode: $editMode,
            isTreatMode: $treatMode,
            selectedTreatType: $treatType,
            onShopTapped: {},
            onPigListTapped: {},
            onBreedingTapped: {},
            onAlmanacTapped: {},
            onShowroomTapped: {},
            onAtlasTapped: {},
            onRefillTapped: {},
            onPigShowTapped: nil,
            onEditTapped: { editMode.toggle() },
            onPauseTapped: {},
            onSpeedTapped: {}
        )
        .background(.black)
    }
}

#Preview {
    StatusToolbarPreview()
}
