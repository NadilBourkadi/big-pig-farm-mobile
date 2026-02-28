import Foundation

/// Animation timing and frame count data for pig sprite animations.
///
/// Ports ANIM_TICKS_PER_FRAME and ANIM_FRAME_COUNT from
/// big_pig_farm/data/sprite_engine.py. Display state strings (not
/// BehaviorState enum values) are used as keys, matching
/// GuineaPig.displayState output: "idle", "walking", "eating",
/// "sleeping", "happy", "sad".
enum AnimationData {

    // MARK: - Raw Data

    /// Number of simulation ticks each animation frame is displayed
    /// before advancing to the next frame. Static states are omitted.
    static let ticksPerFrame: [String: Int] = [
        "walking": 3,
        "eating": 4,
        "happy": 3,
        "sleeping": 10,
    ]

    /// Number of distinct animation frames per state. Static states are omitted.
    static let frameCounts: [String: Int] = [
        "walking": 3,
        "eating": 2,
        "happy": 2,
        "sleeping": 2,
    ]

    // MARK: - Lookups

    /// Returns the number of animation frames for a given display state.
    /// Static states (idle, sad, or unknown strings) return 1.
    static func frameCount(for state: String) -> Int {
        frameCounts[state] ?? 1
    }

    /// Returns the ticks-per-frame for a given display state,
    /// or nil for static states.
    static func ticksPerFrameValue(for state: String) -> Int? {
        ticksPerFrame[state]
    }

    /// Returns the total tick duration for one full animation cycle
    /// (frameCount × ticksPerFrame), or nil for static states.
    static func cycleDuration(for state: String) -> Int? {
        guard let tpf = ticksPerFrame[state],
              let fc = frameCounts[state] else { return nil }
        return tpf * fc
    }

    // MARK: - State Classification

    /// The set of display states that have multi-frame animation.
    static let animatedStates: Set<String> = Set(ticksPerFrame.keys)

    /// The set of known static (single-frame) display states.
    static let staticStates: Set<String> = ["idle", "sad"]

    // MARK: - Baby Fallback

    /// Returns the effective display state for a baby pig.
    ///
    /// Baby pigs have sprites for idle, walking, and sleeping only.
    /// States without baby sprites fall back to idle.
    static func babyFallbackState(for state: String) -> String {
        switch state {
        case "eating", "happy", "sad":
            return "idle"
        default:
            return state
        }
    }
}
