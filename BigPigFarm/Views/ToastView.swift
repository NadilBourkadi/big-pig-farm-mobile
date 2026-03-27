/// ToastView — Single toast notification component.
///
/// Compact horizontal layout: category icon + message text on a tinted
/// material background. Tap or swipe down to dismiss.
import SwiftUI

// MARK: - ToastView

struct ToastView: View {
    let toast: ToastItem
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.category.iconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(toast.category.color)

            Text(toast.message)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.12, green: 0.08, blue: 0.04).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(toast.category.color.opacity(0.12))
                )
        )
        .onTapGesture { onDismiss() }
        // Swipe down to dismiss (toward the toolbar edge the toast slid in from).
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    if value.translation.height > 10 {
                        onDismiss()
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(toast.category.displayName): \(toast.message)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to dismiss")
    }
}
