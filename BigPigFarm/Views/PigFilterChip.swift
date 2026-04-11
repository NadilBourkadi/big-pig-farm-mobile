/// PigFilterChip — Capsule-shaped toggle chip for pig list filtering.
import SwiftUI

struct PigFilterChip: View {
    let label: String
    let isActive: Bool
    var activeColor: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isActive ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isActive ? activeColor : Color(.secondarySystemFill), in: Capsule())
                .foregroundStyle(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
