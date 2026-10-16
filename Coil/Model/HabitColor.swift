import SwiftUI

/// The fixed palette habits can choose from. Stored as an index so it syncs compactly.
nonisolated struct HabitColor: Hashable, Identifiable {
    let index: Int

    init(index: Int) {
        self.index = HabitColor.palette.indices.contains(index) ? index : HabitColor.defaultIndex
    }

    var id: Int { index }

    static let defaultIndex = 10

    static let all: [HabitColor] = palette.indices.map(HabitColor.init(index:))

    var color: Color { Color(hex: HabitColor.palette[index].hex) }

    var name: LocalizedStringResource { HabitColor.palette[index].name }

    private static let palette: [(hex: UInt32, name: LocalizedStringResource)] = [
        (0xFF3B30, "Red"),
        (0xFF6A33, "Coral"),
        (0xFF9500, "Orange"),
        (0xFFB300, "Amber"),
        (0xF2C500, "Yellow"),
        (0x9CC23A, "Lime"),
        (0x34C759, "Green"),
        (0x00BFA5, "Mint"),
        (0x30B0C7, "Teal"),
        (0x32ADE6, "Cyan"),
        (0x007AFF, "Blue"),
        (0x5856D6, "Indigo"),
        (0xAF52DE, "Purple"),
        (0xD63AC8, "Magenta"),
        (0xFF2D55, "Pink"),
        (0xFF6482, "Rose"),
        (0xA2845E, "Brown"),
        (0xC8A06E, "Sand"),
        (0x6E7F8D, "Slate"),
        (0x8E8E93, "Graphite"),
    ]
}

nonisolated extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
