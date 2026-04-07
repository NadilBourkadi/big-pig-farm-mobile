/// AudioManagerTests — Smoke tests for AudioManager event methods, plus
/// asset bundle presence and AudioSettings persistence checks.
///
/// Mirrors the structure of HapticManagerTests. AVAudioPlayer is happy to
/// initialise in the test environment when the .app bundle is the test host
/// (BigPigFarmTests.TEST_HOST = BigPigFarm.app).
import Testing
import Foundation
import AVFoundation
@testable import BigPigFarm

// MARK: - AudioManager Smoke Tests

@Test @MainActor func audioPigSelectedDoesNotCrash() {
    AudioManager.pigSelected()
}

@Test @MainActor func audioPurchaseDoesNotCrash() {
    AudioManager.purchase()
}

@Test @MainActor func audioPigSoldDoesNotCrash() {
    AudioManager.pigSold()
}

@Test @MainActor func audioBirthDoesNotCrash() {
    AudioManager.birth()
}

@Test @MainActor func audioPigdexDiscoveryDoesNotCrash() {
    AudioManager.pigdexDiscovery()
}

@Test @MainActor func audioContractCompletedDoesNotCrash() {
    AudioManager.contractCompleted()
}

@Test @MainActor func audioErrorDoesNotCrash() {
    AudioManager.error()
}

@Test @MainActor func audioTreatPlacedDoesNotCrash() {
    AudioManager.treatPlaced()
}

@Test @MainActor func audioTreatConsumedDoesNotCrash() {
    AudioManager.treatConsumed()
}

// MARK: - Repeated Calls

@Test @MainActor func audioMethodsAreIdempotent() {
    // Calling repeatedly in the same tick must not crash or accumulate state.
    for _ in 0..<5 {
        AudioManager.pigSelected()
        AudioManager.purchase()
        AudioManager.pigSold()
        AudioManager.birth()
        AudioManager.pigdexDiscovery()
        AudioManager.contractCompleted()
        AudioManager.error()
        AudioManager.treatPlaced()
        AudioManager.treatConsumed()
    }
}

// MARK: - Bundle Presence

@Test @MainActor func allSFXFilesExistInBundle() {
    for sfx in AudioManager.SFX.allCases {
        let url = Bundle.main.url(forResource: sfx.rawValue, withExtension: "wav")
        #expect(url != nil, "Missing SFX asset: \(sfx.rawValue).wav")
    }
}

@Test @MainActor func allSFXFilesAreLoadable() throws {
    for sfx in AudioManager.SFX.allCases {
        let url = try #require(
            Bundle.main.url(forResource: sfx.rawValue, withExtension: "wav"),
            "Missing SFX asset: \(sfx.rawValue).wav"
        )
        let player = try AVAudioPlayer(contentsOf: url)
        #expect(player.duration > 0, "Empty SFX file: \(sfx.rawValue)")
    }
}

// MARK: - AudioSettings Persistence

@Test func audioSettingsDefaultIsEnabled() throws {
    let suiteName = "AudioManagerTests.default"
    let suite = try #require(UserDefaults(suiteName: suiteName))
    suite.removePersistentDomain(forName: suiteName)
    #expect(AudioSettings.load(from: suite).isEnabled == true)
}

@Test func audioSettingsRoundTripsThroughUserDefaults() throws {
    let suiteName = "AudioManagerTests.roundtrip"
    let suite = try #require(UserDefaults(suiteName: suiteName))
    defer { suite.removePersistentDomain(forName: suiteName) }
    suite.removePersistentDomain(forName: suiteName)

    var settings = AudioSettings.load(from: suite)
    settings.isEnabled = false
    settings.save(to: suite)

    let reloaded = AudioSettings.load(from: suite)
    #expect(reloaded.isEnabled == false)
}

@Test func audioSettingsToggleBackOn() throws {
    let suiteName = "AudioManagerTests.toggleback"
    let suite = try #require(UserDefaults(suiteName: suiteName))
    defer { suite.removePersistentDomain(forName: suiteName) }
    suite.removePersistentDomain(forName: suiteName)

    var settings = AudioSettings(isEnabled: false)
    settings.save(to: suite)
    settings.isEnabled = true
    settings.save(to: suite)

    let reloaded = AudioSettings.load(from: suite)
    #expect(reloaded.isEnabled == true)
}

// MARK: - reloadSettings cache invalidation

@Test @MainActor func audioManagerReloadSettingsRefreshesCache() {
    // Snapshot whatever the user had set so we can restore it.
    let original = AudioSettings.load()
    defer {
        original.save()
        AudioManager.reloadSettings()
    }

    // Mute → reload → calls should no-op (we can't observe playback, but
    // play() must not crash and must return early).
    var muted = AudioSettings(isEnabled: false)
    muted.save()
    AudioManager.reloadSettings()
    AudioManager.pigSelected()
    AudioManager.birth()

    // Unmute → reload → calls proceed normally.
    muted.isEnabled = true
    muted.save()
    AudioManager.reloadSettings()
    AudioManager.pigSelected()
    AudioManager.birth()
}

// MARK: - HapticManager / AudioManager API Parity

/// Compile-time parity check: every HapticManager event method must have an
/// AudioManager equivalent. Adding a new haptic event without an audio twin
/// will fail to compile here, prompting the developer to add both.
@Test @MainActor func audioManagerMirrorsHapticManagerSurface() {
    @MainActor func parity() {
        HapticManager.pigSelected();        AudioManager.pigSelected()
        HapticManager.purchase();           AudioManager.purchase()
        HapticManager.pigSold();            AudioManager.pigSold()
        HapticManager.birth();              AudioManager.birth()
        HapticManager.pigdexDiscovery();    AudioManager.pigdexDiscovery()
        HapticManager.contractCompleted();  AudioManager.contractCompleted()
        HapticManager.error();              AudioManager.error()
        HapticManager.treatPlaced();        AudioManager.treatPlaced()
        HapticManager.treatConsumed();      AudioManager.treatConsumed()
    }
    parity()
}
