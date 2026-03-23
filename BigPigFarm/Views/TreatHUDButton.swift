/// TreatHUDButton — HUD button showing available treat count with placement mode toggle.
import SwiftUI

struct TreatHUDButton: View {
    let gameState: GameState
    @Binding var isTreatMode: Bool

    private var treatCount: Int { gameState.remainingTreatsThisVisit }

    var body: some View {
        Button {
            isTreatMode.toggle()
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
                Text("Treats")
                    .font(.system(size: 9))
            }
            .foregroundStyle(isTreatMode ? .yellow : .white)
            .opacity(treatCount > 0 ? 1.0 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(treatCount <= 0)
        .accessibilityLabel("Treats, \(treatCount) remaining")
    }
}
