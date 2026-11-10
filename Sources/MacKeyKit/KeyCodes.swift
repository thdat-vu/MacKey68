// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// HID keyboard usages (usage page 0x07) and human friendly names for them.
public enum KeyCodes {
    public static let keyboardPage: UInt32 = 0x07

    /// hidutil expects usages in the 0x700000000 namespace.
    public static func usage(_ code: UInt32) -> UInt64 { 0x7_0000_0000 | UInt64(code) }

    /// Canonical name for a usage code, if known.
    public static func name(for code: UInt32) -> String? {
        canonical[code]
    }

    /// Resolve a user supplied key name ("caps", "LeftGUI", "0x39", ...) to a usage code.
    public static func code(for name: String) -> UInt32? {
        let key = normalize(name)
        if key.hasPrefix("0x"), let value = UInt32(key.dropFirst(2), radix: 16) {
            return value
        }
        if let hit = aliases[key] {
            return hit
        }
        return nil
    }

    /// A sorted list of canonical names, useful for help output.
    public static var allNames: [String] {
        canonical.sorted { $0.key < $1.key }.map(\.value)
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased()
            .filter { !" -_".contains($0) }
    }

    private static let canonical: [UInt32: String] = [
        0x04: "A", 0x05: "B", 0x06: "C", 0x07: "D", 0x08: "E", 0x09: "F",
        0x0A: "G", 0x0B: "H", 0x0C: "I", 0x0D: "J", 0x0E: "K", 0x0F: "L",
        0x10: "M", 0x11: "N", 0x12: "O", 0x13: "P", 0x14: "Q", 0x15: "R",
        0x16: "S", 0x17: "T", 0x18: "U", 0x19: "V", 0x1A: "W", 0x1B: "X",
        0x1C: "Y", 0x1D: "Z",
        0x1E: "1", 0x1F: "2", 0x20: "3", 0x21: "4", 0x22: "5", 0x23: "6",
        0x24: "7", 0x25: "8", 0x26: "9", 0x27: "0",
        0x28: "Return", 0x29: "Escape", 0x2A: "Delete", 0x2B: "Tab",
        0x2C: "Space", 0x2D: "Minus", 0x2E: "Equal", 0x2F: "LeftBracket",
        0x30: "RightBracket", 0x31: "Backslash", 0x32: "NonUSHash",
        0x33: "Semicolon", 0x34: "Quote", 0x35: "Grave", 0x36: "Comma",
        0x37: "Period", 0x38: "Slash", 0x39: "CapsLock",
        0x3A: "F1", 0x3B: "F2", 0x3C: "F3", 0x3D: "F4", 0x3E: "F5",
        0x3F: "F6", 0x40: "F7", 0x41: "F8", 0x42: "F9", 0x43: "F10",
        0x44: "F11", 0x45: "F12",
        0x46: "PrintScreen", 0x47: "ScrollLock", 0x48: "Pause",
        0x49: "Insert", 0x4A: "Home", 0x4B: "PageUp", 0x4C: "ForwardDelete",
        0x4D: "End", 0x4E: "PageDown", 0x4F: "RightArrow", 0x50: "LeftArrow",
        0x51: "DownArrow", 0x52: "UpArrow",
        0x53: "NumLock", 0x54: "KeypadSlash", 0x55: "KeypadAsterisk",
        0x56: "KeypadMinus", 0x57: "KeypadPlus", 0x58: "KeypadEnter",
        0x59: "Keypad1", 0x5A: "Keypad2", 0x5B: "Keypad3", 0x5C: "Keypad4",
        0x5D: "Keypad5", 0x5E: "Keypad6", 0x5F: "Keypad7", 0x60: "Keypad8",
        0x61: "Keypad9", 0x62: "Keypad0", 0x63: "KeypadPeriod",
        0x64: "NonUSBackslash", 0x65: "Application", 0x66: "Power",
        0x67: "KeypadEqual",
        0x68: "F13", 0x69: "F14", 0x6A: "F15", 0x6B: "F16", 0x6C: "F17",
        0x6D: "F18", 0x6E: "F19", 0x6F: "F20",
        0xE0: "LeftControl", 0xE1: "LeftShift", 0xE2: "LeftAlt", 0xE3: "LeftGUI",
        0xE4: "RightControl", 0xE5: "RightShift", 0xE6: "RightAlt", 0xE7: "RightGUI",
    ]

    private static let aliases: [String: UInt32] = {
        var table: [String: UInt32] = [:]

        func add(_ names: [String], _ code: UInt32) {
            for name in names { table[normalize(name)] = code }
        }

        // Canonical names are always valid input.
        for (code, name) in canonical { table[normalize(name)] = code }

        add(["Enter", "Return"], 0x28)
        add(["Esc", "Escape"], 0x29)
        add(["Backspace", "BackSpace"], 0x2A)
        add(["Tab", "Tabulator"], 0x2B)
        add(["Space", "Spacebar"], 0x2C)
        add(["Backtick", "Tilde", "Grave", "`"], 0x35)
        add(["CapsLock", "Caps", "Capslock"], 0x39)
        add(["ForwardDelete", "Del", "DeleteForward"], 0x4C)
        add(["Left", "LeftArrow", "ArrowLeft"], 0x50)
        add(["Right", "RightArrow", "ArrowRight"], 0x4F)
        add(["Up", "UpArrow", "ArrowUp"], 0x52)
        add(["Down", "DownArrow", "ArrowDown"], 0x51)

        // Modifiers, written the way people actually say them.
        add(["Ctrl", "Control", "LeftCtrl", "LeftControl"], 0xE0)
        add(["Cmd", "Command", "LeftCmd", "LeftCommand", "Win", "Super", "LeftWin", "LeftGUI"], 0xE3)
        add(["Opt", "Option", "Alt", "LeftAlt", "LeftOption"], 0xE2)
        add(["Shift", "LeftShift"], 0xE1)

        add(["RightCtrl", "RightControl"], 0xE4)
        add(["RightShift"], 0xE5)
        add(["RightOpt", "RightOption", "RightAlt", "AltGr"], 0xE6)
        add(["RightCmd", "RightCommand", "RightWin", "RightGUI"], 0xE7)

        return table
    }()
}
