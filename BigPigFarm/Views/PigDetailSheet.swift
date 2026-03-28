// PigDetailSheet — Shared sheet presentation modifier for PigDetailView.
// Ensures consistent half-sheet styling across scene tap and list tap contexts.
import SwiftUI

// MARK: - PigDetailSheetContent

/// Inner view wrapping PigDetailView that owns sell-confirmation state.
/// Extracted from the View extension because @State requires a View struct.
private struct PigDetailSheetContent: View {
    let gameState: GameState
    let pig: GuineaPig
    let onFollow: ((UUID) -> Void)?
    let onDismiss: () -> Void

    @State private var showSellConfirmation = false

    var body: some View {
        NavigationStack {
            PigDetailView(gameState: gameState, pig: pig)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { onDismiss() }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(spacing: 12) {
                            if let onFollow {
                                Button("Follow") { onFollow(pig.id) }
                            }
                            Button("Sell", systemImage: "dollarsign.circle") {
                                showSellConfirmation = true
                            }
                            .tint(.red)
                        }
                    }
                }
                .confirmationDialog(
                    sellConfirmationTitle,
                    isPresented: $showSellConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Sell", role: .destructive) { sellAndDismiss() }
                    Button("Cancel", role: .cancel) {}
                }
        }
    }

    private var sellConfirmationTitle: String {
        let value = Market.calculatePigValue(pig: pig, state: gameState)
        return "Sell \(pig.name) for \(Currency.formatCurrency(value))?"
    }

    private func sellAndDismiss() {
        let result = Market.sellPig(state: gameState, pig: pig)
        HapticManager.pigSold()
        if result.contractBonus > 0 {
            HapticManager.contractCompleted()
        }
        onDismiss()
    }
}

// MARK: - View Extension

extension View {
    /// Presents a PigDetailView half-sheet with standardized styling.
    ///
    /// Configures: half-sheet detents (.fraction(0.45) + .large), drag indicator,
    /// ultra-thin material background, background interaction, scroll content
    /// interaction, and toolbar with Done, optional Follow, and Sell buttons.
    ///
    /// `PigDetailView` sets its own `.navigationTitle` and
    /// `.navigationBarTitleDisplayMode(.inline)` — callers need not set them.
    ///
    /// - Parameters:
    ///   - pig: Binding to the selected pig (nil dismisses the sheet).
    ///   - gameState: The shared game state for PigDetailView.
    ///   - onFollow: Optional closure called when the Follow button is tapped.
    ///     When nil, the Follow button is hidden (e.g. PigListView context).
    func pigDetailSheet(
        pig: Binding<GuineaPig?>,
        gameState: GameState,
        onFollow: ((UUID) -> Void)? = nil
    ) -> some View {
        self.sheet(item: pig) { selectedPig in
            PigDetailSheetContent(
                gameState: gameState,
                pig: selectedPig,
                onFollow: onFollow,
                onDismiss: { pig.wrappedValue = nil }
            )
            .background(.clear)
            .presentationDetents([.fraction(0.45), .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.45)))
            .presentationContentInteraction(.scrolls)
            .presentationBackground(.ultraThinMaterial)
        }
    }
}
