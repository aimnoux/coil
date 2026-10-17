import SwiftUI
import UIKit

/// The fixed palette habits can choose from. Stored as an index so it syncs compactly.
///
/// The palette is soft and muted. Each color has two shades:
/// - `color` — the pastel itself, for fills, rings and chart areas;
/// - `ink` — a deeper shade for text and thin lines on light backgrounds (in dark mode it is the
///   pastel itself, which already reads well on black).
nonisolated struct HabitColor: Hashable, Identifiable {
    let index: Int

    init(index: Int) {
        self.index = HabitColor.palette.indices.contains(index) ? index : HabitColor.defaultIndex
    }

    var id: Int { index }

    static let defaultIndex = 10

    static let all: [HabitColor] = palette.indices.map(HabitColor.init(index:))

    var color: Color { Color(hex: HabitColor.palette[index].hex) }

    var ink: Color {
        let hex = HabitColor.palette[index].hex
        return Color(UIColor { traits in
            let pastel = UIColor(hex: hex)
            return traits.userInterfaceStyle == .dark ? pastel : pastel.deepened()
        })
    }

    var name: LocalizedStringResource { HabitColor.palette[index].name }

    private static let palette: [(hex: UInt32, name: LocalizedStringResource)] = [
        (0xE48C8C, "Red"),
        (0xEDA088, "Coral"),
        (0xEDAE78, "Orange"),
        (0xE6C07C, "Amber"),
        (0xDDCB7E, "Yellow"),
        (0xB5C98A, "Lime"),
        (0x93C4A0, "Green"),
        (0x86C6B6, "Mint"),
        (0x80B9C4, "Teal"),
        (0x8DB8DE, "Cyan"),
        (0x93A8E2, "Blue"),
        (0xA39FDF, "Indigo"),
        (0xBBA3DD, "Purple"),
        (0xD3A2D2, "Magenta"),
        (0xE79CB3, "Pink"),
        (0xE6AFB7, "Rose"),
        (0xBBA08C, "Brown"),
        (0xCDB89E, "Sand"),
        (0x99A8B4, "Slate"),
        (0xA8A8B0, "Graphite"),
    ]
}

nonisolated extension Color {
    /// Coil's muted lavender accent; widgets use it because they don't get the app's AccentColor asset.
    static let coilAccent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xA4B0EB) : UIColor(hex: 0x7682C4)
    })

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

nonisolated extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    /// A darker, slightly richer shade that stays readable as text on white.
    func deepened() -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: min(1, s * 1.35 + 0.08), brightness: b * 0.62, alpha: a)
    }
}
