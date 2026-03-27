/// StatusInfoRow — HUD status strip showing game metrics at a glance.
/// Extracted from StatusBarView; positioned at the top of the screen.
import SwiftUI

// MARK: - StatusInfoRow

/// Top-of-screen HUD strip displaying day, tier, currency, population,
/// and resource levels.
///
/// Read-only — no action callbacks. All values are observed from GameState.
struct StatusInfoRow: View {
    let gameState: GameState

    var body: some View {
        HStack(spacing: 12) {
            Text("Day \(gameState.gameTime.day)")
                .font(.caption.bold())
                .fixedSize()
            Text("Tier \(gameState.farmTier)")
                .font(.caption)
                .foregroundStyle(Color(red: 0.9, green: 0.84, blue: 0.72).opacity(0.7))
                .fixedSize()
            CurrencyLabel(amount: gameState.money)
            populationLabel

            if showLowPopulationWarning {
                Text(lowPopulationWarningText)
                    .font(.caption2.bold())
                    .foregroundStyle(.red)
                    .fixedSize()
                    .accessibilityLabel(lowPopulationAccessibilityLabel)
            }

            Spacer()

            resourceIndicator(systemImage: "fork.knife", level: foodLevel)
            resourceIndicator(systemImage: "drop.fill", level: waterLevel)
        }
        .foregroundStyle(Color(red: 0.9, green: 0.84, blue: 0.72))
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(Color(red: 0.08, green: 0.05, blue: 0.02).opacity(0.92))
    }
}

// MARK: - Computed Properties

private extension StatusInfoRow {
    /// Average fill percentage (0–100) across all food-type facilities.
    var foodLevel: Int {
        let facilities = gameState.getFacilitiesByType(.foodBowl)
            + gameState.getFacilitiesByType(.hayRack)
            + gameState.getFacilitiesByType(.feastTable)
        guard !facilities.isEmpty else { return 0 }
        let average = facilities.reduce(0.0) { $0 + $1.fillPercentage }
            / Double(facilities.count)
        return Int(average.rounded())
    }

    /// Average fill percentage (0–100) across all water facilities.
    var waterLevel: Int {
        let facilities = gameState.getFacilitiesByType(.waterBottle)
        guard !facilities.isEmpty else { return 0 }
        let average = facilities.reduce(0.0) { $0 + $1.fillPercentage }
            / Double(facilities.count)
        return Int(average.rounded())
    }

    /// True when breeding is enabled and adult pig count is at or below minimum threshold.
    var showLowPopulationWarning: Bool {
        guard gameState.breedingProgram.enabled else { return false }
        let adultCount = gameState.getPigsList().filter { !$0.isBaby }.count
        return adultCount <= GameConfig.Breeding.minBreedingPopulation
    }

    /// Player-facing warning text showing the number of adults needed for breeding.
    var lowPopulationWarningText: String {
        let needed = GameConfig.Breeding.minBreedingPopulation + 1
        return "Need \(needed)+ adults"
    }

    /// VoiceOver label providing full context for the low-population warning.
    var lowPopulationAccessibilityLabel: String {
        let needed = GameConfig.Breeding.minBreedingPopulation + 1
        return "Low population warning: you need at least \(needed) adult pigs for breeding"
    }
}

// MARK: - Sub-views

private extension StatusInfoRow {
    var populationLabel: some View {
        HStack(spacing: 2) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 9))
            Text("\(gameState.pigCount)/\(gameState.capacity)")
                .font(.caption)
        }
        .fixedSize()
    }

    func resourceIndicator(systemImage: String, level: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
            Text("\(level)%")
                .font(.caption)
        }
        .fixedSize()
        .foregroundStyle(level < 30 ? .red : .white)
    }
}

// MARK: - Preview

#Preview {
    let state: GameState = {
        let previewState = GameState()
        previewState.farm = FarmGrid.createStarter()
        previewState.money = 1_250
        return previewState
    }()
    StatusInfoRow(gameState: state)
        .background(.black)
}
