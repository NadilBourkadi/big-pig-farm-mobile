/// StatusBadgeContrastTests — Verify tinted StatusBadge colors meet WCAG AA contrast.
///
/// WCAG AA requires ≥ 4.5:1 contrast ratio for normal-size text.
/// The .tinted style uses the badge color as text against a 0.2-opacity
/// background of the same color composited over white. All three tinted
/// badge colors (blue, green, purple) must pass after darkening.
import Testing
import SwiftUI
import UIKit
@testable import BigPigFarm

// MARK: - RGB Helper

/// sRGB components extracted from a SwiftUI Color for contrast calculations.
private struct RGB {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    init(_ color: Color, style: UIUserInterfaceStyle = .light) {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let resolved = UIColor(color).resolvedColor(with: traits)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// WCAG 2.0 relative luminance.
    var luminance: CGFloat {
        func linearize(_ channel: CGFloat) -> CGFloat {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }

    /// Composite this color at given opacity over white.
    func compositedOverWhite(opacity: CGFloat) -> Self {
        Self(
            red: red * opacity + (1 - opacity),
            green: green * opacity + (1 - opacity),
            blue: blue * opacity + (1 - opacity)
        )
    }

    /// WCAG 2.0 contrast ratio against another RGB value.
    func contrastRatio(against other: Self) -> CGFloat {
        let lighter = max(luminance, other.luminance)
        let darker = min(luminance, other.luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

// MARK: - Tests

struct StatusBadgeContrastTests {

    private static func tintedBadgeContrastRatio(_ color: Color) -> CGFloat {
        let textRGB = RGB(color.darkenedForTintedBadge(scheme: .light))
        let bgRGB = RGB(color).compositedOverWhite(opacity: 0.2)
        return textRGB.contrastRatio(against: bgRGB)
    }

    // MARK: - Contrast Compliance

    @Test func blueTintedBadgePassesWCAGAA() {
        let ratio = Self.tintedBadgeContrastRatio(.blue)
        #expect(ratio >= 4.5)
    }

    @Test func greenTintedBadgePassesWCAGAA() {
        let ratio = Self.tintedBadgeContrastRatio(.green)
        #expect(ratio >= 4.5)
    }

    @Test func purpleTintedBadgePassesWCAGAA() {
        let ratio = Self.tintedBadgeContrastRatio(.purple)
        #expect(ratio >= 4.5)
    }

    // MARK: - Behavior

    @Test func darkModeSkipsDarkening() {
        let darkRGB = RGB(Color.blue.darkenedForTintedBadge(scheme: .dark))
        let lightRGB = RGB(Color.blue.darkenedForTintedBadge(scheme: .light))
        #expect(darkRGB.luminance > lightRGB.luminance)
    }

    @Test func darkeningReducesLuminance() {
        let origLuminance = RGB(Color.green).luminance
        let darkLuminance = RGB(Color.green.darkenedForTintedBadge(scheme: .light)).luminance
        #expect(darkLuminance < origLuminance)
    }
}
