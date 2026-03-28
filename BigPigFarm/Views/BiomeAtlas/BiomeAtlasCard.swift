/// BiomeAtlasCard — Individual biome card showing mastery progress and rewards.
import SwiftUI

struct BiomeAtlasCard: View {
    let biome: BiomeType
    // swiftlint:disable:next inclusive_language
    let mastery: BiomeMastery

    private var info: BiomeInfo? { biomes[biome] }
    private var pigsBred: Int { mastery.pigsBred(in: biome) }
    private var threshold: Int { GameConfig.Prestige.biomeMasteryThreshold }
    // swiftlint:disable:next inclusive_language
    private var isMastered: Bool { mastery.isMastered(biome) }
    private var progress: Double { mastery.masteryProgress(for: biome) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            progressRow
            if isMastered {
                rewardsRow
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sub-views

private extension BiomeAtlasCard {
    var headerRow: some View {
        HStack(spacing: 10) {
            if let color = info?.signatureColor {
                Circle()
                    .fill(pigColorSwiftUI(color))
                    .frame(width: 20, height: 20)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(info?.displayName ?? biome.rawValue.capitalized)
                        .font(.headline)
                    if isMastered {
                        Text("MASTERED")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green, in: Capsule())
                    }
                }
                Text("Tier \(info?.requiredTier ?? 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(pigsBred)/\(threshold)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(isMastered ? .green : .primary)
        }
    }

    var progressRow: some View {
        ProgressView(value: progress)
            .tint(isMastered ? .green : .accentColor)
    }

    var rewardsRow: some View {
        let discountPct = Int(GameConfig.Prestige.biomeMasteryCostReduction * 100)
        let mutationPct = Int(GameConfig.Prestige.biomeMasteryMutationBoost * 100)
        return HStack(spacing: 16) {
            Label("\(discountPct)% room discount", systemImage: "tag.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            Label("+\(mutationPct)% signature mutation", systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(.purple)
        }
    }
}
