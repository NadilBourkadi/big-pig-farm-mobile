/// StatusBarView — HUD overlay showing currency, population, and controls.
/// Maps from: ui/screens/status_bar.py
import SwiftUI

// MARK: - StatusBarView

/// Persistent HUD overlay displayed above the farm scene.
///
/// Shows game state at a glance and provides toolbar buttons to open menu screens.
/// All mutations are delegated back to the caller via action closures.
struct StatusBarView: View {
    let gameState: GameState

    /// Two-way binding to ContentView's edit-mode state.
    @Binding var isEditMode: Bool

    // MARK: - Action Callbacks

    var onShopTapped: () -> Void
    var onPigListTapped: () -> Void
    var onBreedingTapped: () -> Void
    var onAlmanacTapped: () -> Void
    var onEditTapped: () -> Void
    var onPauseTapped: () -> Void
    var onSpeedTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            infoRow
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 2)
            Divider().opacity(0.3)
            buttonRow
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Computed Properties

private extension StatusBarView {
    /// Average fill percentage (0–100) across all food-type facilities.
    var foodLevel: Int {
        let facilities = gameState.getFacilitiesByType(.foodBowl)
            + gameState.getFacilitiesByType(.hayRack)
        guard !facilities.isEmpty else { return 0 }
        let average = facilities.reduce(0.0) { $0 + $1.fillPercentage }
            / Double(facilities.count)
        return Int(average.rounded())
    }

    /// Average fill percentage (0–100) across all water facilities.
    var waterLevel: Int {
        let facilities = gameState.getFacilitiesByType(.waterBottle)
        guard !facilities.isEmpty else { return 0 }
        let average = facilities.reduce(0.0) { $0 + $1.fillPercentage }
            / Double(facilities.count)
        return Int(average.rounded())
    }

    /// True when breeding is enabled and adult pig count is at or below the minimum threshold.
    var showLowPopulationWarning: Bool {
        guard gameState.breedingProgram.enabled else { return false }
        let adultCount = gameState.getPigsList().filter { !$0.isBaby }.count
        return adultCount <= GameConfig.Breeding.minBreedingPopulation
    }
}

// MARK: - Info Row

private extension StatusBarView {
    var infoRow: some View {
        HStack(spacing: 10) {
            Text("Day \(gameState.gameTime.day)")
                .font(.caption.bold())
            Text("T\(gameState.farmTier)")
                .font(.caption)
                .foregroundStyle(.secondary)
            CurrencyLabel(amount: gameState.money)
            Text("\(gameState.pigCount)/\(gameState.capacity)")
                .font(.caption)

            if showLowPopulationWarning {
                Text("LOW POP")
                    .font(.caption2.bold())
                    .foregroundStyle(.red)
            }

            Spacer()

            resourceIndicator(systemImage: "fork.knife", level: foodLevel)
            resourceIndicator(systemImage: "drop.fill", level: waterLevel)
            speedIndicator
        }
    }

    @ViewBuilder
    var speedIndicator: some View {
        if gameState.isPaused {
            Image(systemName: "pause.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
        } else {
            Text(gameState.speed.displayLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    func resourceIndicator(systemImage: String, level: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: 10))
            Text("\(level)%")
                .font(.caption2)
        }
        .foregroundStyle(level < 30 ? .red : .primary)
    }
}

// MARK: - Button Row

private extension StatusBarView {
    var buttonRow: some View {
        HStack(spacing: 16) {
            toolbarButton(systemImage: "cart.fill", label: "Shop", action: onShopTapped)
            toolbarButton(systemImage: "list.bullet", label: "Pigs", action: onPigListTapped)
            toolbarButton(systemImage: "heart.fill", label: "Breed", action: onBreedingTapped)
            toolbarButton(systemImage: "book.fill", label: "Almanac", action: onAlmanacTapped)

            Spacer()

            toolbarButton(
                systemImage: isEditMode ? "pencil.slash" : "pencil",
                label: "Edit",
                action: onEditTapped,
                isActive: isEditMode
            )
            toolbarButton(
                systemImage: gameState.isPaused ? "play.fill" : "pause.fill",
                label: gameState.isPaused ? "Play" : "Pause",
                action: onPauseTapped
            )
            toolbarButton(
                systemImage: "forward.fill",
                label: "Speed",
                action: onSpeedTapped
            )
        }
    }

    func toolbarButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void,
        isActive: Bool = false
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 9))
            }
            .foregroundStyle(isActive ? .yellow : .white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

private struct StatusBarPreview: View {
    @State private var editMode = false
    private let state: GameState = {
        let previewState = GameState()
        previewState.farm = FarmGrid.createStarter()
        previewState.money = 1_250
        previewState.speed = .fast
        return previewState
    }()

    var body: some View {
        StatusBarView(
            gameState: state,
            isEditMode: $editMode,
            onShopTapped: {},
            onPigListTapped: {},
            onBreedingTapped: {},
            onAlmanacTapped: {},
            onEditTapped: { editMode.toggle() },
            onPauseTapped: {},
            onSpeedTapped: {}
        )
        .background(.black)
    }
}

#Preview {
    StatusBarPreview()
}
