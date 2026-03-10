// AlmanacView — Pigdex, contracts, and farm statistics.
// Maps from: ui/screens/almanac_screen.py
import SwiftUI

// MARK: - AlmanacTab

/// The three tabs available in the almanac.
enum AlmanacTab: String, Sendable {
    case pigdex = "Pigdex"
    case contracts = "Contracts"
    case log = "Log"
}

// MARK: - AlmanacView

/// Journal screen with Pigdex collection, breeding contracts, and event log.
/// Maps from: almanac.py JournalScreen class.
struct AlmanacView: View {
    let gameState: GameState
    @State private var selectedTab: AlmanacTab = .pigdex
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                PigdexTab(gameState: gameState)
                    .tabItem { Label("Pigdex", systemImage: "book.fill") }
                    .tag(AlmanacTab.pigdex)
                ContractsTab(gameState: gameState)
                    .tabItem { Label("Contracts", systemImage: "doc.text.fill") }
                    .tag(AlmanacTab.contracts)
                EventLogTab(gameState: gameState)
                    .tabItem { Label("Log", systemImage: "bell.fill") }
                    .tag(AlmanacTab.log)
            }
            .navigationTitle(selectedTab.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - PigdexTab

/// Pigdex phenotype discovery grid (144 slots) with milestone progress.
/// Maps from: almanac.py PigdexPanel class.
private struct PigdexTab: View {
    let gameState: GameState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                milestonesSection
                    .padding(.horizontal)
                ForEach(RoanType.allCases, id: \.rawValue) { roan in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(roan == .none ? "Standard" : "Roan")
                            .font(.headline)
                            .padding(.horizontal)
                        ForEach(ColorIntensity.allCases, id: \.rawValue) { intensity in
                            ForEach(Pattern.allCases, id: \.rawValue) { pattern in
                                PigdexRow(
                                    pattern: pattern,
                                    intensity: intensity,
                                    roan: roan,
                                    pigdex: gameState.pigdex
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private var milestonesSection: some View {
        let pct = gameState.pigdex.completionPercent
        return VStack(alignment: .leading, spacing: 6) {
            Text("Discovered: \(gameState.pigdex.discoveredCount)/\(totalPhenotypes) (\(Int(pct.rounded()))%)")
                .font(.subheadline.bold())
            HStack(spacing: 12) {
                ForEach(milestoneThresholds, id: \.self) { threshold in
                    milestoneLabel(threshold: threshold, pct: pct)
                }
            }
        }
    }

    private func milestoneLabel(threshold: Int, pct: Double) -> some View {
        let claimed = gameState.pigdex.milestoneRewardsClaimed.contains(threshold)
        let ready = pct >= Double(threshold)
        let label: String
        let color: Color
        if claimed {
            label = "✓ \(threshold)%"
            color = .green
        } else if ready {
            label = "READY! \(threshold)%"
            color = .yellow
        } else {
            label = "\(Int(pct))/\(threshold)%"
            color = .secondary
        }
        return Text(label)
            .font(.caption2)
            .foregroundStyle(color)
    }
}

// MARK: - PigdexRow

/// One row of 8 color-coded discovery circles for a single pattern/intensity/roan combo.
/// Maps from: almanac.py PigdexPanel grid row rendering.
private struct PigdexRow: View {
    let pattern: Pattern
    let intensity: ColorIntensity
    let roan: RoanType
    let pigdex: Pigdex

    var body: some View {
        HStack(spacing: 4) {
            Text(rowLabel)
                .font(.caption2)
                .frame(width: 72, alignment: .leading)
            ForEach(BaseColor.allCases, id: \.rawValue) { color in
                let key = phenotypeKeyFromParts(
                    baseColor: color, pattern: pattern,
                    intensity: intensity, roan: roan
                )
                Circle()
                    .fill(pigdex.isDiscovered(key)
                        ? pigColorSwiftUI(color)
                        : Color.gray.opacity(0.2))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(.secondary.opacity(0.3), lineWidth: 1))
            }
        }
    }

    private var rowLabel: String {
        var parts: [String] = []
        if pattern != .solid { parts.append(pattern.rawValue.capitalized) }
        if intensity != .full { parts.append(intensity.rawValue.capitalized) }
        return parts.isEmpty ? "Solid" : parts.joined(separator: "/")
    }
}

// MARK: - ContractsTab

/// Active breeding contracts list with completion statistics.
/// Maps from: almanac.py ContractsPanel class.
private struct ContractsTab: View {
    let gameState: GameState

    var body: some View {
        List {
            Section("Active Contracts") {
                if gameState.contractBoard.activeContracts.isEmpty {
                    Text("No active contracts.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(gameState.contractBoard.activeContracts) { contract in
                        ContractRow(contract: contract, currentDay: gameState.gameTime.day)
                    }
                }
            }
            Section("Statistics") {
                InfoRow(label: "Completed", value: "\(gameState.contractBoard.completedContracts)")
                let earned = Currency.formatCurrency(gameState.contractBoard.totalContractEarnings)
                InfoRow(label: "Total Earned", value: earned)
                InfoRow(label: "Current Day", value: "Day \(gameState.gameTime.day)")
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - ContractRow

/// A single breeding contract row with difficulty badge and deadline countdown.
/// Maps from: almanac.py ContractsPanel._format_contract()
private struct ContractRow: View {
    let contract: BreedingContract
    let currentDay: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(contract.description)
                    .font(.subheadline)
                Spacer()
                Text(contract.difficulty.rawValue.capitalized)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .foregroundStyle(.white)
                    .background(difficultyColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            HStack {
                Text("+\(Currency.formatCurrency(contract.reward))")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                Spacer()
                let daysLeft = max(0, contract.deadlineDay - currentDay)
                Text("\(daysLeft)d left")
                    .font(.caption)
                    .foregroundStyle(daysLeft < 5 ? .red : .secondary)
            }
            if !contract.breedingHint.isEmpty {
                Text("Tip: \(contract.breedingHint)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var difficultyColor: Color {
        switch contract.difficulty {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .orange
        case .expert: return .red
        case .legendary: return .purple
        }
    }
}

// MARK: - EventLogTab

/// Reverse-chronological event feed.
/// Maps from: almanac.py EventLogPanel class.
private struct EventLogTab: View {
    let gameState: GameState

    var body: some View {
        if gameState.events.isEmpty {
            ContentUnavailableView("No Events Yet", systemImage: "bell.slash.fill")
        } else {
            List(gameState.events.reversed()) { event in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: eventIcon(event.eventType))
                        .foregroundStyle(eventColor(event.eventType))
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.message)
                            .font(.subheadline)
                        Text("Day \(event.gameDay)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func eventIcon(_ type: String) -> String {
        switch type {
        case "birth": return "gift.fill"
        case "death": return "heart.slash.fill"
        case "sale": return "dollarsign.circle.fill"
        case "purchase": return "cart.fill"
        case "breeding": return "heart.fill"
        case "mutation": return "sparkles"
        case "pigdex": return "book.fill"
        case "contract": return "doc.text.fill"
        case "adoption": return "heart.circle.fill"
        default: return "bell.fill"
        }
    }

    private func eventColor(_ type: String) -> Color {
        switch type {
        case "birth": return .green
        case "death": return .red
        case "sale": return .yellow
        case "purchase": return .blue
        case "breeding": return .pink
        case "mutation": return .purple
        case "pigdex": return .orange
        case "contract": return .teal
        case "adoption": return .indigo
        default: return .secondary
        }
    }
}
