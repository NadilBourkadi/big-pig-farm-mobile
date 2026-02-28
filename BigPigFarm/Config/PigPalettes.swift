/// PigPalettes — Color palette data for all 8 base coat colors.
/// Maps from: big_pig_farm/data/sprite_engine.py (PALETTES dictionary).
/// Consumed by PatternRenderer for pattern compositing.
import UIKit

/// Namespace for pig coat color palette data.
///
/// Each base color has 13 named palette slots covering fur tones,
/// facial features, and accent colors. Used to look up `UIColor`
/// values when compositing pattern overlays onto base-color sprites.
enum PigPalettes {

    // MARK: - Key

    /// Named palette slots for pig sprite pixels.
    /// Raw values match the Python PALETTES dictionary keys exactly.
    enum Key: String, CaseIterable, Sendable {
        case fur, shade, dark, belly
        case pupil, eye, nose, ear, paw, tooth
        case white, blush, tear
    }

    // MARK: - Palette Data

    /// Hex color strings for each palette slot, keyed by base color.
    /// Verified against big_pig_farm/data/sprite_engine.py lines 152–281.
    static let palettes: [BaseColor: [Key: String]] = [
        .black: [
            .fur: "#444444", .shade: "#3a3a3a", .dark: "#262626", .belly: "#585858",
            .pupil: "#121212", .eye: "#ffffff", .nose: "#808080", .ear: "#4e4e4e",
            .paw: "#303030", .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#d75f5f",
            .tear: "#05bce1",
        ],
        .chocolate: [
            .fur: "#875f00", .shade: "#8b4a00", .dark: "#870000", .belly: "#ffaf5f",
            .pupil: "#121212", .eye: "#ffffff", .nose: "#af8787", .ear: "#d75f5f",
            .paw: "#d75f00", .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#ff8787",
            .tear: "#05bce1",
        ],
        .golden: [
            .fur: "#ffd700", .shade: "#d4a800", .dark: "#af8700", .belly: "#ffff5f",
            .pupil: "#121212", .eye: "#ffffff", .nose: "#d7af87", .ear: "#d7af00",
            .paw: "#af8700", .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#ff8787",
            .tear: "#05bce1",
        ],
        .cream: [
            .fur: "#ffffaf", .shade: "#e6d0a8", .dark: "#d7af87", .belly: "#ffffd7",
            .pupil: "#121212", .eye: "#ffffff", .nose: "#ffd7d7", .ear: "#ffd7af",
            .paw: "#d7af87", .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#ff5fd7",
            .tear: "#05bce1",
        ],
        .blue: [
            .fur: "#5fd7ff", .shade: "#5a7a9a", .dark: "#3a5a7a", .belly: "#afafff",
            .pupil: "#121212", .eye: "#ffffff", .nose: "#8a9aaa", .ear: "#6a8aaa",
            .paw: "#4a6a8a", .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#d75f5f",
            .tear: "#05bce1",
        ],
        .lilac: [
            .fur: "#ffafff", .shade: "#b888c8", .dark: "#8a60a0", .belly: "#e8c8f8",
            .pupil: "#121212", .eye: "#ffffff", .nose: "#c8a8d8", .ear: "#b090c0",
            .paw: "#9070a8", .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#ff5fd7",
            .tear: "#117d92",
        ],
        .saffron: [
            .fur: "#ff8700", .shade: "#c87830", .dark: "#a06020", .belly: "#e8a050",
            .pupil: "#121212", .eye: "#ffffff", .nose: "#d09060", .ear: "#c08040",
            .paw: "#b07838", .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#ff8787",
            .tear: "#05bce1",
        ],
        .smoke: [
            .fur: "#9e9e9e", .shade: "#787878", .dark: "#606060", .belly: "#a0a0a0",
            .pupil: "#121212", .eye: "#ffffff", .nose: "#988890", .ear: "#908088",
            .paw: "#808080", .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#ff5fd7",
            .tear: "#05bce1",
        ],
    ]

    // MARK: - Lookup

    /// Returns the UIColor for a palette slot and base color.
    /// Falls back to `.magenta` for any missing entry — a visible debug signal.
    static func color(for key: Key, baseColor: BaseColor) -> UIColor {
        guard let hex = palettes[baseColor]?[key] else {
            return .magenta
        }
        return UIColor(hex: hex)
    }
}
