// PigListView — Sortable list of all guinea pigs.
// Maps from: ui/screens/pig_list_screen.py
// TODO(ebb): Implement full PigListView content (sortable list, row selection)
import SwiftUI

/// Displays a filterable, sortable list of all pigs on the farm.
struct PigListView: View {
    let gameState: GameState
    var onFollowPig: (UUID) -> Void = { _ in }

    var body: some View {
        Text("Pig List — coming soon")
            .navigationTitle("Pigs")
    }
}
