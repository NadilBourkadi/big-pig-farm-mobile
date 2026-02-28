/// PigPaletteTests — Tests for UIColorHex extension and PigPalettes color data.
/// Verifies hex parsing, palette completeness, lookup correctness, and
/// parity with the Python source (sprite_engine.py PALETTES dictionary).
import Testing
import UIKit
@testable import BigPigFarm

// MARK: - UIColor Hex Extension

@Test func hexParsingRedColor() {
    let color = UIColor(hex: "#FF0000")
    var red: CGFloat = 0; var green: CGFloat = 0; var blue: CGFloat = 0; var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    #expect(abs(red - 1.0) < 0.001)
    #expect(abs(green - 0.0) < 0.001)
    #expect(abs(blue - 0.0) < 0.001)
    #expect(abs(alpha - 1.0) < 0.001)
}

@Test func hexParsingWithoutHash() {
    let withHash = UIColor(hex: "#FF8700")
    let withoutHash = UIColor(hex: "FF8700")
    var red1: CGFloat = 0; var green1: CGFloat = 0; var blue1: CGFloat = 0; var alpha1: CGFloat = 0
    var red2: CGFloat = 0; var green2: CGFloat = 0; var blue2: CGFloat = 0; var alpha2: CGFloat = 0
    withHash.getRed(&red1, green: &green1, blue: &blue1, alpha: &alpha1)
    withoutHash.getRed(&red2, green: &green2, blue: &blue2, alpha: &alpha2)
    #expect(abs(red1 - red2) < 0.001)
    #expect(abs(green1 - green2) < 0.001)
    #expect(abs(blue1 - blue2) < 0.001)
}

@Test func hexParsingBlack() {
    let color = UIColor(hex: "#000000")
    var red: CGFloat = 0; var green: CGFloat = 0; var blue: CGFloat = 0; var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    #expect(abs(red) < 0.001)
    #expect(abs(green) < 0.001)
    #expect(abs(blue) < 0.001)
}

@Test func hexParsingWhite() {
    let color = UIColor(hex: "#ffffff")
    var red: CGFloat = 0; var green: CGFloat = 0; var blue: CGFloat = 0; var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    #expect(abs(red - 1.0) < 0.001)
    #expect(abs(green - 1.0) < 0.001)
    #expect(abs(blue - 1.0) < 0.001)
}

// MARK: - Palette Completeness

@Test func allBaseColorsPresent() {
    for baseColor in BaseColor.allCases {
        #expect(PigPalettes.palettes[baseColor] != nil, "Missing palette for \(baseColor)")
    }
    #expect(PigPalettes.palettes.count == BaseColor.allCases.count)
}

@Test func allKeysPerBaseColor() {
    for baseColor in BaseColor.allCases {
        guard let palette = PigPalettes.palettes[baseColor] else {
            Issue.record("No palette for \(baseColor)")
            continue
        }
        for key in PigPalettes.Key.allCases {
            #expect(palette[key] != nil, "\(baseColor) missing key \(key)")
        }
    }
}

@Test func paletteHexValuesAreValidFormat() {
    for (baseColor, palette) in PigPalettes.palettes {
        for (key, hex) in palette {
            #expect(
                hex.hasPrefix("#") && hex.count == 7,
                "\(baseColor).\(key): invalid hex format '\(hex)'"
            )
        }
    }
}

// MARK: - Lookup Function

@Test func knownLookupBlackFur() {
    // black.fur = #444444 → R=0x44/255, G=0x44/255, B=0x44/255
    let color = PigPalettes.color(for: .fur, baseColor: .black)
    var red: CGFloat = 0; var green: CGFloat = 0; var blue: CGFloat = 0; var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    let expected = CGFloat(0x44) / 255.0
    #expect(abs(red - expected) < 0.001)
    #expect(abs(green - expected) < 0.001)
    #expect(abs(blue - expected) < 0.001)
}

@Test func knownLookupSaffronFur() {
    // saffron.fur = #ff8700 → R=1.0, G=0x87/255, B=0
    let color = PigPalettes.color(for: .fur, baseColor: .saffron)
    var red: CGFloat = 0; var green: CGFloat = 0; var blue: CGFloat = 0; var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    #expect(abs(red - 1.0) < 0.001)
    #expect(abs(green - CGFloat(0x87) / 255.0) < 0.001)
    #expect(abs(blue - 0.0) < 0.001)
}

@Test func allLookupsReturnNonMagenta() {
    // If any entry is missing, color(for:baseColor:) returns .magenta — a debug failure.
    let magenta = UIColor.magenta
    var magentaRed: CGFloat = 0; var magentaGreen: CGFloat = 0
    var magentaBlue: CGFloat = 0; var magentaAlpha: CGFloat = 0
    magenta.getRed(&magentaRed, green: &magentaGreen, blue: &magentaBlue, alpha: &magentaAlpha)

    for baseColor in BaseColor.allCases {
        for key in PigPalettes.Key.allCases {
            let result = PigPalettes.color(for: key, baseColor: baseColor)
            var red: CGFloat = 0; var green: CGFloat = 0; var blue: CGFloat = 0; var alpha: CGFloat = 0
            result.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            let isMagenta = abs(red - magentaRed) < 0.001
                && abs(green - magentaGreen) < 0.001
                && abs(blue - magentaBlue) < 0.001
            #expect(!isMagenta, "\(baseColor).\(key) returned magenta fallback")
        }
    }
}

// MARK: - Cross-Color Invariants (parity with Python source)

@Test func sharedSlotsAreConsistentAcrossColors() {
    // pupil, eye, tooth, white are identical for all 8 base colors
    for baseColor in BaseColor.allCases {
        #expect(PigPalettes.palettes[baseColor]?[.pupil] == "#121212", "\(baseColor).pupil")
        #expect(PigPalettes.palettes[baseColor]?[.eye] == "#ffffff", "\(baseColor).eye")
        #expect(PigPalettes.palettes[baseColor]?[.tooth] == "#c0c0c0", "\(baseColor).tooth")
        #expect(PigPalettes.palettes[baseColor]?[.white] == "#d0d0d0", "\(baseColor).white")
    }
}

@Test func lilacTearDiffersFromRest() {
    // Lilac has a darker teal tear; all others share #05bce1
    #expect(PigPalettes.palettes[.lilac]?[.tear] == "#117d92")
    for baseColor in BaseColor.allCases where baseColor != .lilac {
        #expect(PigPalettes.palettes[baseColor]?[.tear] == "#05bce1", "\(baseColor).tear")
    }
}

@Test func spotCheckAllBaseColorFurValues() {
    let expectedFur: [BaseColor: String] = [
        .black: "#444444",
        .chocolate: "#875f00",
        .golden: "#ffd700",
        .cream: "#ffffaf",
        .blue: "#5fd7ff",
        .lilac: "#ffafff",
        .saffron: "#ff8700",
        .smoke: "#9e9e9e",
    ]
    for (baseColor, hex) in expectedFur {
        #expect(PigPalettes.palettes[baseColor]?[.fur] == hex, "\(baseColor).fur")
    }
}
