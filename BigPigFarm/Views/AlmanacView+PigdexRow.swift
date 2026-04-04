// AlmanacView+PigdexRow — Pigdex discovery grid row and pulsing milestone pill.
// Extracted from AlmanacView.swift to keep file length under 300 lines.
import SwiftUI

// MARK: - PulsingPill

/// Pill-shaped milestone indicator with a gentle opacity pulse to signal tappability.
/// Matches StatusBadge tinted style (padding, corner radius, background opacity).
struct PulsingPill: View {
    let threshold: Int
    @State private var isPulsing = false

    var body: some View {
        Text("READY! \(threshold)%")
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(.yellow)
            .background(Color.yellow.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .opacity(isPulsing ? 1.0 : 0.7)
            .accessibilityHidden(true)
            .onAppear { isPulsing = true }
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
    }
}

// MARK: - PigdexRow

/// One row of 8 color-coded discovery circles for a single pattern/intensity/roan combo.
/// Maps from: almanac.py PigdexPanel grid row rendering.
struct PigdexRow: View {
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
                let discovered = pigdex.isDiscovered(key)
                Circle()
                    .fill(discovered
                        ? pigColorSwiftUI(color)
                        : Color.gray.opacity(0.2))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                            .accessibilityHidden(true)
                    )
                    .accessibilityLabel(circleLabel(color: color, discovered: discovered))
            }
        }
    }

    private var rowLabel: String {
        var parts: [String] = []
        if pattern != .solid { parts.append(pattern.rawValue.capitalized) }
        if intensity != .full { parts.append(intensity.rawValue.capitalized) }
        return parts.isEmpty ? "Solid" : parts.joined(separator: "/")
    }

    private func circleLabel(color: BaseColor, discovered: Bool) -> String {
        let roanSuffix = roan != .none ? " roan" : ""
        let state = discovered ? "discovered" : "not yet discovered"
        return "\(color.rawValue.capitalized) \(rowLabel)\(roanSuffix), \(state)"
    }
}
