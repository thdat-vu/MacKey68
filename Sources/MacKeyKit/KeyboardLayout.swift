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
    /// Empty space that keeps rows aligned (no keycap is drawn).
    public let isSpacer: Bool

    public init(id: String, label: String, usage: UInt32, width: Double = 1, isSpacer: Bool = false) {
        self.id = id
        self.label = label
        self.usage = usage
        self.width = width
        self.isSpacer = isSpacer
    }

    public var isRemappable: Bool { usage != 0 }
}

public struct LayoutRow: Identifiable {
    public let id: Int
    public let keys: [LayoutKey]

    public var unitWidth: Double { keys.reduce(0) { $0 + $1.width } }
}

/// The board sizes the app can draw and map.
public enum LayoutID: String, CaseIterable, Codable, Identifiable {
    case k68 = "68"
    case tkl = "tkl"
    case full = "full"

    public var id: String { rawValue }

    /// "68", "TKL", "Full"
    public var shortName: String {
        switch self {
        case .k68: return "68"
        case .tkl: return "TKL"
        case .full: return "Full"
        }
    }

    public var displayName: String {
        switch self {
        case .k68: return "65% · 68 keys"
        case .tkl: return "TKL · 87 keys"
        case .full: return "Full-size · 104 keys"
        }
    }

    public var keyCount: Int {
        Set(Layouts.layout(for: self).keys.filter { !$0.isSpacer }.map(\.usage)).count
    }
}

public struct KeyboardLayout {
    public let id: LayoutID
    public let name: String
    public let unitCount: Double
    public let rows: [LayoutRow]

    public var keys: [LayoutKey] { rows.flatMap(\.keys) }

    public func key(usage: UInt32) -> LayoutKey? {
        keys.first { $0.usage == usage }
    }
}

public enum Layouts {
    public static var all: [KeyboardLayout] { [k68, tkl, full] }

    public static func layout(for id: LayoutID) -> KeyboardLayout {
        switch id {
        case .k68: return k68
        case .tkl: return tkl
        case .full: return full
        }
    }

    public static func layout(named name: String?) -> KeyboardLayout {
        guard let name, let id = LayoutID(rawValue: name.lowercased()) else { return tkl }
        return layout(for: id)
    }

    /// Best guess from the product string, brand/model names or the VID:PID.
    public static func detect(product: String,
                              manufacturer: String = "",
                              vendorID: Int?,
                              productID: Int?) -> LayoutID {
        if let vendorID, let productID {
            let key = String(format: "%04X:%04X", vendorID, productID)
            switch key {
            case "9AEA:1029": return .k68   // Ziyoulang K68
            case "0C45:7644": return .tkl   // Edra EK387 Pro (SONiX)
            default: break
            }
        }

        let text = "\(manufacturer) \(product)".lowercased()

        // Specific models first: "G915 TKL", "Keychron K8", ...
        for (needle, layout) in knownModels where text.contains(needle) {
            return layout
        }

        // Generic size hints.
        if text.contains("tkl") || text.contains("tenkeyless")
            || text.contains("87-key") || text.contains("87 key") {
            return .tkl
        }
        if text.contains("104") || text.contains("108")
            || text.contains("full-size") || text.contains("full size")
            || text.contains("100%") {
            return .full
        }
        if text.contains("65%") || text.contains("68-key") || text.contains("68 key")
            || text.contains("67-key") || text.contains("60%")
            || text.contains("61-key") || text.contains("61 key") {
            return .k68
        }
        if text.contains("75%") || text.contains("84-key") || text.contains("84 key") {
            return .tkl
        }

        if text.contains("k68") || text.contains("65%") {
            return .k68
        }
        if text.contains("ek387") {
            return .tkl
        }
        if text.contains("full") {
            return .full
        }
        // Unknown external keyboard: TKL is the most common shape and still
        // shows every key that matters for a Mac layout.
        return .tkl
    }

