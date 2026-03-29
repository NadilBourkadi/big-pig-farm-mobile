/// PigShowView — Multi-step prestige flow: Judging → Showroom Preview → Confirmation.
/// Presented as a fullScreenCover from ContentView when the player enters the Pig Show.
import SwiftUI

// MARK: - PigShowStep

/// Linear progression through the Pig Show flow.
enum PigShowStep: Sendable, Equatable {
    case judging
    case showroomPreview
    case confirmation
}

// MARK: - PigShowView

struct PigShowView: View {
    let gameState: GameState
    /// Called with the computed breakdown when the player confirms prestige.
    let onPrestigeConfirmed: (RosetteBreakdown) -> Void

    @State private var flowStep: PigShowStep = .judging
    @State private var breakdown: RosetteBreakdown?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let breakdown {
                    flowContent(breakdown)
                } else {
                    ProgressView("Evaluating your herd...")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled()
        .task { computeBreakdown() }
    }

    // MARK: - Flow Content

    @MainActor
    @ViewBuilder
    private func flowContent(_ breakdown: RosetteBreakdown) -> some View {
        Group {
            switch flowStep {
            case .judging:
                JudgingScreenView(
                    gameState: gameState,
                    breakdown: breakdown,
                    onContinue: { flowStep = .showroomPreview }
                )

            case .showroomPreview:
                ShowroomPreviewView(
                    prestigeState: gameState.prestigeState,
                    pendingRosettes: breakdown.total,
                    onContinue: { flowStep = .confirmation }
                )

            case .confirmation:
                NewPasturesConfirmation(
                    rosetteTotal: breakdown.total,
                    farmNumber: gameState.prestigeState.farmCount + 1,
                    onConfirm: { onPrestigeConfirmed(breakdown) },
                    onCancel: { dismiss() }
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: flowStep)
    }

    // MARK: - Computation

    @MainActor
    private func computeBreakdown() {
        breakdown = PigShowCalculator.evaluate(
            gameState: gameState,
            prestigeState: gameState.prestigeState
        )
    }
}
