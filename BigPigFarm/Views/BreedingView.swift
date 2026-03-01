/// BreedingView — Breeding pair selection and offspring preview.
/// Maps from: ui/screens/breeding_screen.py + ui/widgets/breeding_program_panel.py
import SwiftUI

// MARK: - BreedingTab

/// Tab selection for the breeding screen.
enum BreedingTab: String, Sendable {
    case program
    case pair
}

// MARK: - BreedingView

/// Two-tab breeding screen: Program (goal-oriented autopilot) and Pair (manual selection).
struct BreedingView: View {
    let gameState: GameState

    @State private var selectedTab: BreedingTab = .program
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                ProgramTab(gameState: gameState)
                    .tabItem { Label("Program", systemImage: "gearshape.2") }
                    .tag(BreedingTab.program)
                BreedingPairTab(gameState: gameState)
                    .tabItem { Label("Pair", systemImage: "arrow.triangle.2.circlepath") }
                    .tag(BreedingTab.pair)
            }
            .navigationTitle("Breeding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                Section("Target Colors") { targetColorToggles }
                Section("Target Patterns") { targetPatternToggles }
                Section("Target Intensities") { targetIntensityToggles }
                Section("Target Roan") { targetRoanToggles }
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
            Stepper(
                "Stock Limit: \(gameState.breedingProgram.stockLimit)",
                value: $gameState.breedingProgram.stockLimit,
                in: 2...20
            )
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

    private var targetColorToggles: some View {
        ForEach(BaseColor.allCases, id: \.self) { color in
            Toggle(color.rawValue.capitalized, isOn: Binding(
                get: { gameState.breedingProgram.targetColors.contains(color) },
                set: { on in
                    if on {
                        gameState.breedingProgram.targetColors.insert(color)
                    } else {
                        gameState.breedingProgram.targetColors.remove(color)
                    }
                }
            ))
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
