// PigDetailView — Individual pig stats and genetics display.
// Maps from: ui/screens/pig_detail_screen.py
// TODO(xdz): Implement full PigDetailView content (portrait, needs, genetics, family)
import SwiftUI

/// Shows detailed stats, genetics, and lineage for a single pig.
struct PigDetailView: View {
    let gameState: GameState
    let pig: GuineaPig

    var body: some View {
        Text("\(pig.name) — details coming soon")
    }
}
