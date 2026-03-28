/// CoachMarkBubble — A single coach-mark tooltip with dismiss button.
///
/// Visual style parallels ToastView (dark material, icon + text, rounded rect)
/// but uses yellow tinting to distinguish onboarding hints from game notifications.
///
/// Maps from: N/A (new for mobile)
import SwiftUI

// MARK: - CoachMarkBubble

struct CoachMarkBubble: View {
    let icon: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.yellow)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss hint")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.12, green: 0.08, blue: 0.04).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.yellow.opacity(0.1))
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap X to dismiss this hint")
    }
}
