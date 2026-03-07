/// EditModeActionPanel — Action strip overlay displayed above the toolbar in edit mode.
/// Provides Move, Remove, and Auto-Arrange controls for the selected facility.
import SwiftUI

// MARK: - EditModeActionPanel

/// Bottom-of-screen overlay that appears while edit mode is active.
///
/// Move and Remove are disabled when no facility is selected or when a move is
/// already in progress. Auto-Arrange is disabled only during an active move.
struct EditModeActionPanel: View {

    /// The facility currently selected in the scene, or nil if none.
    var selectedFacilityID: UUID?

    /// True while the user is dragging a facility to a new position.
    var isMovingFacility: Bool

    var onMove: () -> Void
    var onRemove: () -> Void
    var onAutoArrange: () -> Void

    private var hasSelection: Bool { selectedFacilityID != nil }

    var body: some View {
        HStack(spacing: 24) {
            Spacer()
            panelButton(
                systemImage: "arrow.up.and.down.and.arrow.left.and.right",
                label: isMovingFacility ? "Moving…" : "Move",
                isDisabled: !hasSelection || isMovingFacility,
                action: onMove
            )
            panelButton(
                systemImage: "trash",
                label: "Remove",
                isDisabled: !hasSelection || isMovingFacility,
                action: onRemove
            )
            panelButton(
                systemImage: "square.grid.2x2",
                label: "Auto-Arrange",
                isDisabled: isMovingFacility,
                action: onAutoArrange
            )
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Sub-views

private extension EditModeActionPanel {
    func panelButton(
        systemImage: String,
        label: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 9))
            }
            .foregroundStyle(.white)
            .opacity(isDisabled ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(label)
    }
}

// MARK: - Preview

#Preview("No selection") {
    VStack {
        Spacer()
        EditModeActionPanel(
            selectedFacilityID: nil,
            isMovingFacility: false,
            onMove: {},
            onRemove: {},
            onAutoArrange: {}
        )
    }
    .background(.black)
}

#Preview("Facility selected") {
    VStack {
        Spacer()
        EditModeActionPanel(
            selectedFacilityID: UUID(),
            isMovingFacility: false,
            onMove: {},
            onRemove: {},
            onAutoArrange: {}
        )
    }
    .background(.black)
}

#Preview("Moving in progress") {
    VStack {
        Spacer()
        EditModeActionPanel(
            selectedFacilityID: UUID(),
            isMovingFacility: true,
            onMove: {},
            onRemove: {},
            onAutoArrange: {}
        )
    }
    .background(.black)
}
