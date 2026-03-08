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

    // MARK: - Action Callbacks

    var onShopTapped: () -> Void
    var onPigListTapped: () -> Void
    var onBreedingTapped: () -> Void
    var onAlmanacTapped: () -> Void
    var onRefillTapped: () -> Void
    var onEditTapped: () -> Void
    var onPauseTapped: () -> Void
    var onSpeedTapped: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            toolbarButton(systemImage: "cart.fill", label: "Shop", action: onShopTapped)
            toolbarButton(systemImage: "list.bullet", label: "Pigs", action: onPigListTapped)
            toolbarButton(systemImage: "heart.fill", label: "Breed", action: onBreedingTapped)
            toolbarButton(systemImage: "book.fill", label: "Almanac", action: onAlmanacTapped)

            toolbarButton(systemImage: "drop.fill", label: "Refill", action: onRefillTapped)
                .disabled(!gameState.isRefillEnabled)
                .opacity(gameState.isRefillEnabled ? 1.0 : 0.4)

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
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Sub-views

private extension StatusToolbar {
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

private struct StatusToolbarPreview: View {
    @State private var editMode = false
    private let state: GameState = {
        let previewState = GameState()
        previewState.farm = FarmGrid.createStarter()
        return previewState
    }()

    var body: some View {
        StatusToolbar(
            gameState: state,
            isEditMode: $editMode,
            onShopTapped: {},
            onPigListTapped: {},
            onBreedingTapped: {},
            onAlmanacTapped: {},
            onRefillTapped: {},
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
