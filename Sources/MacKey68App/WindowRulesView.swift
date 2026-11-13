// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import AppKit
import MacKeyKit

struct WindowRulesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var editingRule: WindowRule?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 42, height: 42)
                    Image(systemName: "macwindow.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.t("Window rules", "Window rules"))
                        .font(.title3.weight(.semibold))
                    Text(model.t("Đổi profile theo app + tiêu đề cửa sổ.",
                                 "Switch profiles by app + focused window title."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    let id = model.addWindowRule(name: model.t("Rule mới", "New rule"),
                                                 bundlePrefix: nil,
                                                 titleContains: "",
                                                 profileID: model.activeProfile.id)
                    editingRule = model.windowRules.first { $0.id == id }
                } label: {
                    Label(model.t("Thêm rule", "Add rule"), systemImage: "plus")
                }
            }

            Divider()

            if !WindowTitleReader.isTrusted {
                permissionCard
            }

            if model.windowRules.isEmpty {
                Text(model.t("Chưa có rule nào. Thêm rule để đổi profile khi một cửa sổ cụ thể xuất hiện.",
                             "No rules yet. Add one to switch profiles when a specific window is focused."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.windowRules) { rule in
                        HStack(spacing: 10) {
                            Button {
                                model.setWindowRuleEnabled(id: rule.id, enabled: !rule.enabled)
                            } label: {
                                Image(systemName: rule.enabled ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(rule.enabled ? Color.accentColor : .secondary)
                            }
                            .buttonStyle(.borderless)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.name).font(.headline)
                                Text(detail(for: rule))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Button {
                                editingRule = rule
                            } label: {
                                Label(model.t("Chỉnh", "Edit"), systemImage: "pencil")
                            }
                            .controlSize(.small)
                            Button {
                                model.deleteWindowRule(id: rule.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.primary.opacity(0.04)))
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Text(model.t("Rule khớp sẽ thắng autoFor của profile.",
                             "A matching rule wins over a profile's autoFor."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(model.t("Đóng", "Close")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(22)
        .frame(width: 700, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editingRule) { rule in
            WindowRuleEditorView(rule: rule)
                .environmentObject(model)
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(model.t("Cần quyền Accessibility", "Accessibility permission needed"),
                  systemImage: "lock.shield")
                .font(.headline)
            Text(model.t(
                "macOS chỉ cho app đọc tiêu đề cửa sổ khi bật MacKey68 trong System Settings → Privacy & Security → Accessibility.",
                "macOS only lets an app read window titles after you enable MacKey68 in System Settings → Privacy & Security → Accessibility."
            ))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(model.t("Mở System Settings", "Open System Settings")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button(model.t("Yêu cầu quyền", "Request access")) {
                    WindowTitleReader.requestAccess()
                }
                Button(model.t("Sao chép đường dẫn app", "Copy app path")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Bundle.main.bundlePath, forType: .string)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.orange.opacity(0.10)))
    }

    private func detail(for rule: WindowRule) -> String {
        let app = rule.bundlePrefix?.isEmpty == false
            ? rule.bundlePrefix!
            : model.t("mọi app", "any app")
        let title = rule.titleContains.isEmpty
            ? model.t("(chưa có tiêu đề)", "(no title)")
            : "“\(rule.titleContains)”"
        let profile = model.config.allProfiles
            .first { $0.id == rule.profileID }?.name ?? rule.profileID
        return "\(app) · \(title) → \(profile)"
    }
}

struct WindowRuleEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let original: WindowRule

    @State private var name: String
    @State private var bundlePrefix: String
    @State private var titleContains: String
    @State private var profileID: String
    @State private var enabled: Bool
    @State private var error: String?

    init(rule: WindowRule) {
        original = rule
        _name = State(initialValue: rule.name)
        _bundlePrefix = State(initialValue: rule.bundlePrefix ?? "")
        _titleContains = State(initialValue: rule.titleContains)
        _profileID = State(initialValue: rule.profileID)
        _enabled = State(initialValue: rule.enabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.t("Rule cửa sổ", "Window rule"))
                .font(.title3.weight(.semibold))
            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(model.t("Tên rule", "Rule name"))
                    .font(.caption).foregroundStyle(.secondary)
                TextField("", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.t("Bundle ID của app (tuỳ chọn)", "App bundle ID (optional)"))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(model.t("Dùng app hiện tại", "Use current app")) {
                        if let id = model.lastForeignBundleID {
                            bundlePrefix = id
                        } else {
                            bundlePrefix = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
                        }
                    }
                    .controlSize(.small)
                }
                TextField("com.riotgames.", text: $bundlePrefix)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.t("Tiêu đề cửa sổ chứa", "Window title contains"))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(model.t("Dùng title hiện tại", "Use current title")) {
                        if !WindowTitleReader.isTrusted {
                            WindowTitleReader.requestAccess()
                        }
                        if let title = model.lastForeignWindowTitle {
                            titleContains = title
                        } else if let title = WindowTitleReader.frontmost()?.title {
                            titleContains = title
                        }
                    }
                    .controlSize(.small)
                }
                TextField(model.t("League of Legends", "League of Legends"), text: $titleContains)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.t("Profile", "Profile"))
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $profileID) {
                        ForEach(model.config.allProfiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
                Spacer()
                Toggle(model.t("Bật", "Enabled"), isOn: $enabled)
                    .toggleStyle(.switch)
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(.orange)
            }

            Spacer(minLength: 0)

            HStack {
                Button(model.t("Xoá", "Delete"), role: .destructive) {
                    model.deleteWindowRule(id: original.id)
                    dismiss()
                }
                Spacer()
                Button(model.t("Huỷ", "Cancel")) { dismiss() }
                Button(model.t("Lưu", "Save")) { save() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 620, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func save() {
        let title = titleContains.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            error = model.t("Cần nhập chuỗi trong tiêu đề cửa sổ.",
                            "Enter a substring of the window title.")
            return
        }
        guard model.config.allProfiles.contains(where: { $0.id == profileID }) else {
            error = model.t("Profile không tồn tại.", "That profile no longer exists.")
            return
        }

        let rule = WindowRule(id: original.id,
                              name: name.isEmpty ? "Window rule" : name,
                              bundlePrefix: bundlePrefix.trimmingCharacters(in: .whitespacesAndNewlines),
                              titleContains: title,
                              profileID: profileID,
                              enabled: enabled)
        model.updateWindowRule(rule)
        dismiss()
    }
}