    /// Common retail boards. Longest/most specific patterns first.
    private static let knownModels: [(String, LayoutID)] = [
        // 65% / 68-key
        ("gmmk 2 65", .k68),
        ("keychron k6", .k68), ("keychron k7", .k68), ("keychron k12", .k68),
        ("keychron q2", .k68), ("keychron v2", .k68), ("keychron k9", .k68),
        ("akko 3068", .k68), ("akko 3061", .k68), ("akko mod005", .k68),
        ("akko mod 005", .k68),
        ("fl680", .k68), ("cmk68", .k68), ("fl-cmk68", .k68),
        ("rk68", .k68), ("rk61", .k68),
        ("huntsman mini", .k68), ("k65", .k68), ("k68", .k68),

        // TKL / 87-key (before generic model names that also contain "g915")
        ("g915 tkl", .tkl), ("g913 tkl", .tkl), ("g715 tkl", .tkl),
        ("keychron k8", .tkl), ("keychron q3", .tkl), ("keychron v3", .tkl),
        ("keychron c1", .tkl),
        ("akko 3087", .tkl), ("akko 5087", .tkl), ("akko cmk87", .tkl),
        ("akko 5075", .tkl), ("akko 3084", .tkl),
        ("fl750", .tkl), ("cmk87", .tkl), ("fl 87", .tkl),
        ("rk87", .tkl), ("rk84", .tkl),
        ("huntsman tkl", .tkl), ("blackwidow v3 tkl", .tkl), ("k70 tkl", .tkl),

        // Full-size / 104-key
        ("keychron k5", .full), ("keychron q6", .full), ("keychron v6", .full),
        ("keychron k10", .full), ("keychron c2", .full),
        ("akko 3108", .full), ("akko 5108", .full), ("akko 3098", .full),
        ("akko 5098", .full),
        ("fl104", .full), ("fl980", .full), ("cmk98", .full), ("cmk99", .full),
        ("rk100", .full), ("rk104", .full),
        ("g915", .full), ("g913", .full),
        ("blackwidow v3", .full), ("k70", .full), ("k95", .full),

        // Brand fallbacks
        ("keychron", .tkl), ("akko", .tkl), ("royal kludge", .tkl),
        ("fl-esports", .tkl), ("fl esports", .tkl),
    ]

    // MARK: - Layout builder

    private struct Builder {
        var nextID = 0

        mutating func key(_ label: String, _ usage: UInt32, _ width: Double = 1) -> LayoutKey {
            defer { nextID += 1 }
            return LayoutKey(id: "k\(nextID)", label: label, usage: usage, width: width)
        }

        mutating func gap(_ width: Double) -> LayoutKey {
            defer { nextID += 1 }
            return LayoutKey(id: "g\(nextID)", label: "", usage: 0, width: width, isSpacer: true)
        }

        func row(_ index: Int, _ keys: [LayoutKey]) -> LayoutRow {
            LayoutRow(id: index, keys: keys)
        }
    }

    /// 65% ANSI, 68 caps: bottom row Ctrl Win Alt [Space] Alt Fn Ctrl, arrow
    /// cluster and Del/PgUp/PgDn column on the right. Matches the Ziyoulang K68.
    public static let k68: KeyboardLayout = {
        var b = Builder()

        let top = b.row(0, [
            b.key("esc", 0x29),
            b.key("1", 0x1E), b.key("2", 0x1F), b.key("3", 0x20),
            b.key("4", 0x21), b.key("5", 0x22), b.key("6", 0x23),
            b.key("7", 0x24), b.key("8", 0x25), b.key("9", 0x26),
            b.key("0", 0x27),
            b.key("-", 0x2D), b.key("=", 0x2E),
            b.key("⌫", 0x2A, 2),
            b.key("del", 0x4C),
        ])
        let upper = b.row(1, [
            b.key("⇥", 0x2B, 1.5),
            b.key("Q", 0x14), b.key("W", 0x1A), b.key("E", 0x08),
            b.key("R", 0x15), b.key("T", 0x17), b.key("Y", 0x1C),
            b.key("U", 0x18), b.key("I", 0x0C), b.key("O", 0x12),
            b.key("P", 0x13),
            b.key("[", 0x2F), b.key("]", 0x30),
            b.key("\\", 0x31, 1.5),
            b.key("pgup", 0x4B),
        ])
        let home = b.row(2, [
            b.key("caps", 0x39, 1.75),
            b.key("A", 0x04), b.key("S", 0x16), b.key("D", 0x07),
            b.key("F", 0x09), b.key("G", 0x0A), b.key("H", 0x0B),
            b.key("J", 0x0D), b.key("K", 0x0E), b.key("L", 0x0F),
            b.key(";", 0x33), b.key("'", 0x34),
            b.key("⏎", 0x28, 2.25),
            b.key("pgdn", 0x4E),
        ])
        let lower = b.row(3, [
            b.key("⇧", 0xE1, 2.25),
            b.key("Z", 0x1D), b.key("X", 0x1B), b.key("C", 0x06),
            b.key("V", 0x19), b.key("B", 0x05), b.key("N", 0x11),
            b.key("M", 0x10),
            b.key(",", 0x36), b.key(".", 0x37), b.key("/", 0x38),
            b.key("⇧", 0xE5, 1.75),
            b.key("↑", 0x52),
            b.key("end", 0x4D),
        ])
        let bottom = b.row(4, [
            b.key("ctrl", 0xE0, 1.25),
            b.key("win", 0xE3, 1.25),
            b.key("alt", 0xE2, 1.25),
            b.key("", 0x2C, 6.25),
            b.key("alt", 0xE6),
            b.key("fn", 0),
            b.key("ctrl", 0xE4),
            b.key("←", 0x50),
            b.key("↓", 0x51),
            b.key("→", 0x4F),
        ])

        return KeyboardLayout(id: .k68, name: "K68",
                              unitCount: 16,
                              rows: [top, upper, home, lower, bottom])
    }()

