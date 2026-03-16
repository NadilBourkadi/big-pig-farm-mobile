/// Tests for OfflineProgressView and formatOfflineDuration helper.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Time Formatting

@Suite("Offline Duration Formatting")
struct OfflineDurationFormattingTests {
    @Test func underOneMinute() {
        #expect(OfflineDurationFormatter.format(30) == "Less than a minute")
    }

    @Test func exactlyOneMinute() {
        #expect(OfflineDurationFormatter.format(60) == "1 minute")
    }

    @Test func minutesOnly() {
        #expect(OfflineDurationFormatter.format(300) == "5 minutes")
    }

    @Test func exactlyOneHour() {
        #expect(OfflineDurationFormatter.format(3600) == "1 hour")
    }

    @Test func hoursAndMinutes() {
        #expect(OfflineDurationFormatter.format(8100) == "2 hours 15 minutes")
    }

    @Test func hoursNoMinutes() {
        #expect(OfflineDurationFormatter.format(7200) == "2 hours")
    }

    @Test func singularHourAndMinute() {
        #expect(OfflineDurationFormatter.format(3660) == "1 hour 1 minute")
    }

    @Test func pluralHoursAndMinutes() {
        #expect(OfflineDurationFormatter.format(7320) == "2 hours 2 minutes")
    }

    @Test func exactlyOneDay() {
        #expect(OfflineDurationFormatter.format(86400) == "1 day")
    }

    @Test func dayAndHours() {
        #expect(OfflineDurationFormatter.format(90000) == "1 day 1 hour")
    }

    @Test func zeroSeconds() {
        #expect(OfflineDurationFormatter.format(0) == "Less than a minute")
    }
}

// MARK: - Summary Edge Cases

@Suite("Offline Summary Properties")
struct OfflineSummaryPropertyTests {
    @Test func emptySummaryNotMeaningful() {
        let summary = OfflineProgressSummary(wallClockElapsed: 100, gameHoursElapsed: 5)
        #expect(!summary.hasMeaningfulEvents)
    }

    @Test func deathsAloneMeaningful() {
        var summary = OfflineProgressSummary(wallClockElapsed: 100, gameHoursElapsed: 5)
        summary.pigsDied.append(.init(name: "Fluffy", ageDays: 42))
        #expect(summary.hasMeaningfulEvents)
    }

    @Test func pigdexAloneMeaningful() {
        var summary = OfflineProgressSummary(wallClockElapsed: 100, gameHoursElapsed: 5)
        summary.pigdexDiscoveries = ["New phenotype discovered!"]
        #expect(summary.hasMeaningfulEvents)
    }

    @Test func facilitiesAloneMeaningful() {
        var summary = OfflineProgressSummary(wallClockElapsed: 100, gameHoursElapsed: 5)
        summary.facilitiesEmptied = 2
        #expect(summary.hasMeaningfulEvents)
    }

    @Test func salesAloneMeaningful() {
        var summary = OfflineProgressSummary(wallClockElapsed: 100, gameHoursElapsed: 5)
        summary.pigsSold.append(.init(name: "Patches", value: 150))
        #expect(summary.hasMeaningfulEvents)
    }

    @Test func pregnanciesAloneMeaningful() {
        var summary = OfflineProgressSummary(wallClockElapsed: 100, gameHoursElapsed: 5)
        summary.pregnanciesStarted.append(.init(maleName: "Bob", femaleName: "Alice"))
        #expect(summary.hasMeaningfulEvents)
    }

    @Test func moneyAloneMeaningful() {
        var summary = OfflineProgressSummary(wallClockElapsed: 100, gameHoursElapsed: 5)
        summary.totalMoneyEarned = 500
        #expect(summary.hasMeaningfulEvents)
    }
}

// MARK: - View Instantiation

@Suite("OfflineProgressView Instantiation")
struct OfflineProgressViewInstantiationTests {
    @Test func acceptsEmptySummary() {
        let summary = OfflineProgressSummary(wallClockElapsed: 60, gameHoursElapsed: 1)
        _ = OfflineProgressView(summary: summary, onContinue: {})
    }

    @Test func acceptsFullSummary() {
        var summary = OfflineProgressSummary(
            wallClockElapsed: 86400, gameHoursElapsed: 4320
        )
        summary.pigsBorn = (0..<20).map {
            .init(name: "Baby\($0)", phenotype: "White Solid")
        }
        summary.pigsDied = [.init(name: "Elder", ageDays: 44)]
        summary.pigsSold = [.init(name: "Surplus", value: 200)]
        summary.pregnanciesStarted = [.init(maleName: "M", femaleName: "F")]
        summary.pigdexDiscoveries = ["New phenotype discovered!"]
        summary.facilitiesEmptied = 3
        summary.totalMoneyEarned = 1500
        _ = OfflineProgressView(summary: summary, onContinue: {})
    }

    @Test func acceptsDeathOnlySummary() {
        var summary = OfflineProgressSummary(wallClockElapsed: 3600, gameHoursElapsed: 180)
        summary.pigsDied = [
            .init(name: "Whiskers", ageDays: 45),
            .init(name: "Patches", ageDays: 43),
        ]
        _ = OfflineProgressView(summary: summary, onContinue: {})
    }
}
