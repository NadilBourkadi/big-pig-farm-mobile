/// OfflineProgressView — Summary popup shown when the player returns from offline.
///
/// Displays a summary of births, deaths, sales, pregnancies, and other events
/// that occurred during offline catch-up. Presented as a modal by the lifecycle
/// integration layer (bead is2).
import SwiftUI

// MARK: - Time Formatting

/// Formats a wall-clock TimeInterval into a human-readable duration string.
///
/// Examples: "2 hours 15 minutes", "1 day 3 hours", "Less than a minute"
func formatOfflineDuration(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    if totalSeconds < 60 { return "Less than a minute" }

    let minutes = (totalSeconds / 60) % 60
    let hours = (totalSeconds / 3600) % 24
    let days = totalSeconds / 86400

    if days > 0 {
        if hours > 0 {
            let dayUnit = days == 1 ? "day" : "days"
            let hourUnit = hours == 1 ? "hour" : "hours"
            return "\(days) \(dayUnit) \(hours) \(hourUnit)"
        }
        return days == 1 ? "1 day" : "\(days) days"
    }

    if hours > 0 {
        if minutes > 0 {
            let hourUnit = hours == 1 ? "hour" : "hours"
            let minUnit = minutes == 1 ? "minute" : "minutes"
            return "\(hours) \(hourUnit) \(minutes) \(minUnit)"
        }
        return hours == 1 ? "1 hour" : "\(hours) hours"
    }

    return minutes == 1 ? "1 minute" : "\(minutes) minutes"
}

// MARK: - OfflineProgressView

struct OfflineProgressView: View {
    let summary: OfflineProgressSummary
    let onContinue: () -> Void

    /// Threshold for inline list vs collapsible disclosure group.
    private let inlineThreshold = 5

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    if summary.hasMeaningfulEvents {
                        eventSections
                    } else {
                        emptyStateSection
                    }
                    continueButton
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "sunrise.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("While You Were Away...")
                .font(.title2.bold())
            Text(formatOfflineDuration(summary.wallClockElapsed))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Event Sections

    @ViewBuilder
    private var eventSections: some View {
        if !summary.pigsBorn.isEmpty {
            birthsSection
        }
        if !summary.pigsDied.isEmpty {
            deathsSection
        }
        if !summary.pigsSold.isEmpty {
            salesSection
        }
        if !summary.pregnanciesStarted.isEmpty {
            pregnanciesSection
        }
        if !summary.pigdexDiscoveries.isEmpty {
            pigdexSection
        }
        if summary.facilitiesEmptied > 0 {
            facilitiesSection
        }
        if summary.totalMoneyEarned > 0 {
            moneySection
        }
    }

    // MARK: - Births

    private var birthsSection: some View {
        let count = summary.pigsBorn.count
        let title = count == 1 ? "1 pig born" : "\(count) pigs born"
        return sectionCard(icon: "gift.fill", title: title, color: .green) {
            if count <= inlineThreshold {
                birthList
            } else {
                DisclosureGroup("Show all") { birthList }
            }
        }
    }

    private var birthList: some View {
        ForEach(Array(summary.pigsBorn.enumerated()), id: \.offset) { _, born in
            if born.phenotype.isEmpty {
                Text(born.name).font(.caption)
            } else {
                Text("\(born.name) — \(born.phenotype)").font(.caption)
            }
        }
    }

    // MARK: - Deaths

    private var deathsSection: some View {
        let count = summary.pigsDied.count
        let title = count == 1 ? "1 pig passed away" : "\(count) pigs passed away"
        return sectionCard(icon: "heart.slash.fill", title: title, color: .red) {
            if count <= inlineThreshold {
                deathList
            } else {
                DisclosureGroup("Show all") { deathList }
            }
        }
    }

    private var deathList: some View {
        ForEach(Array(summary.pigsDied.enumerated()), id: \.offset) { _, dead in
            Text("\(dead.name) — \(dead.ageDays) days old").font(.caption)
        }
    }

    // MARK: - Sales

    private var salesSection: some View {
        let count = summary.pigsSold.count
        let total = summary.pigsSold.reduce(0) { $0 + $1.value }
        let title = count == 1
            ? "1 pig sold (\(Currency.formatCurrency(total)))"
            : "\(count) pigs sold (\(Currency.formatCurrency(total)))"
        return sectionCard(icon: "dollarsign.circle.fill", title: title, color: .yellow) {
            if count <= inlineThreshold {
                salesList
            } else {
                DisclosureGroup("Show all") { salesList }
            }
        }
    }

    private var salesList: some View {
        ForEach(Array(summary.pigsSold.enumerated()), id: \.offset) { _, sold in
            Text("\(sold.name) — \(Currency.formatCurrency(sold.value))").font(.caption)
        }
    }

    // MARK: - Pregnancies

    private var pregnanciesSection: some View {
        let count = summary.pregnanciesStarted.count
        let title = count == 1 ? "1 pregnancy started" : "\(count) pregnancies started"
        return sectionCard(icon: "heart.fill", title: title, color: .pink) {
            EmptyView()
        }
    }

    // MARK: - Pigdex

    private var pigdexSection: some View {
        let count = summary.pigdexDiscoveries.count
        let title = count == 1 ? "1 new discovery" : "\(count) new discoveries"
        return sectionCard(icon: "book.fill", title: title, color: .orange) {
            EmptyView()
        }
    }

    // MARK: - Facilities Warning

    private var facilitiesSection: some View {
        let count = summary.facilitiesEmptied
        let title = count == 1 ? "1 facility ran dry" : "\(count) facilities ran dry"
        return sectionCard(
            icon: "exclamationmark.triangle.fill", title: title, color: .orange
        ) {
            Text("Check your food bowls and water bottles!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Money

    private var moneySection: some View {
        sectionCard(
            icon: "dollarsign.circle.fill",
            title: "Earned \(Currency.formatCurrency(summary.totalMoneyEarned))",
            color: .yellow
        ) {
            EmptyView()
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Nothing happened while you were away.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button(action: onContinue) {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Dismiss offline progress summary")
        .padding(.top, 8)
    }

    // MARK: - Section Card Helper

    private func sectionCard<Content: View>(
        icon: String,
        title: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
