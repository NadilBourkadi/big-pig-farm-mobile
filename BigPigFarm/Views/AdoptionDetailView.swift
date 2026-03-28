/// AdoptionDetailView — Detail sheet for a pig available for adoption.
/// Reuses shared components (SectionHeader, InfoRow, PigPortraitView, etc.)
/// for visual consistency with PigDetailView.
import SwiftUI

/// Presents an adoption candidate's details with a portrait, structured info,
/// and an Adopt button footer. Receives display-ready values — no direct
/// GameState dependency.
struct AdoptionDetailView: View {
    let pig: GuineaPig
    let cost: Int
    let canAfford: Bool
    let isFree: Bool
    let pigCount: Int
    let capacity: Int
    let isAtCapacity: Bool
    let onAdopt: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                portraitSection
                detailsSection
                personalitySection
                adoptSection
            }
            .padding()
        }
    }
}

// MARK: - Header + Portrait

private extension AdoptionDetailView {
    var headerSection: some View {
        HStack {
            Text(pig.name)
                .font(.title2.bold())
            Text(pig.gender.displaySymbol)
                .font(.title2)
                .foregroundStyle(pig.gender.displayColor)
            if isFree {
                StatusBadge(label: "Free", color: .green)
            }
            Spacer()
            RarityBadge(rarity: pig.phenotype.rarity)
        }
    }

    var portraitSection: some View {
        HStack {
            Spacer()
            PigPortraitView(
                baseColor: pig.phenotype.baseColor,
                pattern: pig.phenotype.pattern,
                intensity: pig.phenotype.intensity,
                roan: pig.phenotype.roan,
                pigID: pig.id
            )
            .frame(width: 120, height: 120)
            .accessibilityLabel("\(pig.phenotype.displayName) guinea pig portrait")
            Spacer()
        }
    }
}

// MARK: - Details

private extension AdoptionDetailView {
    var detailsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Details")
            InfoRow(label: "Gender", value: pig.gender.displayLabel)
            InfoRow(label: "Phenotype", value: pig.phenotype.displayName)
            if let tag = pig.originTag {
                InfoRow(label: "Bloodline", value: tag)
            }
            InfoRow(label: "Cost", value: isFree ? "Free" : Currency.formatCurrency(cost))
            InfoRow(label: "Farm", value: "\(pigCount)/\(capacity) pigs")
        }
    }
}

// MARK: - Personality

private extension AdoptionDetailView {
    var personalitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Personality")
            let traits = pig.personality.map { $0.rawValue.capitalized }.joined(separator: ", ")
            Text(traits.isEmpty ? "None" : traits)
                .font(.body)
                .foregroundStyle(traits.isEmpty ? .secondary : .primary)
        }
    }
}

// MARK: - Adopt Button

private extension AdoptionDetailView {
    var adoptSection: some View {
        VStack(spacing: 8) {
            if isAtCapacity {
                Text("Farm is at capacity — upgrade or sell pigs first.")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !canAfford {
                Text("Not enough Squeaks!")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                onAdopt()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .accessibilityHidden(true)
                    Text("Adopt \(pig.name)")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAfford || isAtCapacity)
        }
        .padding(.top, 8)
    }
}
