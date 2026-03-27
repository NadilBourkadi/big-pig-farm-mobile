// PigDetailSheet — Shared sheet presentation modifier for PigDetailView.
// Ensures consistent half-sheet styling across scene tap and list tap contexts.
import SwiftUI

extension View {
    /// Presents a PigDetailView half-sheet with standardized styling.
    ///
    /// Configures: half-sheet detents (.fraction(0.45) + .large), drag indicator,
    /// ultra-thin material background, background interaction, scroll content
    /// interaction, and toolbar with Done + optional Follow buttons.
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
            NavigationStack {
                PigDetailView(gameState: gameState, pig: selectedPig)
                    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { pig.wrappedValue = nil }
                        }
                        ToolbarItem(placement: .topBarLeading) {
                            if let onFollow {
                                Button("Follow") {
                                    onFollow(selectedPig.id)
                                }
                            }
                        }
                    }
            }
            .background(.clear)
            .presentationDetents([.fraction(0.45), .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.45)))
            .presentationContentInteraction(.scrolls)
            .presentationBackground(.ultraThinMaterial)
        }
    }
}
