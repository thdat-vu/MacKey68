// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import MacKeyKit

struct KeyboardLabView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var lab: KeyLab
    let onSelectKey: (UInt32) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var learnError: String?
    @State private var didCopyReport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()

            if case .denied = lab.status {
                permissionCard
            } else {
                keyCard
                coverageCard
                tester
                chatterCard
            }

            Spacer(minLength: 0)
            footer
        }
        .padding(22)
        .frame(width: 680, height: 680)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            lab.onKeyDown = { usage in
                model.markTested(model.sourceUsage(forReportedUsage: usage))
            }
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
                Text(model.t("Test phím", "Key Test"))
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

    private var coverageCard: some View {
        let total = model.testableUsages.count
        let done = model.testedKeyCount
        let untested = model.untestedUsages
        let names = untested.prefix(12).map { Display.label(for: $0) }.joined(separator: ", ")

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.t("Phủ phím", "Key coverage"))
                    .font(.headline)
                Spacer()
                Text("\(done)/\(total)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(done == total && total > 0 ? Color.green : Color.secondary)
                Button(model.t("Đặt lại", "Reset")) {
                    model.resetTestCoverage()
                }
                .controlSize(.small)
                .disabled(done == 0)
            }

            ProgressView(value: total == 0 ? 0 : Double(done) / Double(total))

            if !untested.isEmpty {
                Text(model.t("Chưa bấm: ", "Not pressed: ") + names
                     + (untested.count > 12 ? " +\(untested.count - 12)" : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if total > 0 {
                Label(model.t("Đã bấm đủ phím trên layout.",
                              "All keys on this layout have been pressed."),
                      systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
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
                            let names = mappedNames(for: event.usage)
                            Text(names.source)
                                .font(.system(.callout, design: .monospaced))
                                .frame(width: 110, alignment: .leading)
                            if let target = names.target {
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(target)
                                    .font(.system(.callout, design: .monospaced))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 90, alignment: .leading)
                            } else {
                                Color.clear.frame(width: 104, height: 1)
                            }
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
            .frame(height: 140)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.035)))
        }
    }

    private func mappedNames(for usage: UInt32) -> (source: String, target: String?) {
        let sourceUsage = model.sourceUsage(forReportedUsage: usage)
        let source = KeyCodes.name(for: sourceUsage)
            ?? String(format: "0x%02X", sourceUsage)
        if let targetUsage = model.activeProfile.destination(for: sourceUsage),
           targetUsage != sourceUsage {
            let target = KeyCodes.name(for: targetUsage)
                ?? String(format: "0x%02X", targetUsage)
            return (source, target)
        }
        return (source, nil)
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
                Button(model.t("Sao chép đường dẫn app", "Copy app path")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Bundle.main.bundlePath, forType: .string)
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
            Button(didCopyReport
                   ? model.t("Đã copy", "Copied")
                   : model.t("Sao chép báo cáo", "Copy report")) {
                copyReport()
            }
            Spacer()
            Text(model.t("Chỉ đọc phím khi Lab mở.",
                         "Only reads keys while the lab is open."))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Button(model.t("Đóng", "Close")) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
    }

    private func copyReport() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        var lines: [String] = []
        lines.append("MacKey68 \(version) — Key Test report")
        lines.append("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        lines.append("Keyboard: \(model.config.activeModel ?? model.config.device?.description ?? "-")")
        lines.append("Layout: \(model.layoutID.shortName) — \(model.layout.name)")
        lines.append("Profile: \(model.activeProfile.name) (\(model.activeProfile.id))")
        lines.append("Mappings:")
        for mapping in model.activeProfile.mappings {
            lines.append("  \(mapping.from) -> \(mapping.to)")
        }
        lines.append("Coverage: \(model.testedKeyCount)/\(model.testableUsages.count)")
        let untested = model.untestedUsages
            .map { KeyCodes.name(for: $0) ?? String(format: "0x%02X", $0) }
        if !untested.isEmpty {
            lines.append("Untested: \(untested.joined(separator: ", "))")
        }
        if lab.chatter.isEmpty {
            lines.append("Chatter: none (50 ms threshold)")
        } else {
            lines.append("Chatter:")
            for (usage, count) in lab.chatter.sorted(by: { $0.value > $1.value }) {
                let name = KeyCodes.name(for: usage) ?? String(format: "0x%02X", usage)
                lines.append("  \(name) ×\(count)")
            }
        }
        lines.append("Recent events:")
        for event in lab.events {
            let delta = event.delta.map { String(format: "%.0f ms", $0 * 1000) } ?? "-"
            lines.append("  \(event.pressed ? "down" : "up  ") \(event.name) 0x\(String(format: "%02X", event.usage)) \(delta)")
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        didCopyReport = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            didCopyReport = false
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
