/// EditModeActionPanel — Action strip overlay displayed above the toolbar in edit mode.
/// Provides Remove and Auto-Arrange controls. Facilities are moved by direct drag.
import SwiftUI

// MARK: - EditModeActionPanel

/// Bottom-of-screen overlay that appears while edit mode is active.
///
/// Remove is disabled when no facility is selected or when a drag is in progress.
/// Auto-Arrange is disabled only during an active drag.
struct EditModeActionPanel: View {

    /// The facility currently selected in the scene, or nil if none.
    var selectedFacilityID: UUID?

    /// True while the user is actively dragging a facility to a new position.
    var isDragging: Bool

    var onRemove: () -> Void
    var onAutoArrange: () -> Void

    private var hasSelection: Bool { selectedFacilityID != nil }

    var body: some View {
        HStack(spacing: 24) {
            Spacer()
            HUDButton(
                systemImage: "trash",
                label: "Remove",
                isDisabled: !hasSelection || isDragging,
                action: onRemove
            )
            HUDButton(
                systemImage: "square.grid.2x2",
                label: "Auto-Arrange",
                isDisabled: isDragging,
                action: onAutoArrange
            )
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Preview

#Preview("No selection") {
    VStack {
        Spacer()
        EditModeActionPanel(
            selectedFacilityID: nil,
            isDragging: false,
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
            isDragging: false,
            onRemove: {},
            onAutoArrange: {}
        )
    }
    .background(.black)
}

#Preview("Drag in progress") {
    VStack {
        Spacer()
        EditModeActionPanel(
            selectedFacilityID: UUID(),
            isDragging: true,
            onRemove: {},
            onAutoArrange: {}
        )
    }
    .background(.black)
}
