/// NewPasturesConfirmation — Final confirmation dialog before prestige reset.
/// Presented as the last step in the Pig Show flow.
import SwiftUI

struct NewPasturesConfirmation: View {
    let rosetteTotal: Int
    let farmNumber: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                detailSection
                buttonSection
            }
            .padding()
        }
        .navigationTitle("New Pastures")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Move to New Pastures?")
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    // MARK: - Details

    private var detailSection: some View {
        VStack(spacing: 16) {
            Text("Sell your prize-winning herd and start a new farm. Your Rosettes and breeding knowledge travel with you.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 8) {
                Label("\(rosetteTotal) Rosettes earned", systemImage: "rosette")
                    .font(.headline)
                    .foregroundStyle(.pink)
                Label("Starting Farm #\(farmNumber)", systemImage: "leaf.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.pink.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        VStack(spacing: 12) {
            Button(action: onConfirm) {
                Text("Move to New Pastures")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)

            Button(action: onCancel) {
                Text("Stay on Current Farm")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 8)
    }
}
