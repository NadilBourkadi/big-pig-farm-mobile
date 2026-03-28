/// BreedingView — Breeding pair selection and offspring preview.
/// Maps from: ui/screens/breeding_screen.py + ui/widgets/breeding_program_panel.py
import SwiftUI

// MARK: - BreedingTab

/// Tab selection for the breeding screen.
enum BreedingTab: String, CaseIterable, Sendable {
    case program = "Program"
    case pair = "Pair"
}

// MARK: - BreedingView

/// Two-tab breeding screen: Program (goal-oriented autopilot) and Pair (manual selection).
struct BreedingView: View {
    let gameState: GameState

    @State private var selectedTab: BreedingTab = .program
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case .program: ProgramTab(gameState: gameState)
                case .pair: BreedingPairTab(gameState: gameState)
                }
            }
            .navigationTitle("Breeding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Breeding section", selection: $selectedTab) {
                        ForEach(BreedingTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    breedingStatusBanner
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Status Banner

extension BreedingView {
    /// Status banner showing the active pair or program state.
    /// Maps from: breeding_screen.py _update_status()
    @ViewBuilder
    private var breedingStatusBanner: some View {
        if let pair = gameState.breedingPair,
           let male = gameState.getGuineaPig(pair.maleId),
           let female = gameState.getGuineaPig(pair.femaleId) {
            Text("\(male.name) × \(female.name)")
                .font(.caption)
                .foregroundStyle(.blue)
        } else if gameState.breedingProgram.enabled {
            Text("Program ON")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }
}

// MARK: - ProgramTab

/// Breeding program configuration: target traits, strategy, and autopilot settings.
/// Maps from: ui/widgets/breeding_program_panel.py
private struct ProgramTab: View {
    @Bindable var gameState: GameState

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $gameState.breedingProgram.enabled)
            } header: {
                Text("Breeding Program")
            }
            if gameState.breedingProgram.enabled {
                Section {
                    targetColorToggles
                } header: {
                    Text("Target Colors")
                } footer: {
                    Text("Base fur color, determined by Extension (E), Brown (B), and Dilution (D) genes.")
                }
                Section {
                    targetPatternToggles
                } header: {
                    Text("Target Patterns")
                } footer: {
                    Text("White markings from the Spotting (S) gene. Dutch is partial, Dalmatian is heavy.")
                }
                Section {
                    targetIntensityToggles
                } header: {
                    Text("Target Intensities")
                } footer: {
                    Text("Color depth from the Intensity (C) gene. Chinchilla fades; Himalayan shows on points.")
                }
                Section {
                    targetRoanToggles
                } header: {
                    Text("Target Roan")
                } footer: {
                    Text("White hair intermixing from the Roan (R) gene. Rare and increases pig value.")
                }
                if gameState.prestigeState.hasUpgrade(.selectiveAdvantage) {
                    AllelePreferencesPanel(gameState: gameState)
                }
                Section("Settings") { settingsRows }
            }
        }
    }
}

extension ProgramTab {
    private var settingsRows: some View {
        Group {
            Toggle("Auto-Pair", isOn: $gameState.breedingProgram.autoPair)
            keepCarriersRow
            Picker("Strategy", selection: $gameState.breedingProgram.strategy) {
                ForEach(BreedingStrategy.allCases, id: \.self) { strategy in
                    Text(strategy.rawValue.capitalized).tag(strategy)
                }
            }
            stockLimitRow
        }
    }

    private var keepCarriersRow: some View {
        let hasLab = !gameState.getFacilitiesByType(.geneticsLab).isEmpty
        return VStack(alignment: .leading, spacing: 2) {
            Toggle("Keep Carriers", isOn: $gameState.breedingProgram.keepCarriers)
            if !hasLab {
                Text("Requires Genetics Lab")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var stockLimitRow: some View {
        let clamped = Binding(
            get: { min(gameState.breedingProgram.stockLimit, gameState.capacity) },
            set: { gameState.breedingProgram.stockLimit = $0 }
        )
        return VStack(alignment: .leading, spacing: 2) {
            Stepper(
                "Stock Limit: \(clamped.wrappedValue)",
                value: clamped,
                in: 2...gameState.capacity
            )
            Text("Non-target pigs beyond this limit are auto-sold.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var targetColorToggles: some View {
        ForEach(BaseColor.allCases, id: \.self) { color in
            Toggle(isOn: Binding(
                get: { gameState.breedingProgram.targetColors.contains(color) },
                set: { on in
                    if on {
                        gameState.breedingProgram.targetColors.insert(color)
                    } else {
                        gameState.breedingProgram.targetColors.remove(color)
                    }
                }
            )) {
                Label {
                    Text(color.rawValue.capitalized)
                } icon: {
                    Circle()
                        .fill(pigColorSwiftUI(color))
                        .frame(width: 12, height: 12)
                }
            }
        }
    }

    private var targetPatternToggles: some View {
        ForEach(Pattern.allCases, id: \.self) { pattern in
            Toggle(pattern.rawValue.capitalized, isOn: Binding(
                get: { gameState.breedingProgram.targetPatterns.contains(pattern) },
                set: { on in
                    if on {
                        gameState.breedingProgram.targetPatterns.insert(pattern)
                    } else {
                        gameState.breedingProgram.targetPatterns.remove(pattern)
                    }
                }
            ))
        }
    }

    private var targetIntensityToggles: some View {
        ForEach(ColorIntensity.allCases, id: \.self) { intensity in
            Toggle(intensity.rawValue.capitalized, isOn: Binding(
                get: { gameState.breedingProgram.targetIntensities.contains(intensity) },
                set: { on in
                    if on {
                        gameState.breedingProgram.targetIntensities.insert(intensity)
                    } else {
                        gameState.breedingProgram.targetIntensities.remove(intensity)
                    }
                }
            ))
        }
    }

    private var targetRoanToggles: some View {
        ForEach(RoanType.allCases, id: \.self) { roan in
            Toggle(
                roan == .none ? "None" : roan.rawValue.capitalized,
                isOn: Binding(
                    get: { gameState.breedingProgram.targetRoan.contains(roan) },
                    set: { on in
                        if on {
                            gameState.breedingProgram.targetRoan.insert(roan)
                        } else {
                            gameState.breedingProgram.targetRoan.remove(roan)
                        }
                    }
                )
            )
        }
    }
}

// MARK: - Preview

private struct BreedingViewPreview: View {
    @State private var state = GameState()

    var body: some View {
        BreedingView(gameState: state)
    }
}

#Preview {
    BreedingViewPreview()
}
