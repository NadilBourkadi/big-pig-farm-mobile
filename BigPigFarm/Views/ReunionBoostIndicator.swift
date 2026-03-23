/// ReunionBoostIndicator — Shows active reunion boost with remaining time countdown.
import SwiftUI

struct ReunionBoostIndicator: View {
    let boost: ReunionBoost?

    var body: some View {
        if let boost, boost.isActive() {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 12))
                    Text(remainingText(boost))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .accessibilityLabel("Reunion boost active")
            }
        }
    }

    private func remainingText(_ boost: ReunionBoost) -> String {
        let remaining = boost.timeRemainingSeconds()
        guard remaining > 0 else { return "Boost" }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        if minutes > 0 {
            return "Boost \(minutes)m"
        }
        return "Boost \(seconds)s"
    }
}
