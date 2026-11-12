// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import MacKeyKit

struct ProfilePreset: Identifiable {
    let id: String
    let title: String
    let detailVI: String
    let detailEN: String
    let mappings: [KeyMapping]

    func detail(_ language: Language) -> String {
        language == .vi ? detailVI : detailEN
    }
}

enum Presets {
    static let all: [ProfilePreset] = [
        ProfilePreset(
            id: "macbook",
            title: "MacBook",
            detailVI: "⌘ sát Space, ⌥ ở vị trí cũ. Caps Lock giữ nguyên.",
            detailEN: "⌘ next to Space, ⌥ in its old spot. Caps Lock stays normal.",
            mappings: [
                KeyMapping(from: "LeftAlt", to: "LeftGUI"),
                KeyMapping(from: "LeftGUI", to: "LeftAlt"),
            ]
        ),
        ProfilePreset(
            id: "coding",
            title: "Coding",
            detailVI: "MacBook + Caps Lock thành Esc để dùng Vim/terminal.",
            detailEN: "MacBook layout plus Caps Lock as Escape for Vim/terminal.",
            mappings: [
                KeyMapping(from: "LeftAlt", to: "LeftGUI"),
                KeyMapping(from: "LeftGUI", to: "LeftAlt"),
                KeyMapping(from: "CapsLock", to: "Escape"),
            ]
        ),
        ProfilePreset(
            id: "caps-escape",
            title: "Caps = Esc",
            detailVI: "Chỉ đổi Caps Lock thành Esc, giữ nguyên phần còn lại.",
            detailEN: "Only Caps Lock becomes Escape; everything else stays.",
            mappings: [
                KeyMapping(from: "CapsLock", to: "Escape"),
            ]
        ),
        ProfilePreset(
            id: "league",
            title: "League of Legends",
            detailVI: "Caps Lock thành ` để khóa tướng, ⌥ sát Space để chơi game.",
            detailEN: "Caps Lock becomes ` for camera lock, ⌥ next to Space for gaming.",
            mappings: [
                KeyMapping(from: "CapsLock", to: "Grave"),
            ]
        ),
        ProfilePreset(
            id: "no-caps",
            title: "No Caps Lock",
            detailVI: "Caps Lock thành Control để không gõ nhầm chữ hoa.",
            detailEN: "Caps Lock becomes Control so you stop typing capitals by accident.",
            mappings: [
                KeyMapping(from: "CapsLock", to: "LeftControl"),
            ]
        ),
    ]
}