    /// Tenkeyless ANSI: 87 keys, nav cluster and arrows, no numpad.
    public static let tkl: KeyboardLayout = {
        var b = Builder()

        var top: [LayoutKey] = [b.key("esc", 0x29)]
        for (index, code) in stride(from: 0x3A, through: 0x45, by: 1).enumerated() {
            top.append(b.key("F\(index + 1)", UInt32(code)))
        }
        top += [b.gap(2.25),
                b.key("prtsc", 0x46), b.key("scrlk", 0x47), b.key("pause", 0x48)]

        let numbers = b.row(5, [
            b.key("`", 0x35), b.key("1", 0x1E), b.key("2", 0x1F), b.key("3", 0x20),
            b.key("4", 0x21), b.key("5", 0x22), b.key("6", 0x23),
            b.key("7", 0x24), b.key("8", 0x25), b.key("9", 0x26),
            b.key("0", 0x27),
            b.key("-", 0x2D), b.key("=", 0x2E),
            b.key("⌫", 0x2A, 2),
            b.gap(3.25),
        ])

        let upper = b.row(1, [
            b.key("⇥", 0x2B, 1.5),
            b.key("Q", 0x14), b.key("W", 0x1A), b.key("E", 0x08),
            b.key("R", 0x15), b.key("T", 0x17), b.key("Y", 0x1C),
            b.key("U", 0x18), b.key("I", 0x0C), b.key("O", 0x12),
            b.key("P", 0x13),
            b.key("[", 0x2F), b.key("]", 0x30),
            b.key("\\", 0x31, 1.5),
            b.gap(0.25),
            b.key("ins", 0x49), b.key("home", 0x4A), b.key("pgup", 0x4B),
        ])
        let home = b.row(2, [
            b.key("caps", 0x39, 1.75),
            b.key("A", 0x04), b.key("S", 0x16), b.key("D", 0x07),
            b.key("F", 0x09), b.key("G", 0x0A), b.key("H", 0x0B),
            b.key("J", 0x0D), b.key("K", 0x0E), b.key("L", 0x0F),
            b.key(";", 0x33), b.key("'", 0x34),
            b.key("⏎", 0x28, 2.25),
            b.gap(0.25),
            b.key("del", 0x4C), b.key("end", 0x4D), b.key("pgdn", 0x4E),
        ])
        let lower = b.row(3, [
            b.key("⇧", 0xE1, 2.25),
            b.key("Z", 0x1D), b.key("X", 0x1B), b.key("C", 0x06),
            b.key("V", 0x19), b.key("B", 0x05), b.key("N", 0x11),
            b.key("M", 0x10),
            b.key(",", 0x36), b.key(".", 0x37), b.key("/", 0x38),
            b.key("⇧", 0xE5, 2.75),
            b.gap(0.25),
            b.gap(1), b.key("↑", 0x52), b.gap(1),
        ])
        let bottom = b.row(4, [
            b.key("ctrl", 0xE0, 1.25),
            b.key("win", 0xE3, 1.25),
            b.key("alt", 0xE2, 1.25),
            b.key("", 0x2C, 6.25),
            b.key("alt", 0xE6, 1.25),
            b.key("win", 0xE7, 1.25),
            b.key("menu", 0x65, 1.25),
            b.key("ctrl", 0xE4, 1.25),
            b.gap(0.25),
            b.key("←", 0x50), b.key("↓", 0x51), b.key("→", 0x4F),
        ])

        return KeyboardLayout(id: .tkl, name: "TKL",
                              unitCount: 18.25,
                              rows: [b.row(0, top), numbers, upper, home, lower, bottom])
    }()

