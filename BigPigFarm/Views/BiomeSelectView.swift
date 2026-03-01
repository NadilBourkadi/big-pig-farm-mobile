/// BiomeSelectView — Modal biome picker for new areas.
/// Maps from: ui/screens/biome_select_screen.py
import SwiftUI

/// Modal view for selecting a biome type when creating a new farm area.
///
/// Presented as a .sheet from the Farm tab. Shows all 8 biomes with
/// tier/prerequisite locking. Selecting a biome calls onBiomeSelected.
///
/// Maps from: ui/screens/biome_select_screen.py BiomeSelectScreen
struct BiomeSelectView: View {
    /// Current farm tier (determines which biomes are available).
    let farmTier: Int
    /// Biomes already built (shown as "Built" and disabled).
    let existingBiomes: Set<BiomeType>
    /// Callback when a biome is selected. Nil means cancelled.
    var onBiomeSelected: (BiomeType?) -> Void

    @State private var highlightedBiome: BiomeType?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ForEach(BiomeType.allCases, id: \.self) { biomeType in
                        let (available, lockReason) = biomeStatus(biomeType)
                        BiomeRow(
                            biomeType: biomeType,
                            info: biomes[biomeType],
                            available: available,
                            lockReason: lockReason
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if available {
                                onBiomeSelected(biomeType)
                                dismiss()
                            } else {
                                highlightedBiome = biomeType
                            }
                        }
                        .listRowBackground(
                            highlightedBiome == biomeType ? Color.accentColor.opacity(0.12) : Color.clear
                        )
                        .opacity(available ? 1.0 : 0.4)
                    }
                }
                .listStyle(.insetGrouped)

                if let highlighted = highlightedBiome, let info = biomes[highlighted] {
                    let (_, lockReason) = biomeStatus(highlighted)
                    biomeDetailPanel(info: info, biome: highlighted, lockReason: lockReason)
                }
            }
            .navigationTitle("Select Biome")
            .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Biome Status

    /// Determine whether a biome is selectable and why not if locked.
    ///
    /// Maps from: biome_select_screen.py BiomeSelectScreen._biome_status()
    func biomeStatus(_ biome: BiomeType) -> (Bool, String?) {
        guard let info = biomes[biome] else { return (false, "Unknown biome") }

        if existingBiomes.contains(biome) {
            return (false, "Built")
        }

        if info.requiredTier > farmTier {
            return (false, "Requires Tier \(info.requiredTier)")
        }

        // At least one biome of every tier below requiredTier must be built.
        // Players can choose which biome, but all lower tier slots must be filled.
        let coveredTiers = Set(existingBiomes.compactMap { biomes[$0]?.requiredTier })
        for tier in 1..<info.requiredTier where !coveredTiers.contains(tier) {
            return (false, "Build a Tier \(tier) biome first")
        }

        return (true, nil)
    }

    // MARK: - Detail Panel

    @ViewBuilder
    private func biomeDetailPanel(info: BiomeInfo, biome: BiomeType, lockReason: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let color = info.signatureColor {
                    Circle()
                        .fill(pigColorSwiftUI(color))
                        .frame(width: 12, height: 12)
                }
                Text(info.displayName)
                    .font(.headline)
                Spacer()
                if info.cost > 0 {
                    CurrencyLabel(amount: info.cost)
                        .font(.subheadline.bold())
                } else {
                    Text("Free")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }
            }
            Text(info.description)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Label(
                    "+\(String(format: "%.1f", info.happinessBonus)) happiness",
                    systemImage: "heart.fill"
                )
                .font(.caption)
                .foregroundStyle(.pink)
                if !info.mutationBoostLoci.isEmpty {
                    Label("Mutation boosts", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
            }
            if let reason = lockReason {
                Label(reason, systemImage: "lock.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.regularMaterial)
    }
}

// MARK: - BiomeRow

private struct BiomeRow: View {
    let biomeType: BiomeType
    let info: BiomeInfo?
    let available: Bool
    let lockReason: String?

    var body: some View {
        HStack(spacing: 12) {
            if let color = info?.signatureColor {
                Circle()
                    .fill(pigColorSwiftUI(color))
                    .frame(width: 16, height: 16)
            } else {
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 16, height: 16)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(info?.displayName ?? biomeType.rawValue.capitalized)
                    .font(.body)
                if let reason = lockReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if let info {
                    Text("Tier \(info.requiredTier)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let info {
                if info.cost > 0 {
                    CurrencyLabel(amount: info.cost)
                        .font(.caption)
                } else {
                    Text("Free")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            if available {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let name = info?.displayName ?? biomeType.rawValue.capitalized
        if let reason = lockReason { return "\(name), locked: \(reason)" }
        let costText = info.map { $0.cost > 0 ? Currency.formatCurrency($0.cost) : "Free" } ?? ""
        return costText.isEmpty ? name : "\(name), \(costText)"
    }
}

// MARK: - Preview

#Preview {
    BiomeSelectView(
        farmTier: 3,
        existingBiomes: [.meadow, .burrow],
        onBiomeSelected: { _ in }
    )
}
