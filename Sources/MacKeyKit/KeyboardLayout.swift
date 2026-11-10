// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// One physical keycap on the drawn board.
public struct LayoutKey: Identifiable, Equatable {
    public let id: String
    /// What is printed on the cap.
    public let label: String
    /// Usage the key sends by default. 0 means "not remappable" (Fn).
    public let usage: UInt32
    /// Width in key units.
    public let width: Double

    public var isRemappable: Bool { usage != 0 }
}

public struct LayoutRow: Identifiable {
    public let id: Int
    public let keys: [LayoutKey]
}

public struct KeyboardLayout {
    public let name: String
    public let unitCount: Double
    public let rows: [LayoutRow]

    public var keys: [LayoutKey] { rows.flatMap(\.keys) }

    public func key(usage: UInt32) -> LayoutKey? {
        keys.first { $0.usage == usage }
    }
}

public enum Layouts {
    /// 65% ANSI, 67 caps: hàng dưới Ctrl Win Alt [Space] Alt Fn Ctrl, cụm mũi tên
    /// bên phải, cột Del/PgUp/PgDn. Đúng kiểu Ziyoulang/EWEADN K68.
    public static let k68: KeyboardLayout = {
        func key(_ row: Int, _ column: Int, _ label: String, _ usage: UInt32, _ width: Double = 1) -> LayoutKey {
            LayoutKey(id: "r\(row)c\(column)", label: label, usage: usage, width: width)
        }

        let top: [LayoutKey] = [
            key(0, 0, "esc", 0x29),
            key(0, 1, "1", 0x1E), key(0, 2, "2", 0x1F), key(0, 3, "3", 0x20),
            key(0, 4, "4", 0x21), key(0, 5, "5", 0x22), key(0, 6, "6", 0x23),
            key(0, 7, "7", 0x24), key(0, 8, "8", 0x25), key(0, 9, "9", 0x26),
            key(0, 10, "0", 0x27),
            key(0, 11, "-", 0x2D), key(0, 12, "=", 0x2E),
            key(0, 13, "⌫", 0x2A, 2),
            key(0, 14, "del", 0x4C),
        ]
        let upper: [LayoutKey] = [
            key(1, 0, "⇥", 0x2B, 1.5),
            key(1, 1, "Q", 0x14), key(1, 2, "W", 0x1A), key(1, 3, "E", 0x08),
            key(1, 4, "R", 0x15), key(1, 5, "T", 0x17), key(1, 6, "Y", 0x1C),
            key(1, 7, "U", 0x18), key(1, 8, "I", 0x0C), key(1, 9, "O", 0x12),
            key(1, 10, "P", 0x13),
            key(1, 11, "[", 0x2F), key(1, 12, "]", 0x30),
            key(1, 13, "\\", 0x31, 1.5),
            key(1, 14, "pgup", 0x4B),
        ]
        let home: [LayoutKey] = [
            key(2, 0, "caps", 0x39, 1.75),
            key(2, 1, "A", 0x04), key(2, 2, "S", 0x16), key(2, 3, "D", 0x07),
            key(2, 4, "F", 0x09), key(2, 5, "G", 0x0A), key(2, 6, "H", 0x0B),
            key(2, 7, "J", 0x0D), key(2, 8, "K", 0x0E), key(2, 9, "L", 0x0F),
            key(2, 10, ";", 0x33), key(2, 11, "'", 0x34),
            key(2, 12, "⏎", 0x28, 2.25),
            key(2, 13, "pgdn", 0x4E),
        ]
        let lower: [LayoutKey] = [
            key(3, 0, "⇧", 0xE1, 2.25),
            key(3, 1, "Z", 0x1D), key(3, 2, "X", 0x1B), key(3, 3, "C", 0x06),
            key(3, 4, "V", 0x19), key(3, 5, "B", 0x05), key(3, 6, "N", 0x11),
            key(3, 7, "M", 0x10),
            key(3, 8, ",", 0x36), key(3, 9, ".", 0x37), key(3, 10, "/", 0x38),
            key(3, 11, "⇧", 0xE5, 1.75),
            key(3, 12, "↑", 0x52),
            key(3, 13, "end", 0x4D),
        ]
        let bottom: [LayoutKey] = [
            key(4, 0, "ctrl", 0xE0, 1.25),
            key(4, 1, "win", 0xE3, 1.25),
            key(4, 2, "alt", 0xE2, 1.25),
            key(4, 3, "", 0x2C, 6.25),
            key(4, 4, "alt", 0xE6),
            key(4, 5, "fn", 0),
            key(4, 6, "ctrl", 0xE4),
            key(4, 7, "←", 0x50),
            key(4, 8, "↓", 0x51),
            key(4, 9, "→", 0x4F),
        ]

        return KeyboardLayout(
            name: "K68",
            unitCount: 16,
            rows: [top, upper, home, lower, bottom].enumerated().map { LayoutRow(id: $0.offset, keys: $0.element) }
        )
    }()
}
