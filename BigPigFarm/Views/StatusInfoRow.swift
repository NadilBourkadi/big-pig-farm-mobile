/// StatusInfoRow — HUD status strip showing game metrics at a glance.
/// Extracted from StatusBarView; positioned at the top of the screen.
import SwiftUI

// MARK: - StatusInfoRow

/// Top-of-screen HUD strip displaying day, tier, currency, population,
/// resource levels, and current speed.
///
/// Read-only — no action callbacks. All values are observed from GameState.
struct StatusInfoRow: View {
    let gameState: GameState

    var body: some View {
        HStack(spacing: 10) {
            Text("Day \(gameState.gameTime.day)")
                .font(.caption.bold())
            Text("T\(gameState.farmTier)")
                .font(.caption)
                .foregroundStyle(.secondary)
            CurrencyLabel(amount: gameState.money)
            Text("\(gameState.pigCount)/\(gameState.capacity)")
                .font(.caption)

            if showLowPopulationWarning {
                Text("LOW POP")
                    .font(.caption2.bold())
                    .foregroundStyle(.red)
            }

            Spacer()

            resourceIndicator(systemImage: "fork.knife", level: foodLevel)
            resourceIndicator(systemImage: "drop.fill", level: waterLevel)
            speedIndicator
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Computed Properties

private extension StatusInfoRow {
    /// Average fill percentage (0–100) across all food-type facilities.
    var foodLevel: Int {
        let facilities = gameState.getFacilitiesByType(.foodBowl)
            + gameState.getFacilitiesByType(.hayRack)
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
}

// MARK: - Sub-views

private extension StatusInfoRow {
    @ViewBuilder
    var speedIndicator: some View {
        if gameState.isPaused {
            Image(systemName: "pause.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
        } else {
            Text(gameState.speed.displayLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    func resourceIndicator(systemImage: String, level: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: 10))
            Text("\(level)%")
                .font(.caption2)
        }
        .foregroundStyle(level < 30 ? .red : .primary)
    }
}

// MARK: - Preview

#Preview {
    let state: GameState = {
        let previewState = GameState()
        previewState.farm = FarmGrid.createStarter()
        previewState.money = 1_250
        previewState.speed = .fast
        return previewState
    }()
    StatusInfoRow(gameState: state)
        .background(.black)
}