    /// Full-size ANSI: 104 keys, TKL plus the numpad.
    public static let full: KeyboardLayout = {
        var b = Builder()

        var top: [LayoutKey] = [b.key("esc", 0x29)]
        for (index, code) in stride(from: 0x3A, through: 0x45, by: 1).enumerated() {
            top.append(b.key("F\(index + 1)", UInt32(code)))
        }
        top += [b.gap(2.25),
                b.key("prtsc", 0x46), b.key("scrlk", 0x47), b.key("pause", 0x48),
                b.gap(0.25),
                b.key("num", 0x53), b.key("/", 0x54), b.key("*", 0x55), b.key("-", 0x56)]

        let numbers = b.row(5, [
            b.key("`", 0x35), b.key("1", 0x1E), b.key("2", 0x1F), b.key("3", 0x20),
            b.key("4", 0x21), b.key("5", 0x22), b.key("6", 0x23),
            b.key("7", 0x24), b.key("8", 0x25), b.key("9", 0x26),
            b.key("0", 0x27),
            b.key("-", 0x2D), b.key("=", 0x2E),
            b.key("⌫", 0x2A, 2),
            b.gap(0.25), b.gap(3), b.gap(0.25),
            b.key("7", 0x5F), b.key("8", 0x60), b.key("9", 0x61), b.key("+", 0x57),
        ])

        let upper = b.row(1, [
            b.key("⇥", 0x2B, 1.5),
            b.key("Q", 0x14), b.key("W", 0x1A), b.key("E", 0x08),
            b.key("R", 0x15), b.key("T", 0x17), b.key("Y", 0x1C),
            b.key("U", 0x18), b.key("I", 0x0C), b.key("O", 0x12),
            b.key("P", 0x13),
            b.key("[", 0x2F), b.key("]", 0x30),
            b.key("\\", 0x31, 1.5),
            b.gap(0.25),
            b.key("ins", 0x49), b.key("home", 0x4A), b.key("pgup", 0x4B),
            b.gap(0.25),
            b.key("4", 0x5C), b.key("5", 0x5D), b.key("6", 0x5E), b.key("+", 0x57),
        ])
        let home = b.row(2, [
            b.key("caps", 0x39, 1.75),
            b.key("A", 0x04), b.key("S", 0x16), b.key("D", 0x07),
            b.key("F", 0x09), b.key("G", 0x0A), b.key("H", 0x0B),
            b.key("J", 0x0D), b.key("K", 0x0E), b.key("L", 0x0F),
            b.key(";", 0x33), b.key("'", 0x34),
            b.key("⏎", 0x28, 2.25),
            b.gap(0.25),
            b.key("del", 0x4C), b.key("end", 0x4D), b.key("pgdn", 0x4E),
            b.gap(0.25),
            b.key("1", 0x59), b.key("2", 0x5A), b.key("3", 0x5B), b.key("⏎", 0x58),
        ])
        let lower = b.row(3, [
            b.key("⇧", 0xE1, 2.25),
            b.key("Z", 0x1D), b.key("X", 0x1B), b.key("C", 0x06),
            b.key("V", 0x19), b.key("B", 0x05), b.key("N", 0x11),
            b.key("M", 0x10),
            b.key(",", 0x36), b.key(".", 0x37), b.key("/", 0x38),
            b.key("⇧", 0xE5, 2.75),
            b.gap(0.25),
            b.gap(1), b.key("↑", 0x52), b.gap(1),
            b.gap(0.25),
            b.key("0", 0x62, 2), b.key(".", 0x63), b.key("⏎", 0x58),
        ])
        let bottom = b.row(4, [
            b.key("ctrl", 0xE0, 1.25),
            b.key("win", 0xE3, 1.25),
            b.key("alt", 0xE2, 1.25),
            b.key("", 0x2C, 6.25),
            b.key("alt", 0xE6, 1.25),
            b.key("win", 0xE7, 1.25),
            b.key("menu", 0x65, 1.25),
            b.key("ctrl", 0xE4, 1.25),
            b.gap(0.25),
            b.key("←", 0x50), b.key("↓", 0x51), b.key("→", 0x4F),
            b.gap(4.25),
        ])

        return KeyboardLayout(id: .full, name: "Full",
                              unitCount: 22.5,
                              rows: [b.row(0, top), numbers, upper, home, lower, bottom])
    }()
}
