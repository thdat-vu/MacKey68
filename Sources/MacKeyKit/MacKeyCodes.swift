// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import CoreGraphics

/// macOS virtual keycodes used by CGEventTap. HID usages (what hidutil and the
/// config use) are a different numbering; this table bridges the two worlds.
public enum MacKeyCodes {
    public static func code(for name: String) -> CGKeyCode? {
        table[normalize(name)]
    }

    public static func name(for code: CGKeyCode) -> String? {
        inverse[code]
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased().filter { !" -_".contains($0) }
    }

    private static let table: [String: CGKeyCode] = {
        var map: [String: CGKeyCode] = [:]
        func add(_ name: String, _ code: CGKeyCode) {
            map[normalize(name)] = code
        }

        add("A", 0x00); add("S", 0x01); add("D", 0x02); add("F", 0x03)
        add("H", 0x04); add("G", 0x05); add("Z", 0x06); add("X", 0x07)
        add("C", 0x08); add("V", 0x09); add("B", 0x0B); add("Q", 0x0C)
        add("W", 0x0D); add("E", 0x0E); add("R", 0x0F); add("Y", 0x10)
        add("T", 0x11); add("1", 0x12); add("2", 0x13); add("3", 0x14)
        add("4", 0x15); add("6", 0x16); add("5", 0x17); add("Equal", 0x18)
        add("9", 0x19); add("7", 0x1A); add("Minus", 0x1B); add("8", 0x1C)
        add("0", 0x1D); add("RightBracket", 0x1E); add("O", 0x1F)
        add("U", 0x20); add("LeftBracket", 0x21); add("I", 0x22); add("P", 0x23)
        add("Return", 0x24); add("Enter", 0x24); add("L", 0x25); add("J", 0x26)
        add("Quote", 0x27); add("K", 0x28); add("Semicolon", 0x29)
        add("Backslash", 0x2A); add("Comma", 0x2B); add("Slash", 0x2C)
        add("N", 0x2D); add("M", 0x2E); add("Period", 0x2F); add("Tab", 0x30)
        add("Space", 0x31); add("Grave", 0x32); add("Backtick", 0x32)
        add("Delete", 0x33); add("Backspace", 0x33); add("Escape", 0x35)
        add("Esc", 0x35); add("RightGUI", 0x36); add("RightCommand", 0x36)
        add("LeftGUI", 0x37); add("LeftCommand", 0x37); add("Cmd", 0x37)
        add("LeftShift", 0x38); add("Shift", 0x38); add("CapsLock", 0x39)
        add("Caps", 0x39); add("LeftAlt", 0x3A); add("LeftOption", 0x3A)
        add("LeftControl", 0x3B); add("LeftCtrl", 0x3B)
        add("RightShift", 0x3C); add("RightAlt", 0x3D); add("RightOption", 0x3D)
        add("RightControl", 0x3E); add("RightCtrl", 0x3E)
        add("F17", 0x40); add("KeypadDecimal", 0x41); add("KeypadMultiply", 0x43)
        add("KeypadPlus", 0x45); add("KeypadClear", 0x47); add("VolumeUp", 0x48)
        add("VolumeDown", 0x49); add("VolumeMute", 0x4A); add("KeypadDivide", 0x4B)
        add("KeypadEnter", 0x4C); add("KeypadMinus", 0x4E); add("F18", 0x4F)
        add("F19", 0x50); add("KeypadEquals", 0x51); add("Keypad0", 0x52)
        add("Keypad1", 0x53); add("Keypad2", 0x54); add("Keypad3", 0x55)
        add("Keypad4", 0x56); add("Keypad5", 0x57); add("Keypad6", 0x58)
        add("Keypad7", 0x59); add("F20", 0x5A); add("Keypad8", 0x5B)
        add("Keypad9", 0x5C); add("F5", 0x60); add("F6", 0x61); add("F7", 0x62)
        add("F3", 0x63); add("F8", 0x64); add("F9", 0x65); add("F11", 0x67)
        add("F13", 0x69); add("F16", 0x6A); add("F14", 0x6B); add("F10", 0x6D)
        add("F12", 0x6F); add("F15", 0x71); add("Help", 0x72); add("Insert", 0x72)
        add("Home", 0x73); add("PageUp", 0x74); add("ForwardDelete", 0x75)
        add("F4", 0x76); add("End", 0x77); add("F2", 0x78); add("PageDown", 0x79)
        add("F1", 0x7A); add("LeftArrow", 0x7B); add("Left", 0x7B)
        add("RightArrow", 0x7C); add("Right", 0x7C); add("DownArrow", 0x7D)
        add("Down", 0x7D); add("UpArrow", 0x7E); add("Up", 0x7E)

        return map
    }()

    private static let inverse: [CGKeyCode: String] = {
        var map: [CGKeyCode: String] = [:]
        for (name, code) in table where map[code] == nil {
            // Prefer the canonical name used by the config.
            let canonical = [
                0x18: "Equal", 0x1B: "Minus", 0x1E: "RightBracket",
                0x21: "LeftBracket", 0x24: "Return", 0x27: "Quote",
                0x29: "Semicolon", 0x2A: "Backslash", 0x2B: "Comma",
                0x2C: "Slash", 0x2F: "Period", 0x32: "Grave",
                0x33: "Delete", 0x35: "Escape", 0x36: "RightGUI",
                0x37: "LeftGUI", 0x38: "LeftShift", 0x39: "CapsLock",
                0x3A: "LeftAlt", 0x3B: "LeftControl", 0x3C: "RightShift",
                0x3D: "RightAlt", 0x3E: "RightControl", 0x73: "Home",
                0x74: "PageUp", 0x75: "ForwardDelete", 0x77: "End",
                0x79: "PageDown", 0x7B: "LeftArrow", 0x7C: "RightArrow",
                0x7D: "DownArrow", 0x7E: "UpArrow",
            ][code]
            map[code] = canonical ?? name
        }
        return map
    }()
}
