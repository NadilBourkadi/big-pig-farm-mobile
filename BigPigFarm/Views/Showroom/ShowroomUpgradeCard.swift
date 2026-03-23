/// ShowroomUpgradeCard — Individual upgrade card in the Showroom.
/// Shows name, Rosette cost, effect description, and purchase state.
import SwiftUI

// MARK: - UpgradeDisplayState

/// Visual state of a Showroom upgrade card.
enum UpgradeDisplayState: Sendable {
    case purchased
    case affordable
    case unaffordable

    static func resolve(
        upgrade: ShowroomUpgrade,
        prestigeState: PrestigeState
    ) -> UpgradeDisplayState {
        if prestigeState.hasUpgrade(upgrade) {
            return .purchased
        } else if prestigeState.rosetteBalance >= upgrade.cost {
            return .affordable
        } else {
            return .unaffordable
        }
    }
}

// MARK: - ShowroomUpgradeCard

struct ShowroomUpgradeCard: View {
    let upgrade: ShowroomUpgrade
    let displayState: UpgradeDisplayState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(upgrade.displayName)
                        .font(.body.bold())
                        .foregroundStyle(titleColor)
                    Text(upgrade.info.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                stateIndicator
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(displayState == .unaffordable ? 0.6 : 1.0)
    }
}

// MARK: - Sub-views

private extension ShowroomUpgradeCard {
    var stateIndicator: some View {
        VStack(spacing: 6) {
            switch displayState {
            case .purchased:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
                Text("Owned")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            case .affordable:
                rosetteLabel
                    .foregroundStyle(.orange)
                Text("Buy")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.orange)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            case .unaffordable:
                rosetteLabel
                    .foregroundStyle(.secondary)
            }
        }
    }

    var rosetteLabel: some View {
        Label("\(upgrade.cost)", systemImage: "rosette")
            .font(.caption.bold())
    }

    var titleColor: Color {
        switch displayState {
        case .purchased: .primary
        case .affordable: .primary
        case .unaffordable: .secondary
        }
    }
}
