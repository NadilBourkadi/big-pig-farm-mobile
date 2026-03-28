// PigListRow — Row component for the pig list.
import SwiftUI

/// A single row in the pig list displaying key stats at a glance.
struct PigListRow: View {
    let pig: GuineaPig

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(pigColorSwiftUI(pig.phenotype.baseColor))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pig.name)
                        .font(.body.bold())
                    RarityBadge(rarity: pig.phenotype.rarity)
                    if pig.breedingLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                HStack(spacing: 8) {
                    Text(pig.phenotype.baseColor.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(pig.ageDays))d")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(pig.gender.displaySymbol)
                        .font(.caption)
                        .foregroundStyle(pig.gender.displayColor)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                NeedBar(value: pig.needs.happiness / 100.0, label: "")
                    .frame(width: 64)
                BreedingStatusLabel(pig: pig)
            }
        }
        .padding(.vertical, 2)
    }
}
