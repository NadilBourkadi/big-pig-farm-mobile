/// UIColorHex — UIColor convenience initializer for hex color strings.
/// Used by PigPalettes and any future color data files.
import UIKit

extension UIColor {
    /// Initialize from a 6-digit hex color string, with or without a leading `#`.
    /// Example: `UIColor(hex: "#FF8700")` or `UIColor(hex: "FF8700")`
    /// - Note: Expects a 6-digit hex string. Malformed input (wrong length or
    ///   non-hex characters) silently produces black. All callers in this codebase
    ///   use hardcoded, pre-validated hex strings; validate externally if that ever changes.
    convenience init(hex: String) {
        let stripped = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: stripped).scanHexInt64(&rgb)
        let red   = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let green = CGFloat((rgb >> 8)  & 0xFF) / 255.0
        let blue  = CGFloat( rgb        & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
