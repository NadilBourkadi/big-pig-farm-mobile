/// StreakIndicator — Shows current visit streak day count and expiry countdown.
import SwiftUI

struct StreakIndicator: View {
    let streak: VisitStreak

    var body: some View {
        if streak.currentStreak > 0 {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("Day \(streak.currentStreak)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                if streak.isStreakActive() {
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        Text(countdownText)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .accessibilityLabel("Visit streak: Day \(streak.currentStreak)")
        }
    }

    private var countdownText: String {
        let remaining = streak.timeRemainingSeconds()
        guard remaining > 0 else { return "" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        }
        return "\(minutes)m left"
    }
}
