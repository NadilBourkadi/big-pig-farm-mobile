/// JudgingScreenView — Exhibition scoring display for the Pig Show.
/// Shows each Rosette scoring dimension as a card, with the total at the bottom.
import SwiftUI

struct JudgingScreenView: View {
    let gameState: GameState
    let breakdown: RosetteBreakdown
    let onContinue: () -> Void

    private var newPigdexCount: Int {
        PigShowCalculator.newPigdexEntries(
            currentPigdex: gameState.pigdex,
            previousEntries: gameState.prestigeState.previousPigdexEntries
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                scoringDimensions
                totalSection
                continueButton
            }
            .padding()
        }
        .navigationTitle("The Grand Pig Show")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)
            Text("Judging Results")
                .font(.title2.bold())
            Text("Your herd has been evaluated across five dimensions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Scoring Dimensions

    @ViewBuilder
    private var scoringDimensions: some View {
        dimensionCard(
            icon: "dollarsign.circle.fill",
            title: "Farm Earnings",
            detail: "sqrt(lifetime Squeaks / \(GameConfig.Prestige.rosetteBaseDivisor))",
            value: breakdown.baseRosettes,
            color: .yellow
        )
        dimensionCard(
            icon: "book.fill",
            title: "Pigdex Progress",
            detail: "\(newPigdexCount) new entries",
            value: breakdown.pigdexBonus,
            color: .orange
        )
        dimensionCard(
            icon: "paintpalette.fill",
            title: "Herd Diversity",
            detail: "\(PigShowCalculator.uniquePhenotypesInHerd(gameState)) unique phenotypes",
            value: breakdown.diversityBonus,
            color: .purple
        )
        dimensionCard(
            icon: "doc.text.fill",
            title: "Contracts Completed",
            detail: "\(gameState.contractBoard.completedContracts) contracts",
            value: breakdown.contractBonus,
            color: .blue
        )
        dimensionCard(
            icon: "star.fill",
            title: "Legendary Pig",
            detail: breakdown.rarityBonus > 0 ? "Legendary pig in herd!" : "No legendary pig",
            value: breakdown.rarityBonus,
            color: .pink
        )
        dimensionCard(
            icon: "flame.fill",
            title: "Visit Streak",
            detail: "Bonus from consecutive visits",
            value: breakdown.streakBonus,
            color: .red
        )
    }

    // MARK: - Total

    private var totalSection: some View {
        HStack {
            Label("Rosettes Earned", systemImage: "rosette")
                .font(.headline)
            Spacer()
            Text("\(breakdown.total)")
                .font(.title.bold())
                .foregroundStyle(.pink)
        }
        .padding()
        .background(.pink.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Continue

    private var continueButton: some View {
        Button(action: onContinue) {
            Text("Continue to Showroom Preview")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.pink)
        .padding(.top, 8)
    }

    // MARK: - Dimension Card

    private func dimensionCard(
        icon: String,
        title: String,
        detail: String,
        value: Int,
        color: Color
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("+\(value)")
                .font(.title3.bold())
                .foregroundStyle(value > 0 ? color : .secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
