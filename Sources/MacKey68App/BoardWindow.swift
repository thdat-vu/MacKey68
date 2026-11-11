// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import MacKeyKit

struct BoardWindow: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            deviceRow
            linkRow
            BoardView()
            Divider()
            InspectorView()
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $model.isShowingGuide, onDismiss: {
            model.markGuideSeen()
        }) {
            GuideView()
                .environmentObject(model)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MacKey68")
                    .font(.title3.weight(.semibold))
                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            Picker("", selection: Binding(
                get: { model.activeProfileID },
                set: { model.selectProfile($0) }
            )) {
                ForEach(model.config.allProfiles) { profile in
                    Text(profile.name).tag(profile.id)
                }
            }
            .labelsHidden()
            .frame(width: 200)

            Button {
                model.openGuide()
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.borderless)
            .help(model.t("Hướng dẫn sử dụng", "How to use MacKey68"))

            Picker("", selection: Binding(
                get: { model.language },
                set: { model.setLanguage($0) }
            )) {
                ForEach(Language.allCases) { language in
                    Text(language.shortLabel).tag(language)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 78)
            .help(model.t("Ngôn ngữ", "Language"))

            Toggle(model.t("Bật", "On"), isOn: $model.enabled)
                .toggleStyle(.switch)
        }
    }

    /// Bàn phím đang chọn + layout vẽ ra (68 / TKL / Full).
    private var deviceRow: some View {
        HStack(spacing: 10) {
            Text(model.t("Bàn phím:", "Keyboard:"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: Binding(
                get: { model.config.device?.description ?? "" },
                set: { key in
                    if let choice = model.deviceChoices.first(where: { $0.id == key }) {
                        model.selectDevice(choice.device)
                    }
                }
            )) {
                ForEach(model.deviceChoices) { choice in
                    Text(choice.label).tag(choice.id)
                }
            }
            .labelsHidden()
            .frame(width: 300)

            Text(model.t("Layout:", "Layout:"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: Binding(
                get: { model.layoutID },
                set: { model.setLayout($0) }
            )) {
                ForEach(LayoutID.allCases) { id in
                    Text(id.shortName).tag(id)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 170)

            if model.availableDevices.isEmpty {
                Text(model.t("chưa cắm bàn phím", "no keyboard connected"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                model.refreshDevices()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help(model.t("Dò lại bàn phím đang cắm", "Rescan connected keyboards"))
        }
    }

    /// Profile hiện tại tự bật khi mở những app nào, và cách gắn thêm.
    private var linkRow: some View {
        HStack(spacing: 8) {
            Text(model.t("Tự đổi khi mở:", "Auto-switch in:"))
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(model.activeProfile.autoFor, id: \.self) { bundleID in
                HStack(spacing: 4) {
                    Text(Display.appName(for: bundleID))
                    Button {
                        model.unlink(bundleID: bundleID)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.accentColor.opacity(0.14)))
            }

            if let app = model.lastForeignApp,
               !model.activeProfile.autoFor.contains(app.id) {
                Button("+ \(app.name)") { model.linkLastForeignApp() }
                    .controlSize(.small)
                    .help(model.t(
                        "Mỗi lần app này ra trước, tự bật profile \(model.activeProfile.name)",
                        "Whenever this app comes forward, switch to profile \(model.activeProfile.name)"
                    ))
            } else if model.activeProfile.autoFor.isEmpty {
                Text(model.t("chưa gắn app nào", "no apps linked"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
    }
}

struct InspectorView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""

    private var selected: LayoutKey? { model.selectedKey }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let key = selected, key.isRemappable {
                HStack(spacing: 8) {
                    Text(key.label.isEmpty ? "space" : key.label)
                        .font(.system(.headline, design: .rounded))
                    Text("→")
                        .foregroundStyle(.secondary)
                    Text(model.destination(for: key).map(Display.label(for:))
                         ?? model.t("chưa đổi", "unchanged"))
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(model.destination(for: key) == nil ? .secondary : Color.accentColor)

                    Spacer()

                    Button(model.t("Bỏ đổi", "Reset")) {
                        model.setMapping(source: key.usage, to: nil)
                    }
                    .disabled(model.destination(for: key) == nil)
                    Button(model.t("Đóng", "Close")) { model.selectedKey = nil }
                }

                TextField(model.t("Tìm phím đích… (grave, esc, cmd, f5)",
                                  "Find target key… (grave, esc, cmd, f5)"),
                          text: $query)
                    .textFieldStyle(.roundedBorder)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 6)], spacing: 6) {
                        ForEach(filtered, id: \.self) { name in
                            if let code = KeyCodes.code(for: name) {
                                Button {
                                    model.setMapping(source: key.usage, to: code)
                                } label: {
                                    Text(Display.label(for: code))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(height: 120)
            } else if let key = selected {
                HStack {
                    Text(model.t("Phím \(key.label) do firmware giữ, không remap được.",
                                 "Key \(key.label) is handled by firmware and can't be remapped."))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(model.t("Đóng", "Close")) { model.selectedKey = nil }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "cursorarrow.click")
                    Text(model.t("Bấm một phím trên hình để đổi chức năng. Phím đã đổi sẽ hiện màu xanh.",
                                 "Click a key above to change it. Remapped keys are highlighted."))
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var filtered: [String] {
        guard !query.isEmpty else { return InspectorView.pickable }
        let needle = query.lowercased()
        return InspectorView.pickable.filter { $0.lowercased().contains(needle) }
    }

    /// Every key the mapping engine understands, including numpad and F13–F20.
    static var pickable: [String] { KeyCodes.allNames }
}

/// Menu bar apps don't get a window for free, and SwiftUI's `Window` scene
/// insists on restoring itself at launch. One NSWindow we control is simpler.
@MainActor
final class BoardWindowController: NSObject, NSWindowDelegate {
    static let shared = BoardWindowController()

    private var window: NSWindow?

    func show(model: AppModel) {
        let createdWindow = window == nil
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 980, height: 700),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "MacKey68"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.contentView = NSHostingView(rootView: BoardWindow().environmentObject(model))
            window.center()
            self.window = window
        }
        activateWindow(retries: 8)

        // Lần đầu mở: chờ cửa sổ lên rồi mới bung popup hướng dẫn.
        if createdWindow {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                model.presentGuideIfNeeded()
            }
        }
    }

    /// macOS hay trì hoãn việc activate app mới; thử lại vài lần cho chắc.
    private func activateWindow(retries: Int) {
        NSApp.setActivationPolicy(.regular)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()

        guard retries > 1, NSApp.isActive == false else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.activateWindow(retries: retries - 1)
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
