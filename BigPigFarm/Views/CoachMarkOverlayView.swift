/// CoachMarkOverlayView — Positioned above the toolbar, below toasts.
///
/// Only one coach mark shows at a time. When dismissed, the next one in
/// priority order becomes eligible on the next evaluation.
///
/// Maps from: N/A (new for mobile)
import SwiftUI

// MARK: - CoachMarkOverlayView

@MainActor
struct CoachMarkOverlayView: View {
    let gameState: GameState
    @Binding var coachState: CoachMarkState

    var body: some View {
        if let markID = CoachMarkTrigger.evaluate(state: gameState, coachState: coachState) {
            CoachMarkBubble(
                icon: CoachMarkTrigger.icon(for: markID),
                message: CoachMarkTrigger.message(for: markID),
                onDismiss: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        coachState.markShown(markID)
                        coachState.save()
                    }
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(duration: 0.35, bounce: 0.2), value: markID)
        }
    }
}
