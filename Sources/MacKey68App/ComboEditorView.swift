// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import MacKeyKit

struct ComboEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let comboID: String

    private var combo: Combo? {
        model.combos.first { $0.id == comboID }
    }

    private var choices: [String] {
        KeyCodes.allNames
            .filter { MacKeyCodes.code(for: $0) != nil }
            .sorted()
    }

    private let modifierNames = ["control", "option", "shift", "command"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 42, height: 42)
                    Image(systemName: "command")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(combo?.name ?? model.t("Combo", "Combo"))
                        .font(.title3.weight(.semibold))
                    Text(model.t("Chọn modifier, phím nguồn và phím đích.",
                                 "Pick modifiers, a source key and a target key."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            if let combo {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.t("Modifier", "Modifiers"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(modifierNames, id: \.self) { modifier in
                            let selected = combo.modifiers.contains {
                                $0.lowercased() == modifier
                            }
                            Button {
                                model.toggleComboModifier(id: comboID, modifier: modifier)
                            } label: {
                                Text(label(for: modifier))
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                    .frame(width: 34, height: 28)
                            }
                            .buttonStyle(.bordered)
                            .tint(selected ? Color.accentColor : Color.secondary)
                        }
                    }
                }

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.t("Từ", "From")).font(.caption).foregroundStyle(.secondary)
                        Menu {
                            ForEach(choices, id: \.self) { name in
                                Button(name) { model.setComboFrom(id: comboID, from: name) }
                            }
                        } label: {
                            Text(combo.from)
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }

                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.t("Thành", "To")).font(.caption).foregroundStyle(.secondary)
                        Menu {
                            ForEach(choices, id: \.self) { name in
                                Button(name) { model.setComboTo(id: comboID, to: name) }
                            }
                        } label: {
                            Text(combo.to)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    Spacer()
                }

                if combo.modifiers.isEmpty {
                    Label(model.t("Combo cần ít nhất một modifier.",
                                  "A combo needs at least one modifier."),
                          systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                Text("\(combo.modifierSummary) + \(combo.from)  →  \(combo.to)")
                    .font(.system(.title3, design: .monospaced))
                    .padding(.top, 4)
            } else {
                Text(model.t("Combo không còn tồn tại.", "This combo no longer exists."))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack {
                if let combo {
                    Button(model.t("Xoá combo", "Delete combo"), role: .destructive) {
                        model.deleteCombo(id: combo.id)
                        dismiss()
                    }
                }
                Spacer()
                Button(model.t("Đóng", "Close")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(22)
        .frame(width: 620, height: 430)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func label(for modifier: String) -> String {
        switch modifier {
        case "control": return "⌃"
        case "option": return "⌥"
        case "shift": return "⇧"
        case "command": return "⌘"
        default: return modifier
        }
    }
}
