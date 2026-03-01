/// BreedingPairTab — Manual pair selection with offspring prediction.
/// Maps from: ui/screens/breeding_screen.py pair selection section.
import SwiftUI

// MARK: - BreedingPairTab

/// Side-by-side male/female pig lists with offspring prediction panel.
struct BreedingPairTab: View {
    let gameState: GameState

    @State private var selectedMaleID: UUID?
    @State private var selectedFemaleID: UUID?

    private var adultMales: [GuineaPig] {
        gameState.getPigsList().filter { $0.gender == .male && $0.isAdult }
    }

    private var adultFemales: [GuineaPig] {
        gameState.getPigsList().filter { $0.gender == .female && $0.isAdult }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                pigColumn(title: "Males", pigs: adultMales, selectedID: $selectedMaleID)
                Divider()
                pigColumn(title: "Females", pigs: adultFemales, selectedID: $selectedFemaleID)
            }
            Divider()
            predictionPanel
                .frame(maxHeight: 220) // ~8 prediction rows at 24pt + header + buttons
        }
    }

    private func pigColumn(
        title: String,
        pigs: [GuineaPig],
        selectedID: Binding<UUID?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            if pigs.isEmpty {
                ContentUnavailableView("No adult \(title.lowercased())", systemImage: "pawprint")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(pigs) { pig in
                            BreedingPigRow(
                                pig: pig,
                                gameState: gameState,
                                isSelected: selectedID.wrappedValue == pig.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedID.wrappedValue =
                                    selectedID.wrappedValue == pig.id ? nil : pig.id
                            }
                            Divider().padding(.leading, 30)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Prediction Panel

extension BreedingPairTab {
    @ViewBuilder
    var predictionPanel: some View {
        if let maleID = selectedMaleID,
           let femaleID = selectedFemaleID,
           let male = gameState.getGuineaPig(maleID),
           let female = gameState.getGuineaPig(femaleID) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Predicted Offspring")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if gameState.breedingProgram.hasTarget {
                        let rawProb = calculateTargetProbability(
                            male.genotype, female.genotype,
                            targetColors: gameState.breedingProgram.targetColors,
                            targetPatterns: gameState.breedingProgram.targetPatterns,
                            targetIntensities: gameState.breedingProgram.targetIntensities,
                            targetRoan: gameState.breedingProgram.targetRoan
                        )
                        let prob = max(0.0, min(1.0, rawProb))
                        Text("Target: \(Int(prob * 100))%")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                let predictions = predictOffspringPhenotypes(male.genotype, female.genotype)
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(Array(predictions.prefix(8)), id: \.0) { item in
                            let (phenotype, probability) = item
                            let isNew = !gameState.pigdex.isDiscovered(phenotypeKey(phenotype))
                            PredictionRow(phenotype: phenotype, probability: probability, isNew: isNew)
                        }
                    }
                }
                HStack {
                    Button("Set Pair") { setPair(male: male, female: female) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSetPair(male: male, female: female))
                    if gameState.breedingPair != nil {
                        Button("Clear Pair", role: .destructive) { gameState.clearBreedingPair() }
                            .buttonStyle(.bordered)
                    }
                }
            }
            .padding(10)
        } else {
            VStack {
                Text("Select a male and female to preview offspring")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if gameState.breedingPair != nil {
                    Button("Clear Pair", role: .destructive) { gameState.clearBreedingPair() }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
    }

    private func canSetPair(male: GuineaPig, female: GuineaPig) -> Bool {
        male.canBreed && female.canBreed
            && !male.breedingLocked && !female.breedingLocked
            && !female.isPregnant
    }

    private func setPair(male: GuineaPig, female: GuineaPig) {
        guard canSetPair(male: male, female: female) else { return }
        gameState.setBreedingPair(maleID: male.id, femaleID: female.id)
    }
}

// MARK: - BreedingPigRow

/// A single pig row in the pair selection lists.
/// Maps from: breeding_screen.py PigListItem
struct BreedingPigRow: View {
    let pig: GuineaPig
    let gameState: GameState
    let isSelected: Bool

    private var isPaired: Bool {
        guard let pair = gameState.breedingPair else { return false }
        return pig.id == pair.maleId || pig.id == pair.femaleId
    }

    private var isAutoPaired: Bool {
        isPaired && gameState.breedingProgram.shouldAutoPair()
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(pigColorSwiftUI(pig.phenotype.baseColor))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(pig.name).font(.body)
                Text(pig.phenotype.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusBadge
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isAutoPaired {
            pill("AUTO", color: .blue)
        } else if isPaired {
            pill("PAIRED", color: .blue)
        } else if pig.breedingLocked {
            Text("LOCKED").font(.caption2).foregroundStyle(.red)
        } else if pig.isPregnant {
            Text("Pregnant").font(.caption2).foregroundStyle(.orange)
        } else if !pig.canBreed {
            Text("Can't breed").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func pill(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - PredictionRow

/// A single offspring prediction entry with probability bar.
/// Maps from: breeding_screen.py _update_predictions()
struct PredictionRow: View {
    let phenotype: Phenotype
    let probability: Double
    let isNew: Bool

    var body: some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.2))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue)
                            .frame(width: geo.size.width * probability)
                    }
            }
            .frame(width: 80, height: 12)
            Text(String(format: "%.1f%%", probability * 100))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 38, alignment: .trailing)
            Text(phenotype.displayName)
                .font(.caption)
                .lineLimit(1)
            if isNew {
                Text("NEW")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Spacer(minLength: 0)
        }
    }
}
