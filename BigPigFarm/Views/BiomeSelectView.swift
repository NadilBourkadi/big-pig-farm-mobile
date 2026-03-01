/// BiomeSelectView — Modal biome picker for new areas.
/// Maps from: ui/screens/biome_select_screen.py
/// Full implementation tracked in bead big-pig-farm-mobile-9nq.
import SwiftUI

/// Modal view for selecting a biome type when creating a new farm area.
struct BiomeSelectView: View {
    let farmTier: Int
    let onBiomeSelected: (BiomeType?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Biome Select — coming soon")
                .foregroundStyle(.secondary)
                .navigationTitle("Choose Biome")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") {
                            onBiomeSelected(nil)
                            dismiss()
                        }
                    }
                }
        }
    }
}
