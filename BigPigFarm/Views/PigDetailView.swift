// PigDetailView — Individual pig stats and genetics display.
// Maps from: ui/screens/pig_detail.py
import SwiftUI

/// Shows detailed stats, genetics, and lineage for a single pig.
struct PigDetailView: View {
    let gameState: GameState
    let pig: GuineaPig

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                portraitSection
                basicInfoSection
                needsSection
                personalitySection
                breedingSection
                familySection
                if hasGeneticsLab {
                    geneticsSection
                }
                aiStateSection
            }
            .padding()
        }
        .navigationTitle(pig.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hasGeneticsLab: Bool {
        !gameState.getFacilitiesByType(.geneticsLab).isEmpty
    }
}

// MARK: - Header + Portrait

private extension PigDetailView {
    var headerSection: some View {
        HStack {
            Text(pig.name)
                .font(.title2.bold())
            Text(pig.gender == .male ? "♂" : "♀")
                .font(.title2)
                .foregroundStyle(pig.gender == .male ? .blue : .pink)
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
            Spacer()
        }
    }
}

// MARK: - Basic Info

private extension PigDetailView {
    var basicInfoSection: some View {
        let breakdown = Market.calculatePigValueBreakdown(pig: pig, state: gameState)
        return VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Basic Info")
            infoRow("Age", ageDescription)
            infoRow("Phenotype", pig.phenotype.displayName)
            infoRow("Area", areaName)
            infoRow("Birth Area", birthAreaName)
            if let biome = pig.preferredBiome {
                infoRow("Preferred Biome", biome.capitalized)
            }
            infoRow("Sale Value", "\(Currency.formatCurrency(breakdown.total))")
            if let origin = pig.originTag {
                infoRow("Origin", origin)
            }
        }
    }

    var ageDescription: String {
        let days = Int(pig.ageDays)
        switch pig.ageGroup {
        case .baby: return "\(days)d (Baby)"
        case .adult: return "\(days)d (Adult)"
        case .senior: return "\(days)d (Senior)"
        }
    }

    var areaName: String {
        guard let id = pig.currentAreaId,
              let area = gameState.farm.getAreaByID(id) else { return "Unknown" }
        return area.name
    }

    var birthAreaName: String {
        guard let id = pig.birthAreaId,
              let area = gameState.farm.getAreaByID(id) else { return "Unknown" }
        return area.name
    }
}

// MARK: - Needs

private extension PigDetailView {
    var needsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Needs")
            NeedBar(value: pig.needs.hunger / 100.0, label: "Hunger")
            NeedBar(value: pig.needs.thirst / 100.0, label: "Thirst")
            NeedBar(value: pig.needs.energy / 100.0, label: "Energy")
            NeedBar(value: pig.needs.happiness / 100.0, label: "Happiness")
            NeedBar(value: pig.needs.health / 100.0, label: "Health")
            NeedBar(value: pig.needs.social / 100.0, label: "Social")
            NeedBar(value: (100.0 - pig.needs.boredom) / 100.0, label: "Fun")  // Boredom is inverse of fun
        }
    }
}

// MARK: - Personality

private extension PigDetailView {
    var personalitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Personality")
            let traits = pig.personality.map { $0.rawValue.capitalized }.joined(separator: ", ")
            Text(traits.isEmpty ? "None" : traits)
                .font(.body)
                .foregroundStyle(traits.isEmpty ? .secondary : .primary)
        }
    }
}

// MARK: - Breeding

private extension PigDetailView {
    var breedingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Breeding")
            infoRow("Status", formatBreedingStatus(pig, verbose: true))
            infoRow("Lock", pig.breedingLocked ? "Locked" : "Unlocked")
            if pig.isBaby {
                infoRow("Auto-sell at adulthood", pig.markedForSale ? "Yes" : "No")
            }
        }
    }
}

// MARK: - Family

private extension PigDetailView {
    var familySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Family")
            infoRow("Mother", parentName(id: pig.motherId))
            infoRow("Father", parentName(id: pig.fatherId))
        }
    }

    func parentName(id: UUID?) -> String {
        guard let id else { return "Unknown (adopted/starter)" }
        if let parent = gameState.getGuineaPig(id) { return parent.name }
        return "Unknown (no longer on farm)"
    }
}

// MARK: - Genetics

private extension PigDetailView {
    var geneticsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Genetics (Lab Required)")
            let genotype = pig.genotype
            locusRow("Extension (E)", genotype.eLocus)
            locusRow("Brown (B)", genotype.bLocus)
            locusRow("Spotting (S)", genotype.sLocus)
            locusRow("Intensity (C)", genotype.cLocus)
            locusRow("Roan (R)", genotype.rLocus)
            locusRow("Dilution (D)", genotype.dLocus)
            Divider()
            let summary = carrierSummary(pig.genotype)
            infoRow("Carriers", summary.isEmpty ? "None" : summary)
        }
    }

    func locusRow(_ label: String, _ pair: AllelePair) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text("\(pair.first)/\(pair.second)")
                .font(.caption.monospaced())
        }
    }
}

// MARK: - AI State

private extension PigDetailView {
    var aiStateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Current Activity")
            infoRow("State", pig.behaviorState.rawValue.capitalized)
            if let target = pig.targetPosition {
                infoRow("Target", "(\(target.x), \(target.y))")
            }
            if !pig.path.isEmpty {
                infoRow("Path steps", "\(pig.path.count)")
            }
        }
    }
}

// MARK: - Helpers

private extension PigDetailView {
    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 4)
    }

    func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.caption)
        }
    }
}

// MARK: - Preview

private struct PigDetailPreview: View {
    private let state: GameState = {
        let previewState = GameState()
        previewState.farm = FarmGrid.createStarter()
        return previewState
    }()
    private let pig = GuineaPig.create(name: "Biscuit", gender: .female)

    var body: some View {
        NavigationStack {
            PigDetailView(gameState: state, pig: pig)
        }
    }
}

#Preview {
    PigDetailPreview()
}
