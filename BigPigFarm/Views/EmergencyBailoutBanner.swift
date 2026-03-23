/// EmergencyBailoutBanner -- Farm HUD overlay guiding the player to adopt free pigs.
///
/// Displayed on the main farm view when the player has zero pigs and cannot
/// afford adoption. Tapping opens the shop (adoption tab).
import SwiftUI

struct EmergencyBailoutBanner: View {
    var onAdoptTapped: () -> Void

    var body: some View {
        Button(action: onAdoptTapped) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Farm Empty!")
                        .font(.caption.bold())
                    Text("Tap to adopt free starter pigs")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.orange.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Farm empty. Tap to adopt free starter pigs.")
        .padding(.horizontal, 8)
    }
}
