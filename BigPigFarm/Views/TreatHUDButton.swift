/// TreatHUDButton — HUD button with menu for selecting treat type and entering placement mode.
import SwiftUI

struct TreatHUDButton: View {
    let gameState: GameState
    @Binding var isTreatMode: Bool
    @Binding var selectedTreatType: TreatType

    private var treatCount: Int { gameState.remainingTreatsThisVisit }
    private var currentTier: Int { gameState.farmTier }

    var body: some View {
        Menu {
            ForEach(TreatType.allCases, id: \.self) { type in
                let isUnlocked = type.requiredTier <= currentTier

                Button {
                    selectedTreatType = type
                    isTreatMode = true
                } label: {
                    Label {
                        Text(type.displayName)
                        if isUnlocked {
                            Text(type.effectSummary)
                        } else {
                            Text("Requires Tier \(type.requiredTier)")
                        }
                    } icon: {
                        Image(systemName: type.systemImageName)
                    }
                }
                .disabled(!isUnlocked)
            }

            if isTreatMode {
                Divider()
                Button("Cancel Placement", role: .destructive) {
                    isTreatMode = false
                }
            }
        } label: {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 16))
                    if treatCount > 0 {
                        Text("\(treatCount)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(.green, in: Capsule())
                            .offset(x: 6, y: -4)
                    }
                }
                Text(isTreatMode ? selectedTreatType.displayName : "Treats")
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .foregroundStyle(isTreatMode ? .yellow : .white)
            .opacity(treatCount > 0 ? 1.0 : 0.4)
        }
        .disabled(treatCount <= 0)
        .accessibilityLabel("Treats, \(treatCount) remaining")
    }
}
