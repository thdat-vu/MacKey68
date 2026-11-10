import SwiftUI
import MacKeyKit

enum Display {
    /// Tên dễ đọc cho bundle id đang gắn với profile.
    static func appName(for bundleID: String) -> String {
        switch bundleID {
        case let id where id.hasPrefix("com.riotgames"): return "League of Legends"
        case "com.codeweavers.CrossOver": return "CrossOver"
        case "com.apple.TextEdit": return "TextEdit"
        case "com.google.Chrome": return "Google Chrome"
        default:
            return bundleID.split(separator: ".").suffix(2).joined(separator: ".")
        }
    }

    /// Nhãn ngắn cho một usage, dùng trên keycap và trong danh sách chọn.
    static func label(for usage: UInt32) -> String {
        switch usage {
        case 0xE0, 0xE4: return "⌃"
        case 0xE1, 0xE5: return "⇧"
        case 0xE2, 0xE6: return "⌥"
        case 0xE3, 0xE7: return "⌘"
        case 0x28: return "⏎"
        case 0x29: return "esc"
        case 0x2A: return "⌫"
        case 0x2B: return "⇥"
        case 0x2C: return "space"
        case 0x2D: return "-"
        case 0x2E: return "="
        case 0x2F: return "["
        case 0x30: return "]"
        case 0x31: return "\\"
        case 0x33: return ";"
        case 0x34: return "'"
        case 0x36: return ","
        case 0x37: return "."
        case 0x38: return "/"
        case 0x39: return "caps"
        case 0x46: return "prtsc"
        case 0x48: return "pause"
        case 0x49: return "ins"
        case 0x65: return "menu"
        case 0x35: return "`"
        case 0x4C: return "⌦"
        case 0x4A: return "home"
        case 0x4D: return "end"
        case 0x4B: return "pgup"
        case 0x4E: return "pgdn"
        case 0x4F: return "→"
        case 0x50: return "←"
        case 0x51: return "↓"
        case 0x52: return "↑"
        default:
            return (KeyCodes.name(for: usage) ?? "?").lowercased()
        }
    }
}

struct KeyCapView: View {
    let key: LayoutKey
    let unit: CGFloat
    let destination: UInt32?
    let isSelected: Bool
    let fnHelp: String
    let action: () -> Void

    private var changed: Bool { destination != nil }
    private var targetText: String { destination.map(Display.label(for:)) ?? key.label }
    private var originalText: String { key.label.isEmpty ? "space" : key.label }

    /// Backtick, tilde… là những glyph rất nhỏ trong font, phải phóng to hơn.
    private var glyphSize: CGFloat {
        switch targetText {
        case "`": return max(12, unit * 0.56)
        case "~": return max(11, unit * 0.44)
        default: return max(9, unit * (changed ? 0.36 : 0.32))
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: changed
                                ? [Color.accentColor.opacity(0.32), Color.accentColor.opacity(0.12)]
                                : [Color(nsColor: .controlBackgroundColor), Color(nsColor: .windowBackgroundColor)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isSelected
                                    ? Color.accentColor
                                    : (changed ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.14)),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }

                if changed {
                    // Nhãn in trên keycap, để vẫn nhận ra phím nào.
                    VStack {
                        HStack {
                            Text(originalText)
                                .font(.system(size: max(7, unit * 0.17)))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Spacer(minLength: 0)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 3)
                }

                Text(targetText)
                    .font(.system(size: glyphSize,
                                  weight: changed ? .bold : .regular,
                                  design: .rounded))
                    .foregroundStyle(changed ? Color.accentColor : Color.primary.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 2)
                    .offset(y: changed ? unit * 0.07 : 0)
            }
        }
        .buttonStyle(.plain)
        .frame(width: max(18, key.width * unit - 5), height: unit * 0.92)
        .help(key.isRemappable ? "\(originalText) → \(targetText)" : fnHelp)
    }
}

struct BoardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Color.clear
            .aspectRatio(3.5, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let gap: CGFloat = 5
                    let units = CGFloat(model.layout.unitCount)
                    let unit = max(20, (geo.size.width - gap * units) / units)

                    VStack(alignment: .leading, spacing: gap) {
                        ForEach(model.layout.rows) { row in
                            HStack(spacing: gap) {
                                ForEach(row.keys) { key in
                                    KeyCapView(
                                        key: key,
                                        unit: unit,
                                        destination: model.destination(for: key),
                                        isSelected: model.selectedKey?.id == key.id,
                                        fnHelp: model.t("Fn do firmware giữ, không remap được",
                                                        "Fn is handled by firmware and can't be remapped")
                                    ) {
                                        model.selectedKey = key
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }
}
