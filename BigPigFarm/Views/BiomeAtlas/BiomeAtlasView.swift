/// BiomeAtlasView — Biome mastery overview showing all 8 biomes with progress and rewards.
import SwiftUI

struct BiomeAtlasView: View {
    let prestigeState: PrestigeState
    @Environment(\.dismiss) private var dismiss

    private var mastery: BiomeMastery { prestigeState.biomeMastery }
    private var masteredCount: Int { mastery.masteredBiomes.count }

    var body: some View {
        NavigationStack {
            List {
                summaryHeader
                ForEach(BiomeType.allCases, id: \.self) { biome in
                    BiomeAtlasCard(biome: biome, mastery: mastery)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Biome Atlas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sub-views

private extension BiomeAtlasView {
    var summaryHeader: some View {
        Section {
            HStack {
                Image(systemName: "map.fill")
                    .font(.title2)
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(masteredCount)/\(BiomeType.allCases.count) biomes mastered")
                        .font(.title3.bold())
                    Text("Breed \(GameConfig.Prestige.biomeMasteryThreshold) pigs in a biome to master it")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Preview

#Preview {
    BiomeAtlasView(prestigeState: PrestigeState())
}
