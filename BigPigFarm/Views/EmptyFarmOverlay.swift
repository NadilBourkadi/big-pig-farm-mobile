/// EmptyFarmOverlay — Centered prompt shown when the farm has zero pigs.
///
/// Guides the player to the Adoption Center. Distinct from EmergencyBailoutBanner
/// which handles the soft-locked case (zero pigs AND insufficient money for adoption).
/// This overlay covers the broader "no pigs" state, regardless of money.
///
/// Maps from: no Python equivalent (mobile-only UX improvement).
import SwiftUI

struct EmptyFarmOverlay: View {
    let onAdoptTapped: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Your Farm is Empty")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text("Visit the Adoption Center to bring home new guinea pigs.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button(action: onAdoptTapped) {
                Label("Open Adoption Center", systemImage: "cart.fill")
                    .font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.12, green: 0.08, blue: 0.04).opacity(0.95))
        )
        .padding(.horizontal, 40)
        .accessibilityLabel("Your farm is empty")
    }
}
