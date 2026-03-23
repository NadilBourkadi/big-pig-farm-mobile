/// AllelePreferencesPanel -- Per-locus allele bias configuration.
/// Appears in the breeding program UI when Selective Advantage is purchased.
import SwiftUI

struct AllelePreferencesPanel: View {
    @Bindable var gameState: GameState

    var body: some View {
        Section {
            ForEach(locusDefinitions, id: \.0) { locusName, dominant, recessive in
                LocusPreferenceRow(
                    displayName: locusDisplayNames[locusName] ?? locusName,
                    dominantLabel: dominant,
                    recessiveLabel: recessive,
                    preference: locusBinding(locusName)
                )
            }
        } header: {
            Label("Allele Preferences", systemImage: "dna")
        } footer: {
            Text("80% chance offspring inherit the preferred allele when a parent carries it.")
        }
    }

    private func locusBinding(_ locusName: String) -> Binding<AllelePreference> {
        Binding(
            get: { gameState.prestigeState.allelePreferences.preference(forLocus: locusName) },
            set: { newValue in
                switch locusName {
                case "eLocus": gameState.prestigeState.allelePreferences.eLocus = newValue
                case "bLocus": gameState.prestigeState.allelePreferences.bLocus = newValue
                case "sLocus": gameState.prestigeState.allelePreferences.sLocus = newValue
                case "cLocus": gameState.prestigeState.allelePreferences.cLocus = newValue
                case "rLocus": gameState.prestigeState.allelePreferences.rLocus = newValue
                case "dLocus": gameState.prestigeState.allelePreferences.dLocus = newValue
                default: assertionFailure("Unhandled locus: \(locusName)")
                }
            }
        )
    }
}

// MARK: - LocusPreferenceRow

private struct LocusPreferenceRow: View {
    let displayName: String
    let dominantLabel: String
    let recessiveLabel: String
    @Binding var preference: AllelePreference

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayName)
                .font(.subheadline)
            Picker(displayName, selection: $preference) {
                Text(dominantLabel).tag(AllelePreference.dominant)
                Text("Any").tag(AllelePreference.noPreference)
                Text(recessiveLabel).tag(AllelePreference.recessive)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}
