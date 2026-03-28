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
            menuRow
                .padding(.top, 10)
                .padding(.bottom, 4)

            Divider()
                .opacity(0.3)

            actionRow
                .padding(.top, 4)
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 12)
        .background(Color(red: 0.08, green: 0.05, blue: 0.02).opacity(0.92))
    }
}

// MARK: - Sub-views

private extension StatusToolbar {

    // MARK: Row 1 — Menu buttons (open sheets/screens)

    var menuRow: some View {
        HStack(spacing: 4) {
            HUDButton(systemImage: "cart.fill", label: "Shop", fillWidth: true, action: onShopTapped)
            HUDButton(systemImage: "list.bullet", label: "Pigs", fillWidth: true, action: onPigListTapped)
            HUDButton(systemImage: "heart.fill", label: "Breed", fillWidth: true, action: onBreedingTapped)
            HUDButton(systemImage: "books.vertical.fill", label: "Almanac", fillWidth: true, action: onAlmanacTapped)
            HUDButton(systemImage: "rosette", label: "Showroom", fillWidth: true, action: onShowroomTapped)
            HUDButton(systemImage: "map.fill", label: "Atlas", fillWidth: true, action: onAtlasTapped)

            if isPigShowEligible, let onPigShowTapped {
                HUDButton(systemImage: "trophy.fill", label: "Show", fillWidth: true, action: onPigShowTapped)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Row 2 — Immediate actions (refill, treats, edit, pause, speed)

    var actionRow: some View {
        GeometryReader { geo in
            let buttonWidth = (geo.size.width - 5 * 4) / 6
            HStack(spacing: 4) {
                refillButton.frame(width: buttonWidth)
                TreatHUDButton(gameState: gameState, isTreatMode: $isTreatMode, selectedTreatType: $selectedTreatType)
                    .frame(width: buttonWidth)
                HUDButton(
                    systemImage: isEditMode ? "pencil.slash" : "pencil",
                    label: "Edit",
                    isActive: isEditMode,
                    fillWidth: true,
                    action: onEditTapped
                )
                .frame(width: buttonWidth)
                HUDButton(
                    systemImage: gameState.isPaused ? "play.fill" : "pause.fill",
                    label: gameState.isPaused ? "Play" : "Pause",
                    fillWidth: true,
                    action: onPauseTapped
                )
                .frame(width: buttonWidth)
                HUDButton(
                    systemImage: "forward.fill",
                    label: gameState.speed.displayLabel,
                    isDisabled: gameState.isPaused,
                    fillWidth: true,
                    action: onSpeedTapped
                )
                .frame(width: buttonWidth)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 42)
    }

    var refillButton: some View {
        Button(action: onRefillTapped) {
            VStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.subheadline)
                    .frame(minHeight: 18)
                if gameState.hasFacilitiesToRefill {
                    Text(Currency.formatCurrency(gameState.totalRefillCost))
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(gameState.canAffordRefill ? .green : .red)
                } else {
                    Text("Refill")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.3, green: 0.22, blue: 0.14).opacity(0.6))
            )
            .foregroundStyle(Color(red: 0.95, green: 0.9, blue: 0.82))
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
    @State private var treatType: TreatType = .leafyGreens
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
