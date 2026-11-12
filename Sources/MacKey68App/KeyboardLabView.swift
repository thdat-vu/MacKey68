// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import MacKeyKit

struct KeyboardLabView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var lab: KeyLab
    let onSelectKey: (UInt32) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var learnError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()

            if case .denied = lab.status {
                permissionCard
            } else {
                keyCard
                tester
                chatterCard
            }

            Spacer(minLength: 0)
            footer
        }
        .padding(22)
        .frame(width: 660, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            lab.onLearn = { usage in
                if onSelectKey(usage) {
                    dismiss()
                } else {
                    learnError = model.t(
                        "Phím này không có trên layout đang vẽ. Đổi Layout hoặc chọn bàn phím khác.",
                        "This key is not on the current layout. Change Layout or pick another keyboard."
                    )
                }
            }
            lab.start()
        }
        .onDisappear { lab.stop() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Keyboard Lab")
                    .font(.title3.weight(.semibold))
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if case .denied = lab.status {
                Button(model.t("Thử lại", "Retry")) { lab.start() }
            }
        }
    }

    private var keyCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lab.lastKey?.name ?? model.t("Chưa có phím", "No key yet"))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                if let key = lab.lastKey {
                    Text(String(format: "usage 0x%02X · %@",
                                key.usage,
                                key.pressed ? model.t("đang nhấn", "down")
                                            : model.t("đã nhả", "up")))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                } else {
                    Text(model.t("Bấm một phím bất kỳ trên bàn phím.",
                                 "Press any key on your keyboard."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(lab.total)")
                    .font(.title2.monospacedDigit().weight(.semibold))
                Text(model.t("lần nhấn", "key downs"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(0.04)))
    }

    private var tester: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.t("Tester", "Tester"))
                    .font(.headline)
                Spacer()
                Button(model.t("Chọn phím trên bàn phím", "Press to select a key")) {
                    lab.reset()
                    learnError = nil
                    lab.learnMode = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(lab.learnMode)
            }

            if lab.learnMode {
                Label(model.t("Đang chờ bạn bấm phím…", "Waiting for a key press…"),
                      systemImage: "target")
                    .font(.callout)
                    .foregroundStyle(Color.accentColor)
            }

            if let learnError {
                Text(learnError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if lab.events.isEmpty {
                        Text(model.t("Chưa có sự kiện nào.", "No events yet."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    }
                    ForEach(lab.events) { event in
                        HStack(spacing: 10) {
                            Image(systemName: event.pressed
                                  ? "arrow.down.circle.fill"
                                  : "arrow.up.circle")
                                .foregroundStyle(event.pressed ? Color.accentColor : .secondary)
                                .font(.caption)
                            Text(event.name)
                                .font(.system(.callout, design: .monospaced))
                                .frame(width: 140, alignment: .leading)
                            Text(String(format: "0x%02X", event.usage))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)
                            if let delta = event.delta {
                                Text(String(format: "%.0f ms", delta * 1000))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
            .frame(height: 170)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.035)))
        }
    }

    private var chatterCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.t("Chatter / phím nhảy", "Chatter"))
                .font(.headline)
            if lab.chatter.isEmpty {
                Text(model.t("Không phát hiện phím nào nhấn đúp trong 50 ms.",
                             "No key was pressed twice within 50 ms."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text(lab.chatter
                    .sorted { $0.value > $1.value }
                    .map { usage, count in
                        let name = KeyCodes.name(for: usage) ?? String(format: "0x%02X", usage)
                        return "\(name) ×\(count)"
                    }
                    .joined(separator: " · "))
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(model.t("Cần quyền Input Monitoring",
                          "Input Monitoring permission needed"),
                  systemImage: "lock.shield")
                .font(.headline)

            Text(model.t(
                "macOS chỉ cho app đọc phím khi bạn bật MacKey68 trong System Settings → Privacy & Security → Input Monitoring. Bật xong bấm Thử lại.",
                "macOS only lets an app read keys after you enable MacKey68 in System Settings → Privacy & Security → Input Monitoring. Enable it, then press Retry."
            ))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(model.t("Mở System Settings", "Open System Settings")) {
                    lab.openInputMonitoringSettings()
                }
                Button(model.t("Thử lại", "Retry")) { lab.start() }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.orange.opacity(0.10)))
    }

    private var footer: some View {
        HStack {
            Button(model.t("Đặt lại", "Reset")) {
                lab.reset()
                learnError = nil
            }
            .disabled(lab.events.isEmpty)
            Spacer()
            Text(model.t("Lab chỉ đọc phím, không thay đổi mapping.",
                         "The lab only reads keys; it does not change mappings."))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Button(model.t("Đóng", "Close")) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
    }

    private var statusText: String {
        switch lab.status {
        case .idle:
            return model.t("Chưa bật", "Not running")
        case .running:
            return model.t("Đang nghe phím", "Listening")
        case .denied:
            return model.t("Thiếu quyền Input Monitoring", "Input Monitoring denied")
        }
    }

    private var statusColor: Color {
        switch lab.status {
        case .idle: return .secondary
        case .running: return .green
        case .denied: return .orange
        }
    }
}
