import UIKit

/// Centralized accessor for the system Reduce Motion accessibility setting.
///
/// SwiftUI views can use `@Environment(\.accessibilityReduceMotion)` directly,
/// but SpriteKit code (which is not a SwiftUI View) reads this namespace
/// instead. This mirrors the existing pattern in `FarmScene+Accessibility.swift`
/// of reading `UIAccessibility.isVoiceOverRunning` directly from scene code.
///
/// `overrideForTesting` lets tests inject a value, since `UIAccessibility`
/// flags are read-only and platform-controlled.
enum MotionSettings {
    /// Test-only override. When non-nil, `isReduced` returns this instead of
    /// reading the system value. Tests must reset to `nil` in teardown.
    @MainActor
    static var overrideForTesting: Bool?

    /// True when motion should be reduced or eliminated for accessibility.
    /// Reads the system `UIAccessibility.isReduceMotionEnabled` unless a
    /// test override is active.
    @MainActor
    static var isReduced: Bool {
        overrideForTesting ?? UIAccessibility.isReduceMotionEnabled
    }
}
