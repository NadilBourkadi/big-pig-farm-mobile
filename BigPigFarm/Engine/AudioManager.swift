/// AudioManager — Plays sound effects for the same events HapticManager covers.
///
/// All methods are @MainActor and mirror HapticManager's API 1:1. Playback is
/// gated by AudioSettings.isEnabled (UserDefaults-backed); when muted, calls
/// no-op silently.
///
/// One AVAudioPlayer per SFX is preloaded at app launch via `preloadAll()`,
/// keeping memory tiny (~100 KB total) and giving zero first-play latency.
/// Rapid retriggers reset `currentTime` to 0 — adequate for the realistic
/// case of a single SFX firing back-to-back.
import AVFoundation

@MainActor
enum AudioManager {
    // MARK: - SFX Catalog

    enum SFX: String, CaseIterable {
        case pigSelected       = "sfx_pig_selected"
        case purchase          = "sfx_purchase"
        case pigSold           = "sfx_pig_sold"
        case birth             = "sfx_birth"
        case pigdexDiscovery   = "sfx_pigdex_discovery"
        case contractCompleted = "sfx_contract_completed"
        case error             = "sfx_error"
        case treatPlaced       = "sfx_treat_placed"
        case treatConsumed     = "sfx_treat_consumed"
    }

    // MARK: - Player Storage

    private static var players: [SFX: AVAudioPlayer] = [:]
    private static var didConfigureSession = false

    /// Cached mute setting. Loaded once at first use, then refreshed only
    /// when `reloadSettings()` is called from SettingsView. Avoids decoding
    /// JSON from UserDefaults on every audio event in the game loop.
    private static var cachedIsEnabled: Bool = AudioSettings.load().isEnabled

    // MARK: - Lifecycle

    /// Configure the audio session and preload every SFX into memory.
    /// Call once at app launch from BigPigFarmApp.init. Safe to call repeatedly.
    static func preloadAll() {
        configureSessionIfNeeded()
        for sfx in SFX.allCases where players[sfx] == nil {
            guard let url = Bundle.main.url(
                forResource: sfx.rawValue,
                withExtension: "wav"
            ) else {
                #if DEBUG
                print("[AudioManager] Missing SFX asset: \(sfx.rawValue).wav")
                #endif
                continue
            }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                player.volume = 1.0
                players[sfx] = player
            } catch {
                #if DEBUG
                print("[AudioManager] Failed to load \(sfx.rawValue): \(error)")
                #endif
            }
        }
    }

    private static func configureSessionIfNeeded() {
        guard !didConfigureSession else { return }
        didConfigureSession = true
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .ambient,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("[AudioManager] Audio session setup failed: \(error)")
            #endif
        }
    }

    /// Refresh the cached mute setting from UserDefaults. Call this from
    /// SettingsView whenever the user toggles the Sound Effects switch.
    static func reloadSettings() {
        cachedIsEnabled = AudioSettings.load().isEnabled
    }

    // MARK: - Internal Playback

    private static func play(_ sfx: SFX) {
        guard cachedIsEnabled else { return }
        if players[sfx] == nil {
            // Lazy fallback in case preloadAll() was never called.
            preloadAll()
        }
        guard let player = players[sfx] else { return }
        player.currentTime = 0
        player.play()
    }

    // MARK: - Event Methods (mirror HapticManager 1:1)

    /// Pig tapped/selected in the farm scene.
    static func pigSelected() { play(.pigSelected) }

    /// Facility or perk purchased from the shop.
    static func purchase() { play(.purchase) }

    /// Pig sold at market or auto-sold.
    static func pigSold() { play(.pigSold) }

    /// New pig born.
    static func birth() { play(.birth) }

    /// New phenotype discovered in the pigdex.
    static func pigdexDiscovery() { play(.pigdexDiscovery) }

    /// Breeding contract completed.
    static func contractCompleted() { play(.contractCompleted) }

    /// Error or failure (insufficient funds, invalid placement).
    static func error() { play(.error) }

    /// Treat placed on the farm during visit.
    static func treatPlaced() { play(.treatPlaced) }

    /// Pig consumed a treat (hearts particle).
    static func treatConsumed() { play(.treatConsumed) }
}
